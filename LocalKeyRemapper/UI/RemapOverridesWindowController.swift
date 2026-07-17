//
//  RemapOverridesWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import AppKit
import CoreGraphics

/// A sheet that edits the exact exceptions owned by one
/// modifier-preserving remapping rule.
@MainActor
final class RemapOverridesWindowController:
    NSWindowController,
    NSWindowDelegate
{
    @MainActor
    private final class CaptureWindow: NSWindow {

        var keyDownHandler: ((NSEvent) -> Bool)?

        override func sendEvent(_ event: NSEvent) {
            if
                event.type == .keyDown,
                keyDownHandler?(event) == true
            {
                return
            }

            super.sendEvent(event)
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
        case duplicateSource
        case sourceKeyMismatch
        case identityReplacement

        var message: String {
            switch self {
            case .incomplete:
                return "Complete every highlighted exception before saving."

            case .duplicateSource:
                return "Each exception source combination can appear only once."

            case .sourceKeyMismatch:
                return "Every exception must use the parent rule's physical source key."

            case .identityReplacement:
                return "An exception cannot replace a combination with itself."
            }
        }
    }

    private struct ValidationSnapshot {
        let issue: ValidationIssue?
        let invalidRows: Set<ObjectIdentifier>
    }

    private let parentWindow: NSWindow
    private let parentRule: RemapRule

    private let remappingController:
        RemappingSettingsControlling

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

    private let sourceHeader = NSTextField(
        labelWithString: "Source combination"
    )

    private let actionHeader = NSTextField(
        labelWithString: "Action"
    )

    private let destinationHeader = NSTextField(
        labelWithString: "Destination"
    )

    private let scrollView = NSScrollView()
    private let documentView = FlippedView()
    private let rowsStack = NSStackView()

    private let addButton = NSButton()
    private let cancelButton = NSButton()
    private let saveButton = NSButton()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private let actionsStack = NSStackView()
    private let mainStack = NSStackView()

    private var rows: [RemapOverrideRowView] = []

    private var captureRow: RemapOverrideRowView?
    private var captureField:
        RemapOverrideRowView.KeyField?

    private let initialOverrides:
        [RemapOverride]

    private let textScale: CGFloat

    init(
        parentWindow: NSWindow,
        rule: RemapRule,
        remappingController:
            RemappingSettingsControlling,
        textScale: CGFloat,
        onSave:
            @escaping ([RemapOverride]) -> Void,
        onClose:
            @escaping () -> Void
    ) {
        self.parentWindow = parentWindow
        parentRule = rule
        self.remappingController = remappingController
        self.textScale = textScale
        self.onSave = onSave
        self.onClose = onClose
        initialOverrides = rule.overrides

        let window = CaptureWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 800,
                height: 500
            ),
            styleMask: [
                .titled,
                .closable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "Modifier Exceptions"
        window.isReleasedWhenClosed = false

        window.contentMinSize = NSSize(
            width: 720,
            height: 400
        )

        super.init(window: window)

        window.delegate = self

        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureContent()
        loadInitialRows()
        applyTextScale()
        refreshState()
    }

    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    func showAsSheet() {
        guard let window else {
            return
        }

        parentWindow.beginSheet(window)
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        cancelAndClose()
        return false
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let sourceName = KeyCodeDisplayName.name(
            for: parentRule.source.keyCode
        )

        let destinationName = KeyCodeDisplayName.name(
            for: parentRule.destination.keyCode
        )

        descriptionLabel.stringValue =
            "Exact exceptions override \(sourceName) → \(destinationName) when specific modifiers are pressed."

        descriptionLabel.textColor =
            .secondaryLabelColor

        sourceHeader.textColor =
            .secondaryLabelColor

        actionHeader.textColor =
            .secondaryLabelColor

        destinationHeader.textColor =
            .secondaryLabelColor

        configureScrollView()
        configureButtons()

        let actionsSpacer = NSView()

        actionsSpacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        actionsSpacer.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        actionsStack.setViews(
            [
                addButton,
                actionsSpacer,
                cancelButton,
                saveButton
            ],
            in: .leading
        )

        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY

        let headerView = makeHeaderView()

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                headerView,
                scrollView,
                actionsStack,
                statusLabel
            ],
            in: .leading
        )

        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints =
            false

        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate(
            [
                mainStack.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: 24
                ),

                mainStack.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 24
                ),

                mainStack.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -24
                ),

                mainStack.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -24
                ),

                headerView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),

                scrollView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),

                actionsStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                )
            ]
        )
    }

    private func makeHeaderView() -> NSView {
        let headerView = NSView()
        let arrowSpacer = NSView()
        let removeSpacer = NSView()

        let views: [NSView] = [
            sourceHeader,
            arrowSpacer,
            actionHeader,
            destinationHeader,
            removeSpacer
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            headerView.addSubview(view)
        }

        headerView.translatesAutoresizingMaskIntoConstraints =
            false

        NSLayoutConstraint.activate(
            [
                sourceHeader.leadingAnchor.constraint(
                    equalTo: headerView.leadingAnchor,
                    constant: 6
                ),

                sourceHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),

                sourceHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),

                sourceHeader.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 180
                ),

                arrowSpacer.leadingAnchor.constraint(
                    equalTo: sourceHeader.trailingAnchor,
                    constant: 10
                ),

                arrowSpacer.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                actionHeader.leadingAnchor.constraint(
                    equalTo: arrowSpacer.trailingAnchor,
                    constant: 10
                ),

                actionHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),

                actionHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),

                actionHeader.widthAnchor.constraint(
                    equalToConstant: 132
                ),

                destinationHeader.leadingAnchor.constraint(
                    equalTo: actionHeader.trailingAnchor,
                    constant: 10
                ),

                destinationHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),

                destinationHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),

                destinationHeader.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 180
                ),

                removeSpacer.leadingAnchor.constraint(
                    equalTo: destinationHeader.trailingAnchor,
                    constant: 10
                ),

                removeSpacer.trailingAnchor.constraint(
                    equalTo: headerView.trailingAnchor,
                    constant: -6
                ),

                removeSpacer.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceHeader.widthAnchor.constraint(
                    equalTo: destinationHeader.widthAnchor
                ),

                headerView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 20
                )
            ]
        )

        return headerView
    }

    private func configureScrollView() {
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.translatesAutoresizingMaskIntoConstraints =
            false

        documentView.translatesAutoresizingMaskIntoConstraints =
            false

        documentView.addSubview(rowsStack)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = false
        scrollView.documentView = documentView
        scrollView.translatesAutoresizingMaskIntoConstraints =
            false

        scrollView.setContentHuggingPriority(
            .defaultLow,
            for: .vertical
        )

        scrollView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .vertical
        )

        NSLayoutConstraint.activate(
            [
                rowsStack.topAnchor.constraint(
                    equalTo: documentView.topAnchor,
                    constant: 12
                ),

                rowsStack.leadingAnchor.constraint(
                    equalTo: documentView.leadingAnchor,
                    constant: 12
                ),

                rowsStack.trailingAnchor.constraint(
                    equalTo: documentView.trailingAnchor,
                    constant: -12
                ),

                rowsStack.bottomAnchor.constraint(
                    equalTo: documentView.bottomAnchor,
                    constant: -12
                ),

                documentView.widthAnchor.constraint(
                    equalTo:
                        scrollView.contentView.widthAnchor
                ),

                documentView.heightAnchor.constraint(
                    greaterThanOrEqualTo:
                        scrollView.contentView.heightAnchor
                ),

                scrollView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 190
                )
            ]
        )
    }

    private func configureButtons() {
        addButton.title = "Add Exception"

        addButton.image = NSImage(
            systemSymbolName: "plus",
            accessibilityDescription: "Add Exception"
        )

        addButton.imagePosition = .imageLeading
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addEmptyRow)

        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action =
            #selector(cancelButtonPressed)

        saveButton.title = "Save Exceptions"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action =
            #selector(saveButtonPressed)
    }

    private func loadInitialRows() {
        for override in initialOverrides {
            addRow(
                override: override,
                scrollIntoView: false
            )
        }
    }

    private func addRow(
        override: RemapOverride? = nil,
        scrollIntoView: Bool = true
    ) {
        let row = RemapOverrideRowView(
            override: override
        )

        row.applyTextScale(textScale)

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

            self?.removeRow(row)
        }

        row.onChange = {
            [weak self] in

            self?.refreshState()
        }

        rows.append(row)
        rowsStack.addArrangedSubview(row)

        row.translatesAutoresizingMaskIntoConstraints =
            false

        row.widthAnchor.constraint(
            equalTo: rowsStack.widthAnchor
        ).isActive = true

        refreshState()

        if scrollIntoView {
            scrollToRow(row)
        }
    }

    private func removeRow(
        _ row: RemapOverrideRowView
    ) {
        if captureRow === row {
            endCapture()
        }

        guard let index = rows.firstIndex(
            where: { $0 === row }
        ) else {
            return
        }

        rows.remove(at: index)
        rowsStack.removeArrangedSubview(row)
        row.removeFromSuperview()

        refreshState()
    }

    private func scrollToRow(
        _ row: RemapOverrideRowView
    ) {
        documentView.layoutSubtreeIfNeeded()
        rowsStack.layoutSubtreeIfNeeded()

        let visibleRect = row.convert(
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

    private func beginCapture(
        row: RemapOverrideRowView,
        field: RemapOverrideRowView.KeyField
    ) {
        if
            captureRow === row,
            captureField == field
        {
            endCapture()
            refreshState()
            return
        }

        if captureRow != nil {
            endCapture()
        }

        captureRow = row
        captureField = field

        remappingController.beginKeyCapture()

        row.showCapturePrompt(
            for: field
        )

        switch field {
        case .source:
            let sourceName =
                KeyCodeDisplayName.name(
                    for:
                        parentRule.source.keyCode
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

    private func handleKeyDown(
        _ event: NSEvent
    ) -> Bool {
        guard
            let captureRow,
            let captureField
        else {
            return false
        }

        let combination = KeyCombination(
            keyCode: CGKeyCode(
                event.keyCode
            ),
            modifiers: KeyModifiers(
                appKitFlags:
                    event.modifierFlags
            )
        )

        if
            captureField == .source,
            combination.keyCode
                != parentRule.source.keyCode
        {
            let sourceName =
                KeyCodeDisplayName.name(
                    for:
                        parentRule.source.keyCode
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
        refreshState()

        return true
    }

    private func endCapture() {
        guard captureRow != nil else {
            return
        }

        captureRow?.restoreButtonTitles()

        captureRow = nil
        captureField = nil

        remappingController.endKeyCapture()
    }

    private var completeOverrides:
        [RemapOverride]?
    {
        let overrides = rows.compactMap {
            $0.override
        }

        guard overrides.count == rows.count else {
            return nil
        }

        return overrides
    }

    private var hasUnsavedChanges: Bool {
        guard let current = completeOverrides else {
            return true
        }

        return normalized(current)
            != normalized(initialOverrides)
    }

    private func normalized(
        _ overrides: [RemapOverride]
    ) -> [RemapOverride] {
        overrides.sorted {
            if
                $0.source.keyCode
                    != $1.source.keyCode
            {
                return $0.source.keyCode
                    < $1.source.keyCode
            }

            if
                $0.source.modifiers.rawValue
                    != $1.source.modifiers.rawValue
            {
                return $0.source.modifiers.rawValue
                    < $1.source.modifiers.rawValue
            }

            return actionSortKey($0.action)
                < actionSortKey($1.action)
        }
    }

    private func actionSortKey(
        _ action: RemapAction
    ) -> String {
        switch action {
        case .passThrough:
            return "0"

        case .replaceWith(
            let destination
        ):
            return
                "1-\(destination.keyCode)-\(destination.modifiers.rawValue)"
        }
    }

    private func validationSnapshot()
        -> ValidationSnapshot
    {
        var invalidRows =
            Set<ObjectIdentifier>()

        var sourceOwners:
            [KeyCombination:
                [RemapOverrideRowView]] = [:]

        var hasIncomplete = false
        var hasDuplicate = false
        var hasSourceMismatch = false
        var hasIdentity = false

        for row in rows {
            guard let override =
                row.override
            else {
                hasIncomplete = true

                invalidRows.insert(
                    ObjectIdentifier(row)
                )

                continue
            }

            if
                override.source.keyCode
                    != parentRule.source.keyCode
            {
                hasSourceMismatch = true

                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }

            if row.hasIdentityReplacement {
                hasIdentity = true

                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }

            sourceOwners[
                override.source,
                default: []
            ].append(row)
        }

        for owners in sourceOwners.values
        where owners.count > 1 {
            hasDuplicate = true

            for row in owners {
                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }
        }

        let issue: ValidationIssue?

        if hasDuplicate {
            issue = .duplicateSource
        } else if hasSourceMismatch {
            issue = .sourceKeyMismatch
        } else if hasIdentity {
            issue = .identityReplacement
        } else if hasIncomplete {
            issue = .incomplete
        } else {
            issue = nil
        }

        return ValidationSnapshot(
            issue: issue,
            invalidRows: invalidRows
        )
    }

    private func applyValidationAppearance(
        _ snapshot: ValidationSnapshot
    ) {
        for row in rows {
            row.setValidationErrorVisible(
                snapshot.invalidRows.contains(
                    ObjectIdentifier(row)
                )
            )
        }
    }

    private func refreshState() {
        let snapshot =
            validationSnapshot()

        applyValidationAppearance(
            snapshot
        )

        let hasChanges =
            hasUnsavedChanges

        saveButton.isEnabled =
            snapshot.issue == nil &&
            hasChanges

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
        } else if !hasChanges {
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

        guard let overrides =
            completeOverrides
        else {
            return
        }

        onSave(overrides)
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

        parentWindow.endSheet(window)
        window.orderOut(nil)

        onClose()
    }

    private func setStatus(
        _ message: String,
        isError: Bool
    ) {
        statusLabel.stringValue = message

        statusLabel.textColor =
            isError
                ? .systemRed
                : .secondaryLabelColor
    }

    private func applyTextScale() {
        titleLabel.font =
            NSFont.systemFont(
                ofSize: 20 * textScale,
                weight: .semibold
            )

        descriptionLabel.font =
            NSFont.systemFont(
                ofSize: 13 * textScale,
                weight: .regular
            )

        sourceHeader.font =
            NSFont.systemFont(
                ofSize: 12 * textScale,
                weight: .medium
            )

        actionHeader.font =
            sourceHeader.font

        destinationHeader.font =
            sourceHeader.font

        statusLabel.font =
            NSFont.systemFont(
                ofSize: 13 * textScale,
                weight: .regular
            )

        let actionFont =
            NSFont.systemFont(
                ofSize: 13 * textScale,
                weight: .regular
            )

        addButton.font = actionFont
        cancelButton.font = actionFont
        saveButton.font = actionFont

        rowsStack.spacing =
            10 * textScale

        actionsStack.spacing =
            10 * textScale

        mainStack.spacing =
            14 * textScale
    }
}
