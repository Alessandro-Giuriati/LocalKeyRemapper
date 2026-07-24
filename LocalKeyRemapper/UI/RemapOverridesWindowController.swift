//
//  RemapOverridesWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A sheet that edits the stored exceptions owned by one remapping rule.
///
/// Exceptions remain stored in every matching mode. They affect runtime
/// remapping only when the parent rule uses Preserve Modifiers and the
/// individual exception is enabled.
@MainActor
final class RemapOverridesWindowController:
    NSWindowController,
    NSWindowDelegate
{
    @MainActor
    private final class CaptureWindow: NSWindow {
        var flagsChangedHandler: ((NSEvent) -> Void)?
        var keyDownHandler: ((NSEvent) -> Bool)?
        var undoHandler: (() -> Void)?
        var redoHandler: (() -> Void)?
        var canUndoHandler: (() -> Bool)?
        var canRedoHandler: (() -> Bool)?

        override func sendEvent(
            _ event: NSEvent
        ) {
            if event.type == .flagsChanged {
                flagsChangedHandler?(event)
            }

            if event.type == .keyDown,
               keyDownHandler?(event) == true {
                return
            }

            super.sendEvent(event)
        }

        override func validateUserInterfaceItem(
            _ item: NSValidatedUserInterfaceItem
        ) -> Bool {
            if item.action
                == #selector(performRuleEditorUndo(_:))
            {
                return canUndoHandler?() ?? false
            }

            if item.action
                == #selector(performRuleEditorRedo(_:))
            {
                return canRedoHandler?() ?? false
            }

            return super.validateUserInterfaceItem(item)
        }

        @objc
        func performRuleEditorUndo(
            _ sender: Any?
        ) {
            undoHandler?()
        }

        @objc
        func performRuleEditorRedo(
            _ sender: Any?
        ) {
            redoHandler?()
        }
    }

    @MainActor
    private final class FlippedView: NSView {
        override var isFlipped: Bool {
            true
        }
    }

    private enum ValidationIssue {
        case incomplete
        case duplicateActiveSource
        case sourceKeyMismatch
        case parentSourceConflict
        case identityReplacement
        case externalConflict(String)

        var message: String {
            switch self {
            case .incomplete:
                return "Complete every highlighted exception before saving."

            case .duplicateActiveSource:
                return "Two enabled exceptions cannot use the same source combination."

            case .sourceKeyMismatch:
                return "Every exception must use the parent rule's physical source key."

            case .parentSourceConflict:
                return "An exception cannot use the exact same source combination as its parent rule."

            case .identityReplacement:
                return "An exception cannot replace a combination with itself."

            case .externalConflict(
                let message
            ):
                return message
            }
        }
    }

    private struct ValidationSnapshot {
        let issue: ValidationIssue?
        let invalidRows: Set<ObjectIdentifier>
    }

    private struct WarningSnapshot {
        let warning:
            KeyCombinationConfigurationWarning?

        let affectedRows:
            Set<ObjectIdentifier>
    }

    private struct EditorSnapshot: Equatable {
        let rowStates:
            [RemapOverrideRowView.EditorState]
    }

    private enum LocalHistoryLimit {
        /// Stores at most 5,000 reversible changes plus the current state.
        static let maximumSnapshotCount = 5_001
    }

    private let parentWindow: NSWindow
    private let parentRule: RemapRule

    private let remappingController:
        RemappingSettingsControlling

    /// Optional validation supplied by the main editor.
    ///
    /// This allows activation to be rejected when an exception conflicts
    /// with another active rule outside this sheet.
    private let validateCandidateOverrides:
        (([RemapOverride]) -> String?)?

    private let onSave:
        ([RemapOverride]) -> Void

    private let onClose:
        () -> Void

    private let titleLabel = NSTextField(
        labelWithString: "Custom Exceptions"
    )

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private let enabledHeader = NSTextField(
        labelWithString: "Enabled"
    )

    private let sourceHeader = NSTextField(
        labelWithString: "Source combination"
    )

    private let actionHeader = NSTextField(
        labelWithString: "Action"
    )

    private let destinationHeader = NSTextField(
        labelWithString: "Destination"
    )

    private let warningBanner =
        ConfigurationWarningBannerView()

    private let scrollView = NSScrollView()
    private let documentView = FlippedView()
    private let rowsStack = NSStackView()

    private let addButton = NSButton()
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private let cancelButton = NSButton()
    private let saveButton = NSButton()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private let actionsStack = NSStackView()
    private let mainStack = NSStackView()

    private var rows:
        [RemapOverrideRowView] = []

    private var captureRow:
        RemapOverrideRowView?

    private var captureField:
        RemapOverrideRowView.KeyField?

    private var fnModifierStateTracker =
        FnModifierStateTracker()

    private var nonFnModifierStateTracker =
        NonFnModifierStateTracker()

    private var historySnapshots:
        [EditorSnapshot] = []

    private var historyIndex = 0
    private var isRestoringHistory = false

    private let initialOverrides:
        [RemapOverride]

    private let textScale: CGFloat

    init(
        parentWindow: NSWindow,
        rule: RemapRule,
        remappingController:
            RemappingSettingsControlling,
        textScale: CGFloat,
        validateCandidateOverrides:
            (([RemapOverride]) -> String?)? = nil,
        onSave:
            @escaping ([RemapOverride]) -> Void,
        onClose:
            @escaping () -> Void
    ) {
        self.parentWindow =
            parentWindow

        parentRule = rule

        self.remappingController =
            remappingController

        self.textScale =
            textScale

        self.validateCandidateOverrides =
            validateCandidateOverrides

        self.onSave =
            onSave

        self.onClose =
            onClose

        initialOverrides =
            rule.overrides

        let window = CaptureWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 880,
                height: 520
            ),
            styleMask: [
                .titled,
                .closable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title =
            "Modifier Exceptions"

        window.isReleasedWhenClosed =
            false

        window.contentMinSize = NSSize(
            width: 800,
            height: 420
        )

        super.init(
            window: window
        )

        window.delegate = self

        window.flagsChangedHandler = {
            [weak self] event in

            self?.handleFlagsChanged(
                event
            )
        }

        window.keyDownHandler = {
            [weak self] event in

            self?.handleKeyDown(
                event
            ) ?? false
        }

        window.undoHandler = {
            [weak self] in

            self?.undoLocalChange()
        }

        window.redoHandler = {
            [weak self] in

            self?.redoLocalChange()
        }

        window.canUndoHandler = {
            [weak self] in

            self?.canUndoLocalChange
                ?? false
        }

        window.canRedoHandler = {
            [weak self] in

            self?.canRedoLocalChange
                ?? false
        }

        configureContent()
        loadInitialRows()
        initializeLocalHistory()
        applyTextScale()
        refreshState()
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    func showAsSheet() {
        guard let window else {
            return
        }

        parentWindow.beginSheet(
            window
        )
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        cancelAndClose()
        return false
    }

    private var exceptionsAreRuntimeActive:
        Bool
    {
        parentRule.matchingMode
            == .preserveModifiers
    }

    private func configureContent() {
        guard
            let contentView =
                window?.contentView
        else {
            return
        }

        let sourceName =
            KeyCombinationDisplayName.name(
                for:
                    parentRule
                        .source
            )

        let destinationName =
            KeyCombinationDisplayName.name(
                for:
                    parentRule
                        .destination
            )

        if exceptionsAreRuntimeActive {
            descriptionLabel.stringValue =
                "Enabled exceptions override \(sourceName) → \(destinationName) for specific modifier combinations."
        } else {
            descriptionLabel.stringValue =
                "These exceptions are stored but inactive while Exact only is selected. They will become active again if this rule returns to Preserve modifiers."
        }

        descriptionLabel.textColor =
            exceptionsAreRuntimeActive
                ? .secondaryLabelColor
                : .systemOrange

        for header in [
            enabledHeader,
            sourceHeader,
            actionHeader,
            destinationHeader
        ] {
            header.textColor =
                .secondaryLabelColor
        }

        configureScrollView()
        configureButtons()

        let actionsSpacer = NSView()

        actionsSpacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        actionsSpacer
            .setContentCompressionResistancePriority(
                .defaultLow,
                for: .horizontal
            )

        actionsStack.setViews(
            [
                addButton,
                undoButton,
                redoButton,
                actionsSpacer,
                cancelButton,
                saveButton
            ],
            in: .leading
        )

        actionsStack.orientation =
            .horizontal

        actionsStack.alignment =
            .centerY

        let headerView =
            makeHeaderView()

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                warningBanner,
                headerView,
                scrollView,
                actionsStack,
                statusLabel
            ],
            in: .leading
        )

        mainStack.orientation =
            .vertical

        mainStack.alignment =
            .leading

        mainStack.translatesAutoresizingMaskIntoConstraints =
            false

        contentView.addSubview(
            mainStack
        )

        NSLayoutConstraint.activate(
            [
                mainStack.topAnchor.constraint(
                    equalTo:
                        contentView
                            .topAnchor,
                    constant: 24
                ),

                mainStack.leadingAnchor.constraint(
                    equalTo:
                        contentView
                            .leadingAnchor,
                    constant: 24
                ),

                mainStack.trailingAnchor.constraint(
                    equalTo:
                        contentView
                            .trailingAnchor,
                    constant: -24
                ),

                mainStack.bottomAnchor.constraint(
                    equalTo:
                        contentView
                            .bottomAnchor,
                    constant: -24
                ),

                warningBanner.widthAnchor.constraint(
                    equalTo:
                        mainStack
                            .widthAnchor
                ),

                headerView.widthAnchor.constraint(
                    equalTo:
                        mainStack
                            .widthAnchor
                ),

                scrollView.widthAnchor.constraint(
                    equalTo:
                        mainStack
                            .widthAnchor
                ),

                actionsStack.widthAnchor.constraint(
                    equalTo:
                        mainStack
                            .widthAnchor
                ),

                statusLabel.widthAnchor.constraint(
                    equalTo:
                        mainStack
                            .widthAnchor
                )
            ]
        )
    }

    private func makeHeaderView()
        -> NSView
    {
        let headerView = NSView()
        let arrowSpacer = NSView()
        let issueSpacer = NSView()
        let removeSpacer = NSView()

        let views: [NSView] = [
            enabledHeader,
            sourceHeader,
            arrowSpacer,
            actionHeader,
            destinationHeader,
            issueSpacer,
            removeSpacer
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            headerView.addSubview(
                view
            )
        }

        headerView.translatesAutoresizingMaskIntoConstraints =
            false

        NSLayoutConstraint.activate(
            [
                enabledHeader.leadingAnchor.constraint(
                    equalTo:
                        headerView
                            .leadingAnchor,
                    constant: 6
                ),

                enabledHeader.topAnchor.constraint(
                    equalTo:
                        headerView
                            .topAnchor
                ),

                enabledHeader.bottomAnchor.constraint(
                    equalTo:
                        headerView
                            .bottomAnchor
                ),

                enabledHeader.widthAnchor.constraint(
                    equalToConstant: 54
                ),

                sourceHeader.leadingAnchor.constraint(
                    equalTo: headerView.leadingAnchor,
                    constant: 74
                ),

                sourceHeader.topAnchor.constraint(
                    equalTo:
                        headerView
                            .topAnchor
                ),

                sourceHeader.bottomAnchor.constraint(
                    equalTo:
                        headerView
                            .bottomAnchor
                ),

                sourceHeader.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        160
                ),

                arrowSpacer.leadingAnchor.constraint(
                    equalTo:
                        sourceHeader
                            .trailingAnchor,
                    constant: 10
                ),

                arrowSpacer.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                actionHeader.leadingAnchor.constraint(
                    equalTo:
                        arrowSpacer
                            .trailingAnchor,
                    constant: 10
                ),

                actionHeader.topAnchor.constraint(
                    equalTo:
                        headerView
                            .topAnchor
                ),

                actionHeader.bottomAnchor.constraint(
                    equalTo:
                        headerView
                            .bottomAnchor
                ),

                actionHeader.widthAnchor.constraint(
                    equalToConstant: 132
                ),

                destinationHeader.leadingAnchor.constraint(
                    equalTo:
                        actionHeader
                            .trailingAnchor,
                    constant: 10
                ),

                destinationHeader.topAnchor.constraint(
                    equalTo:
                        headerView
                            .topAnchor
                ),

                destinationHeader.bottomAnchor.constraint(
                    equalTo:
                        headerView
                            .bottomAnchor
                ),

                destinationHeader.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        160
                ),

                issueSpacer.leadingAnchor.constraint(
                    equalTo:
                        destinationHeader
                            .trailingAnchor,
                    constant: 8
                ),

                issueSpacer.widthAnchor.constraint(
                    equalToConstant: 24
                ),

                removeSpacer.leadingAnchor.constraint(
                    equalTo:
                        issueSpacer
                            .trailingAnchor,
                    constant: 8
                ),

                removeSpacer.trailingAnchor.constraint(
                    equalTo:
                        headerView
                            .trailingAnchor,
                    constant: -6
                ),

                removeSpacer.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceHeader.widthAnchor.constraint(
                    equalTo:
                        destinationHeader
                            .widthAnchor
                ),

                headerView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        20
                )
            ]
        )

        return headerView
    }

    private func configureScrollView() {
        rowsStack.orientation =
            .vertical

        rowsStack.alignment =
            .leading

        rowsStack.translatesAutoresizingMaskIntoConstraints =
            false

        documentView.translatesAutoresizingMaskIntoConstraints =
            false

        documentView.addSubview(
            rowsStack
        )

        scrollView.hasVerticalScroller =
            true

        scrollView.autohidesScrollers =
            true

        scrollView.borderType =
            .bezelBorder

        scrollView.drawsBackground =
            false

        scrollView.documentView =
            documentView

        scrollView.translatesAutoresizingMaskIntoConstraints =
            false

        scrollView.setContentHuggingPriority(
            .defaultLow,
            for: .vertical
        )

        scrollView
            .setContentCompressionResistancePriority(
                .defaultLow,
                for: .vertical
            )

        NSLayoutConstraint.activate(
            [
                rowsStack.topAnchor.constraint(
                    equalTo:
                        documentView
                            .topAnchor,
                    constant: 12
                ),

                rowsStack.leadingAnchor.constraint(
                    equalTo:
                        documentView
                            .leadingAnchor,
                    constant: 12
                ),

                rowsStack.trailingAnchor.constraint(
                    equalTo:
                        documentView
                            .trailingAnchor,
                    constant: -12
                ),

                rowsStack.bottomAnchor.constraint(
                    equalTo:
                        documentView
                            .bottomAnchor,
                    constant: -12
                ),

                documentView.widthAnchor.constraint(
                    equalTo:
                        scrollView
                            .contentView
                            .widthAnchor
                ),

                documentView.heightAnchor.constraint(
                    greaterThanOrEqualTo:
                        scrollView
                            .contentView
                            .heightAnchor
                ),

                scrollView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        190
                )
            ]
        )
    }

    private func configureButtons() {
        addButton.title =
            "Add Exception"

        addButton.image =
            NSImage(
                systemSymbolName:
                    "plus",
                accessibilityDescription:
                    "Add Exception"
            )

        addButton.imagePosition =
            .imageLeading

        addButton.bezelStyle =
            .rounded

        addButton.target = self

        addButton.action =
            #selector(addEmptyRow)

        undoButton.title =
            "Undo"

        undoButton.image =
            NSImage(
                systemSymbolName:
                    "arrow.uturn.backward",
                accessibilityDescription:
                    "Undo"
            )

        undoButton.imagePosition =
            .imageLeading

        undoButton.bezelStyle =
            .rounded

        undoButton.target = self

        undoButton.action =
            #selector(undoButtonPressed)

        undoButton.toolTip =
            "Undo the last exception change (Command-Z)."

        redoButton.title =
            "Redo"

        redoButton.image =
            NSImage(
                systemSymbolName:
                    "arrow.uturn.forward",
                accessibilityDescription:
                    "Redo"
            )

        redoButton.imagePosition =
            .imageLeading

        redoButton.bezelStyle =
            .rounded

        redoButton.target = self

        redoButton.action =
            #selector(redoButtonPressed)

        redoButton.toolTip =
            "Redo the last undone exception change (Shift-Command-Z)."

        cancelButton.title =
            "Cancel"

        cancelButton.bezelStyle =
            .rounded

        cancelButton.target = self

        cancelButton.action =
            #selector(
                cancelButtonPressed
            )

        saveButton.title =
            "Save Exceptions"

        saveButton.bezelStyle =
            .rounded

        saveButton.keyEquivalent =
            "\r"

        saveButton.target = self

        saveButton.action =
            #selector(
                saveButtonPressed
            )

        updateLocalHistoryControls()
    }

    private func loadInitialRows() {
        for override in initialOverrides {
            addRow(
                editorState:
                    RemapOverrideRowView
                        .EditorState(
                            override:
                                override
                        ),
                scrollIntoView: false,
                recordsHistory: false
            )
        }
    }

    private func addRow(
        editorState:
            RemapOverrideRowView.EditorState? = nil,
        scrollIntoView: Bool = true,
        recordsHistory: Bool = true
    ) {
        let resolvedEditorState =
            editorState
            ?? RemapOverrideRowView.EditorState()

        let row =
            RemapOverrideRowView(
                editorState:
                    resolvedEditorState
            )

        row.applyTextScale(
            textScale
        )

        row.onSourceRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginCapture(
                row: row,
                field: .source
            )
        }

        row.onDestinationRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginCapture(
                row: row,
                field: .destination
            )
        }

        row.onRemoveRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.removeRow(
                row
            )
        }

        row.onEnabledChangeRequested = {
            [weak self, weak row]
            requestedValue in

            guard
                let self,
                let row
            else {
                return false
            }

            return self
                .shouldApplyEnabledChange(
                    requestedValue,
                    to: row
                )
        }

        row.onChange = {
            [weak self] in

            self?.recordCurrentSnapshot()
            self?.refreshState()
        }

        rows.append(
            row
        )

        rowsStack.addArrangedSubview(
            row
        )

        row.translatesAutoresizingMaskIntoConstraints =
            false

        row.widthAnchor.constraint(
            equalTo:
                rowsStack
                    .widthAnchor
        ).isActive = true

        if recordsHistory {
            recordCurrentSnapshot()
        }

        refreshState()

        if scrollIntoView {
            scrollToRow(
                row
            )
        }
    }

    private func shouldApplyEnabledChange(
        _ requestedValue: Bool,
        to row: RemapOverrideRowView
    ) -> Bool {
        guard requestedValue else {
            return true
        }

        if row.sourceCombination
            == parentRule.source
        {
            setStatus(
                "This exception cannot be enabled because its source combination is already used by the parent rule.",
                isError: true
            )

            return false
        }

        guard exceptionsAreRuntimeActive else {
            return true
        }

        if let source =
            row.sourceCombination
        {
            let hasEnabledSibling =
                rows.contains {
                    candidate in

                    candidate !== row
                    && candidate.isEnabled
                    && candidate
                        .sourceCombination
                        == source
                }

            if hasEnabledSibling {
                setStatus(
                    "This exception cannot be enabled because another enabled exception uses the same source combination.",
                    isError: true
                )

                return false
            }
        }

        guard
            let validateCandidateOverrides
        else {
            return true
        }

        guard
            let candidateOverrides =
                candidateOverrides(
                    enabling: row
                )
        else {
            return true
        }

        if let message =
            validateCandidateOverrides(
                candidateOverrides
            )
        {
            setStatus(
                message,
                isError: true
            )

            return false
        }

        return true
    }

    private func candidateOverrides(
        enabling row:
            RemapOverrideRowView
    ) -> [RemapOverride]? {
        var result:
            [RemapOverride] = []

        for candidate in rows {
            guard
                let current =
                    candidate.override
            else {
                return nil
            }

            if candidate === row {
                result.append(
                    RemapOverride(
                        source:
                            current.source,
                        action:
                            current.action,
                        isEnabled:
                            true
                    )
                )
            } else {
                result.append(
                    current
                )
            }
        }

        return result
    }

    private func removeRow(
        _ row: RemapOverrideRowView
    ) {
        if captureRow === row {
            endCapture()
        }

        guard
            let index =
                rows.firstIndex(
                    where: {
                        $0 === row
                    }
                )
        else {
            return
        }

        rows.remove(
            at: index
        )

        rowsStack.removeArrangedSubview(
            row
        )

        row.removeFromSuperview()

        recordCurrentSnapshot()
        refreshState()
    }

    private func scrollToRow(
        _ row: RemapOverrideRowView
    ) {
        documentView
            .layoutSubtreeIfNeeded()

        rowsStack
            .layoutSubtreeIfNeeded()

        let visibleRect =
            row.convert(
                row.bounds,
                to: documentView
            )

        documentView.scrollToVisible(
            visibleRect
        )
    }

    @objc
    private func addEmptyRow() {
        addRow()
    }

    @objc
    private func undoButtonPressed() {
        undoLocalChange()
    }

    @objc
    private func redoButtonPressed() {
        redoLocalChange()
    }

    private func beginCapture(
        row: RemapOverrideRowView,
        field:
            RemapOverrideRowView.KeyField
    ) {
        if captureRow === row,
           captureField == field {
            endCapture()
            refreshState()
            return
        }

        if captureRow != nil {
            endCapture()
        }

        captureRow = row
        captureField = field

        updateLocalHistoryControls()

        fnModifierStateTracker.synchronize(
            isPressed:
                PhysicalFnKeyState
                    .isPressed()
        )

        nonFnModifierStateTracker.synchronize(
            currentModifiers:
                KeyModifiers(
                    appKitFlags:
                        NSEvent.modifierFlags
                )
        )

        remappingController
            .beginKeyCapture()

        row.showCapturePrompt(
            for: field
        )

        switch field {
        case .source:
            let sourceName =
                KeyCombinationDisplayName.name(
                    for:
                        KeyCombination(
                            keyCode:
                                parentRule
                                    .source
                                    .keyCode
                        )
                )

            setStatus(
                "Press a combination using \(sourceName). Click the same field again to cancel.",
                isError: false
            )

        case .destination:
            setStatus(
                "Press the destination combination. Click the same field again to cancel.",
                isError: false
            )
        }
    }

    private func handleFlagsChanged(
        _ event: NSEvent
    ) {
        guard captureRow != nil else {
            return
        }

        var currentModifiers =
            KeyModifiers(
                appKitFlags:
                    NSEvent.modifierFlags
            )

        currentModifiers.formUnion(
            KeyModifiers(
                appKitFlags:
                    event.modifierFlags
            )
        )

        currentModifiers.remove(
            .fn
        )

        nonFnModifierStateTracker
            .handleFlagsChanged(
                keyCode:
                    CGKeyCode(
                        event.keyCode
                    ),
                currentModifiers:
                    currentModifiers
            )

        guard
            event.keyCode
                == UInt16(
                    kVK_Function
                )
        else {
            return
        }

        fnModifierStateTracker.handleFlagsChanged(
            isPressed:
                PhysicalFnKeyState
                    .isPressed()
                || event.modifierFlags
                    .contains(
                        .function
                    )
        )
    }

    private func handleKeyDown(
        _ event: NSEvent
    ) -> Bool {
        guard
            let captureRow,
            let captureField
        else {
            return false
        }

        var capturedNonFnModifiers =
            nonFnModifierStateTracker
                .modifiers

        capturedNonFnModifiers.formUnion(
            KeyModifiers(
                appKitFlags:
                    NSEvent.modifierFlags
            )
        )

        capturedNonFnModifiers.remove(
            .fn
        )

        let combination =
            KeyCombinationInputNormalizer
                .capturedCombination(
                    deliveredKeyCode:
                        CGKeyCode(
                            event.keyCode
                        ),
                    eventModifiers:
                        KeyModifiers(
                            appKitFlags:
                                event
                                    .modifierFlags
                        ),
                    capturedNonFnModifiers:
                        capturedNonFnModifiers,
                    trackedPhysicalFnIsPressed:
                        fnModifierStateTracker
                            .isPressed
                )

        if captureField == .source,
           combination.keyCode
                != parentRule
                    .source
                    .keyCode
        {
            let sourceName =
                KeyCombinationDisplayName.name(
                    for:
                        KeyCombination(
                            keyCode:
                                parentRule
                                    .source
                                    .keyCode
                        )
                )

            setStatus(
                "This exception must use \(sourceName) as its physical source key.",
                isError: true
            )

            return true
        }

        captureRow.setCombination(
            combination,
            for: captureField
        )

        endCapture()

        return true
    }

    private func endCapture() {
        guard captureRow != nil else {
            return
        }

        captureRow?
            .restoreButtonTitles()

        captureRow = nil
        captureField = nil

        remappingController
            .endKeyCapture()

        fnModifierStateTracker.reset()
        nonFnModifierStateTracker.reset()

        updateLocalHistoryControls()
    }

    private var currentSnapshot:
        EditorSnapshot
    {
        EditorSnapshot(
            rowStates:
                rows.map {
                    $0.editorState
                }
        )
    }

    private var canUndoLocalChange: Bool {
        captureRow == nil
            && historySnapshots.isEmpty == false
            && historyIndex > 0
    }

    private var canRedoLocalChange: Bool {
        captureRow == nil
            && historySnapshots.isEmpty == false
            && historyIndex
                < historySnapshots.count - 1
    }

    private func initializeLocalHistory() {
        historySnapshots = [
            currentSnapshot
        ]

        historyIndex = 0
        updateLocalHistoryControls()
    }

    private func recordCurrentSnapshot() {
        guard !isRestoringHistory else {
            return
        }

        let snapshot =
            currentSnapshot

        guard !historySnapshots.isEmpty else {
            historySnapshots = [snapshot]
            historyIndex = 0
            updateLocalHistoryControls()
            return
        }

        guard
            snapshot
                != historySnapshots[
                    historyIndex
                ]
        else {
            updateLocalHistoryControls()
            return
        }

        if historyIndex
            < historySnapshots.count - 1
        {
            historySnapshots.removeSubrange(
                (historyIndex + 1)
                    ..< historySnapshots.count
            )
        }

        historySnapshots.append(
            snapshot
        )

        if historySnapshots.count
            > LocalHistoryLimit
                .maximumSnapshotCount
        {
            let overflow =
                historySnapshots.count
                - LocalHistoryLimit
                    .maximumSnapshotCount

            historySnapshots.removeFirst(
                overflow
            )
        }

        historyIndex =
            historySnapshots.count - 1

        updateLocalHistoryControls()
    }

    private func undoLocalChange() {
        guard canUndoLocalChange else {
            return
        }

        historyIndex -= 1

        restoreSnapshot(
            historySnapshots[
                historyIndex
            ]
        )
    }

    private func redoLocalChange() {
        guard canRedoLocalChange else {
            return
        }

        historyIndex += 1

        restoreSnapshot(
            historySnapshots[
                historyIndex
            ]
        )
    }

    private func restoreSnapshot(
        _ snapshot: EditorSnapshot
    ) {
        if captureRow != nil {
            endCapture()
        }

        isRestoringHistory = true

        removeAllRows()

        for editorState in
            snapshot.rowStates
        {
            addRow(
                editorState:
                    editorState,
                scrollIntoView:
                    false,
                recordsHistory:
                    false
            )
        }

        isRestoringHistory = false

        refreshState()
        updateLocalHistoryControls()
    }

    private func removeAllRows() {
        for row in rows {
            rowsStack.removeArrangedSubview(
                row
            )

            row.removeFromSuperview()
        }

        rows.removeAll()
    }

    private func updateLocalHistoryControls() {
        undoButton.isEnabled =
            canUndoLocalChange

        redoButton.isEnabled =
            canRedoLocalChange
    }

    private var completeOverrides:
        [RemapOverride]?
    {
        let overrides =
            rows.compactMap {
                $0.override
            }

        guard
            overrides.count
                == rows.count
        else {
            return nil
        }

        return overrides
    }

    private var hasUnsavedChanges:
        Bool
    {
        guard
            let current =
                completeOverrides
        else {
            return true
        }

        return current
            != initialOverrides
    }

    private func validationSnapshot()
        -> ValidationSnapshot
    {
        var invalidRows =
            Set<ObjectIdentifier>()

        var activeSourceOwners:
            [KeyCombination:
                [RemapOverrideRowView]] = [:]

        var hasIncomplete = false
        var hasDuplicateActiveSource =
            false
        var hasSourceMismatch = false
        var hasParentSourceConflict = false
        var hasIdentity = false

        for row in rows {
            guard
                let override =
                    row.override
            else {
                hasIncomplete = true

                invalidRows.insert(
                    ObjectIdentifier(
                        row
                    )
                )

                continue
            }

            if override.source.keyCode
                != parentRule
                    .source
                    .keyCode
            {
                hasSourceMismatch =
                    true

                invalidRows.insert(
                    ObjectIdentifier(
                        row
                    )
                )
            }

            if override.source
                == parentRule.source
            {
                hasParentSourceConflict =
                    true

                invalidRows.insert(
                    ObjectIdentifier(
                        row
                    )
                )
            }

            if row
                .hasIdentityReplacement
            {
                hasIdentity = true

                invalidRows.insert(
                    ObjectIdentifier(
                        row
                    )
                )
            }

            if exceptionsAreRuntimeActive,
               override.isEnabled
            {
                activeSourceOwners[
                    override.source,
                    default: []
                ].append(
                    row
                )
            }
        }

        for owners in
            activeSourceOwners.values
        where owners.count > 1 {
            hasDuplicateActiveSource =
                true

            for row in owners {
                invalidRows.insert(
                    ObjectIdentifier(
                        row
                    )
                )
            }
        }

        var issue:
            ValidationIssue?

        if hasDuplicateActiveSource {
            issue =
                .duplicateActiveSource
        } else if hasSourceMismatch {
            issue =
                .sourceKeyMismatch
        } else if hasParentSourceConflict {
            issue =
                .parentSourceConflict
        } else if hasIdentity {
            issue =
                .identityReplacement
        } else if hasIncomplete {
            issue =
                .incomplete
        } else {
            issue = nil
        }

        if issue == nil,
           let overrides =
                completeOverrides,
           let externalMessage =
                validateCandidateOverrides?(
                    overrides
                )
        {
            issue =
                .externalConflict(
                    externalMessage
                )

            if exceptionsAreRuntimeActive {
                for row in rows
                where row.isEnabled {
                    invalidRows.insert(
                        ObjectIdentifier(
                            row
                        )
                    )
                }
            }
        }

        return ValidationSnapshot(
            issue: issue,
            invalidRows: invalidRows
        )
    }

    private func applyValidationAppearance(
        _ snapshot:
            ValidationSnapshot
    ) {
        for row in rows {
            row.setValidationErrorVisible(
                snapshot
                    .invalidRows
                    .contains(
                        ObjectIdentifier(
                            row
                        )
                    )
            )
        }
    }

    private func warningSnapshot()
        -> WarningSnapshot
    {
        var firstWarning:
            KeyCombinationConfigurationWarning?

        var affectedRows =
            Set<ObjectIdentifier>()

        for row in rows {
            guard
                let warning =
                    row.currentConfigurationWarning
            else {
                continue
            }

            firstWarning =
                firstWarning
                ?? warning

            affectedRows.insert(
                ObjectIdentifier(
                    row
                )
            )
        }

        return WarningSnapshot(
            warning:
                firstWarning,
            affectedRows:
                affectedRows
        )
    }

    private func applyWarningAppearance(
        _ snapshot:
            WarningSnapshot
    ) {
        for row in rows {
            let rowIsAffected =
                snapshot
                    .affectedRows
                    .contains(
                        ObjectIdentifier(
                            row
                        )
                    )

            row.setConfigurationWarning(
                rowIsAffected
                    ? row.currentConfigurationWarning
                    : nil
            )
        }

        warningBanner.setWarning(
            snapshot.warning
        )
    }

    private func refreshState() {
        updateLocalHistoryControls()

        let snapshot =
            validationSnapshot()

        applyValidationAppearance(
            snapshot
        )

        let warningSnapshot =
            warningSnapshot()

        applyWarningAppearance(
            warningSnapshot
        )

        let hasChanges =
            hasUnsavedChanges

        saveButton.isEnabled =
            snapshot.issue == nil
            && hasChanges

        if let issue =
            snapshot.issue
        {
            setStatus(
                issue.message,
                isError: true
            )

            return
        }

        if rows.isEmpty {
            setStatus(
                "No custom exceptions are configured.",
                isError: false
            )

            return
        }

        if !exceptionsAreRuntimeActive {
            if hasChanges {
                setStatus(
                    "These exceptions are inactive in Exact only. You have unsaved exception changes.",
                    isError: false
                )
            } else {
                setStatus(
                    "Stored exceptions are inactive in Exact only.",
                    isError: false
                )
            }

            return
        }

        if !hasChanges {
            setStatus(
                "No unsaved exception changes.",
                isError: false
            )
        } else {
            setStatus(
                "You have unsaved exception changes.",
                isError: false
            )
        }
    }

    @objc
    private func saveButtonPressed() {
        let snapshot =
            validationSnapshot()

        applyValidationAppearance(
            snapshot
        )

        if let issue =
            snapshot.issue
        {
            setStatus(
                issue.message,
                isError: true
            )

            return
        }

        guard
            let overrides =
                completeOverrides
        else {
            return
        }

        onSave(
            overrides
        )

        closeSheet()
    }

    @objc
    private func cancelButtonPressed() {
        cancelAndClose()
    }

    private func cancelAndClose() {
        closeSheet()
    }

    private func closeSheet() {
        endCapture()

        guard let window else {
            onClose()
            return
        }

        parentWindow.endSheet(
            window
        )

        window.orderOut(
            nil
        )

        onClose()
    }

    private func setStatus(
        _ message: String,
        isError: Bool
    ) {
        statusLabel.stringValue =
            message

        statusLabel.textColor =
            isError
                ? .systemRed
                : .secondaryLabelColor
    }

    private func applyTextScale() {
        titleLabel.font =
            NSFont.systemFont(
                ofSize:
                    20 * textScale,
                weight:
                    .semibold
            )

        descriptionLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * textScale,
                weight:
                    .regular
            )

        enabledHeader.font =
            NSFont.systemFont(
                ofSize:
                    12 * textScale,
                weight:
                    .medium
            )

        sourceHeader.font =
            enabledHeader.font

        actionHeader.font =
            enabledHeader.font

        destinationHeader.font =
            enabledHeader.font

        warningBanner.applyTextScale(
            textScale
        )

        statusLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * textScale,
                weight:
                    .regular
            )

        let actionFont =
            NSFont.systemFont(
                ofSize:
                    13 * textScale,
                weight:
                    .regular
            )

        addButton.font =
            actionFont

        undoButton.font =
            actionFont

        redoButton.font =
            actionFont

        cancelButton.font =
            actionFont

        saveButton.font =
            actionFont

        rowsStack.spacing =
            10 * textScale

        actionsStack.spacing =
            10 * textScale

        mainStack.spacing =
            14 * textScale
    }
}
