//
//  RemappingRulesWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A reusable rules window that receives local key events only while the user
/// explicitly records a source or destination combination.
///
/// This is not a global keyboard monitor. Runtime remapping continues to be
/// owned by `EventTapManager`, `RemappingEngine`, and `RemappingController`.
@MainActor
private final class RemappingRulesWindow: NSWindow {
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

/// Keeps scrollable rule content anchored to the top-left corner.
@MainActor
private final class RulesFlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

/// Owns the complete remapping-rules interface while the shared
/// `RemappingRuleEditorSession` owns the actual editable data and Undo/Redo
/// history for the lifetime of the application process.
@MainActor
final class RemappingRulesWindowController:
    NSWindowController,
    NSWindowDelegate
{
    private enum EditorValidationIssue {
        case incompleteRule
        case duplicateSource
        case identicalSourceAndDestination

        var message: String {
            switch self {
            case .incompleteRule:
                return "Complete every highlighted rule before saving."

            case .duplicateSource:
                return "Each active exact source combination and each Preserve Modifiers source key can appear only once."

            case .identicalSourceAndDestination:
                return "A source and destination key cannot be identical."
            }
        }
    }

    private struct ValidationSnapshot {
        let issue: EditorValidationIssue?
        let invalidItemIDs: Set<UUID>
    }

    private let remappingController: RemappingSettingsControlling
    private let appPreferencesController: AppPreferencesControlling
    private let globalShortcutController: GlobalShortcutController
    private let ruleEditorSession: RemappingRuleEditorSession
    private let increaseTextSizeHandler: () -> Void
    private let decreaseTextSizeHandler: () -> Void
    private let resetTextSizeHandler: () -> Void

    private let ruleRemovalConfirmationController =
        RuleRemovalConfirmationController()

    private let titleLabel = NSTextField(
        labelWithString: "Remapping Rules"
    )

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Record complete combinations, choose how modifiers behave, and add stored exceptions when needed."
    )

    private let confirmRuleRemovalCheckbox = NSButton(
        checkboxWithTitle: "Confirm before removing rules",
        target: nil,
        action: nil
    )

    private let sourceHeader = NSTextField(
        labelWithString: "Source"
    )

    private let destinationHeader = NSTextField(
        labelWithString: "Destination"
    )

    private let behaviorHeader = NSTextField(
        labelWithString: "Modifier behavior"
    )

    private let exceptionsHeader = NSTextField(
        labelWithString: "Exceptions"
    )

    private let rulesScrollView = NSScrollView()
    private let rulesDocumentView = RulesFlippedView()
    private let rulesStackView = NSStackView()
    private let rulesFlexibleSpacer = NSView()

    private let addRuleButton = NSButton()
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private let saveButton = NSButton()

    private let textSizeLabel = NSTextField(
        labelWithString: "Text size"
    )

    private let decreaseTextSizeButton = NSButton()
    private let resetTextSizeButton = NSButton()
    private let increaseTextSizeButton = NSButton()

    private let actionsStack = NSStackView()
    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )
    private let mainStack = NSStackView()

    private var ruleRows: [RemappingRuleRowView] = []
    private var ruleRowsByItemID:
        [UUID: RemappingRuleRowView] = [:]

    private var captureRow: RemappingRuleRowView?
    private var captureField: RemappingRuleRowView.KeyField?

    private var exceptionsWindowController:
        RemapOverridesWindowController?

    private var fnModifierStateTracker =
        FnModifierStateTracker()

    private var textScale: CGFloat

    init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        ruleEditorSession: RemappingRuleEditorSession,
        increaseTextSizeHandler: @escaping () -> Void,
        decreaseTextSizeHandler: @escaping () -> Void,
        resetTextSizeHandler: @escaping () -> Void,
        textScale: CGFloat? = nil
    ) {
        self.remappingController = remappingController
        self.appPreferencesController = appPreferencesController
        self.globalShortcutController = globalShortcutController
        self.ruleEditorSession = ruleEditorSession
        self.increaseTextSizeHandler = increaseTextSizeHandler
        self.decreaseTextSizeHandler = decreaseTextSizeHandler
        self.resetTextSizeHandler = resetTextSizeHandler
        self.textScale = InterfaceTextScalePreference.clamped(
            textScale ?? InterfaceTextScalePreference.currentScale
        )

        let window = RemappingRulesWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 1120,
                height: 760
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "Remapping Rules"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(
            width: 960,
            height: 520
        )
        window.contentMaxSize = NSSize(
            width: 1440,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.center()

        super.init(window: window)

        window.delegate = self
        window.flagsChangedHandler = { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        window.undoHandler = { [weak self] in
            self?.undoRuleEditorChange()
        }
        window.redoHandler = { [weak self] in
            self?.redoRuleEditorChange()
        }
        window.canUndoHandler = { [weak self] in
            self?.canUndoRuleEditorChange ?? false
        }
        window.canRedoHandler = { [weak self] in
            self?.canRedoRuleEditorChange ?? false
        }

        ruleEditorSession.onChange = { [weak self] in
            self?.renderRuleEditor()
        }

        configureContent()
        synchronizeRuleRemovalConfirmationPreference()
        initializeRuleEditorSession()
        applyTextScale(
            self.textScale
        )
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func showWindow(
        _ sender: Any?
    ) {
        if window?.isVisible == false {
            synchronizeRuleRemovalConfirmationPreference()
            renderRuleEditor()
        }

        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
    }

    /// Ends local capture before another application window starts recording
    /// or before the application terminates.
    func endActiveCapture() {
        endKeyCapture()
    }

    func prepareForApplicationTermination() {
        endKeyCapture()
        exceptionsWindowController?.close()
        exceptionsWindowController = nil
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale = InterfaceTextScalePreference.clamped(
            scale
        )

        titleLabel.font = NSFont.systemFont(
            ofSize: 22 * textScale,
            weight: .semibold
        )
        descriptionLabel.font = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        let headerFont = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .medium
        )
        sourceHeader.font = headerFont
        destinationHeader.font = headerFont
        behaviorHeader.font = headerFont
        exceptionsHeader.font = headerFont

        let actionFont = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )
        confirmRuleRemovalCheckbox.font = actionFont
        addRuleButton.font = actionFont
        undoButton.font = actionFont
        redoButton.font = actionFont
        saveButton.font = actionFont
        textSizeLabel.font = actionFont
        decreaseTextSizeButton.font = actionFont
        resetTextSizeButton.font = actionFont
        increaseTextSizeButton.font = actionFont
        statusLabel.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )

        rulesStackView.spacing = 10 * textScale
        actionsStack.spacing = 12 * textScale
        mainStack.spacing = 16 * textScale

        for row in ruleRows {
            row.applyTextScale(textScale)
        }

        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        endKeyCapture()

        guard ruleEditorSession.hasUnsavedChanges else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Save changes before closing?"
        alert.informativeText =
            "Your remapping rules have been modified."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return persistRules()

        case .alertSecondButtonReturn:
            ruleEditorSession.restoreSavedRules()
            return true

        default:
            return false
        }
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        endKeyCapture()
        exceptionsWindowController = nil
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        descriptionLabel.textColor = .secondaryLabelColor
        sourceHeader.textColor = .secondaryLabelColor
        destinationHeader.textColor = .secondaryLabelColor
        behaviorHeader.textColor = .secondaryLabelColor
        exceptionsHeader.textColor = .secondaryLabelColor

        configureRuleRemovalConfirmationPreference()
        configureRulesScrollView()
        configureActionButtons()
        configureTextSizeControls()

        let rulesHeaderView = makeRulesHeaderView()

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                confirmRuleRemovalCheckbox,
                rulesHeaderView
            ],
            in: .leading
        )
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)
        contentView.addSubview(rulesScrollView)
        contentView.addSubview(actionsStack)
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate(
            [
                mainStack.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: 28
                ),
                mainStack.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 28
                ),
                mainStack.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -28
                ),

                rulesHeaderView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),

                rulesScrollView.topAnchor.constraint(
                    equalTo: mainStack.bottomAnchor,
                    constant: 16
                ),
                rulesScrollView.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 28
                ),
                rulesScrollView.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -28
                ),
                rulesScrollView.bottomAnchor.constraint(
                    equalTo: actionsStack.topAnchor,
                    constant: -16
                ),

                actionsStack.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 28
                ),
                actionsStack.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -28
                ),
                actionsStack.bottomAnchor.constraint(
                    equalTo: statusLabel.topAnchor,
                    constant: -8
                ),

                statusLabel.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 28
                ),
                statusLabel.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -28
                ),
                statusLabel.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -28
                )
            ]
        )
    }

    private func makeRulesHeaderView() -> NSView {
        let headerView = NSView()
        let arrowSpacer = NSView()
        let removeSpacer = NSView()

        let views: [NSView] = [
            sourceHeader,
            arrowSpacer,
            destinationHeader,
            behaviorHeader,
            exceptionsHeader,
            removeSpacer
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(view)
        }

        headerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(
            [
                sourceHeader.leadingAnchor.constraint(
                    equalTo: headerView.leadingAnchor,
                    constant: 18
                ),
                sourceHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                sourceHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),

                arrowSpacer.leadingAnchor.constraint(
                    equalTo: sourceHeader.trailingAnchor,
                    constant: 10
                ),
                arrowSpacer.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                destinationHeader.leadingAnchor.constraint(
                    equalTo: arrowSpacer.trailingAnchor,
                    constant: 10
                ),
                destinationHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                destinationHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),

                behaviorHeader.leadingAnchor.constraint(
                    equalTo: destinationHeader.trailingAnchor,
                    constant: 10
                ),
                behaviorHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                behaviorHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),
                behaviorHeader.widthAnchor.constraint(
                    equalToConstant: 168
                ),

                exceptionsHeader.leadingAnchor.constraint(
                    equalTo: behaviorHeader.trailingAnchor,
                    constant: 10
                ),
                exceptionsHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                exceptionsHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),
                exceptionsHeader.widthAnchor.constraint(
                    equalToConstant: 116
                ),

                removeSpacer.leadingAnchor.constraint(
                    equalTo: exceptionsHeader.trailingAnchor,
                    constant: 10
                ),
                removeSpacer.trailingAnchor.constraint(
                    equalTo: headerView.trailingAnchor,
                    constant: -18
                ),
                removeSpacer.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceHeader.widthAnchor.constraint(
                    equalTo: destinationHeader.widthAnchor
                ),
                sourceHeader.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 120
                ),
                headerView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 20
                )
            ]
        )

        return headerView
    }

    private func configureRuleRemovalConfirmationPreference() {
        confirmRuleRemovalCheckbox.target = self
        confirmRuleRemovalCheckbox.action = #selector(
            ruleRemovalConfirmationPreferenceChanged
        )
        confirmRuleRemovalCheckbox.toolTip =
            "Ask for confirmation before removing a remapping rule."
        confirmRuleRemovalCheckbox.setContentHuggingPriority(
            .required,
            for: .vertical
        )
    }

    private func synchronizeRuleRemovalConfirmationPreference() {
        confirmRuleRemovalCheckbox.state =
            appPreferencesController.preferences.confirmsRuleRemoval
                ? .on
                : .off
    }

    @objc
    private func ruleRemovalConfirmationPreferenceChanged() {
        let previousValue =
            appPreferencesController.preferences.confirmsRuleRemoval
        let requestedValue =
            confirmRuleRemovalCheckbox.state == .on

        guard ruleRemovalConfirmationController
            .shouldApplyPreferenceChange(
                from: previousValue,
                to: requestedValue
            ) else {
            synchronizeRuleRemovalConfirmationPreference()
            return
        }

        do {
            try appPreferencesController.setConfirmsRuleRemoval(
                requestedValue
            )
        } catch {
            synchronizeRuleRemovalConfirmationPreference()
            setStatus(
                "The rule removal confirmation preference could not be saved.",
                isError: true
            )
        }
    }

    private func configureRulesScrollView() {
        rulesStackView.orientation = .vertical
        rulesStackView.alignment = .leading
        rulesStackView.distribution = .fill
        rulesStackView.translatesAutoresizingMaskIntoConstraints = false

        rulesFlexibleSpacer.translatesAutoresizingMaskIntoConstraints = false
        rulesFlexibleSpacer.setContentHuggingPriority(
            .defaultLow,
            for: .vertical
        )
        rulesFlexibleSpacer.setContentCompressionResistancePriority(
            .defaultLow,
            for: .vertical
        )

        rulesStackView.addArrangedSubview(
            rulesFlexibleSpacer
        )

        rulesDocumentView.translatesAutoresizingMaskIntoConstraints = false
        rulesDocumentView.addSubview(
            rulesStackView
        )

        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.autohidesScrollers = true
        rulesScrollView.borderType = .bezelBorder
        rulesScrollView.drawsBackground = false
        rulesScrollView.documentView = rulesDocumentView
        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false
        rulesScrollView.setContentHuggingPriority(
            .defaultLow,
            for: .vertical
        )
        rulesScrollView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .vertical
        )

        NSLayoutConstraint.activate(
            [
                rulesStackView.topAnchor.constraint(
                    equalTo: rulesDocumentView.topAnchor,
                    constant: 12
                ),
                rulesStackView.leadingAnchor.constraint(
                    equalTo: rulesDocumentView.leadingAnchor,
                    constant: 12
                ),
                rulesStackView.trailingAnchor.constraint(
                    equalTo: rulesDocumentView.trailingAnchor,
                    constant: -12
                ),
                rulesStackView.bottomAnchor.constraint(
                    equalTo: rulesDocumentView.bottomAnchor,
                    constant: -12
                ),

                rulesFlexibleSpacer.widthAnchor.constraint(
                    equalTo: rulesStackView.widthAnchor
                ),
                rulesFlexibleSpacer.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 0
                ),

                rulesDocumentView.widthAnchor.constraint(
                    equalTo: rulesScrollView.contentView.widthAnchor
                ),
                rulesDocumentView.heightAnchor.constraint(
                    greaterThanOrEqualTo:
                        rulesScrollView.contentView.heightAnchor
                ),
                rulesScrollView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 260
                )
            ]
        )
    }

    private func configureActionButtons() {
        addRuleButton.title = "Add Rule"
        addRuleButton.image = NSImage(
            systemSymbolName: "plus",
            accessibilityDescription: "Add Rule"
        )
        addRuleButton.imagePosition = .imageLeading
        addRuleButton.bezelStyle = .rounded
        addRuleButton.target = self
        addRuleButton.action = #selector(addEmptyRule)

        undoButton.title = "Undo"
        undoButton.image = NSImage(
            systemSymbolName: "arrow.uturn.backward",
            accessibilityDescription: "Undo"
        )
        undoButton.imagePosition = .imageLeading
        undoButton.bezelStyle = .rounded
        undoButton.target = self
        undoButton.action = #selector(undoButtonPressed)
        undoButton.toolTip =
            "Undo the last rule editor change (Command-Z)."

        redoButton.title = "Redo"
        redoButton.image = NSImage(
            systemSymbolName: "arrow.uturn.forward",
            accessibilityDescription: "Redo"
        )
        redoButton.imagePosition = .imageLeading
        redoButton.bezelStyle = .rounded
        redoButton.target = self
        redoButton.action = #selector(redoButtonPressed)
        redoButton.toolTip =
            "Redo the last undone rule editor change (Shift-Command-Z)."

        saveButton.title = "Save Rules"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveRules)

        let spacer = NSView()
        spacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )
        spacer.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        actionsStack.setViews(
            [
                addRuleButton,
                undoButton,
                redoButton,
                saveButton,
                spacer,
                textSizeLabel,
                decreaseTextSizeButton,
                resetTextSizeButton,
                increaseTextSizeButton
            ],
            in: .leading
        )
        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.distribution = .fill
        actionsStack.translatesAutoresizingMaskIntoConstraints = false

        updateRuleEditorHistoryControls()
    }

    private func configureTextSizeControls() {
        decreaseTextSizeButton.title = "−"
        decreaseTextSizeButton.bezelStyle = .rounded
        decreaseTextSizeButton.target = self
        decreaseTextSizeButton.action = #selector(
            decreaseTextSizeButtonPressed
        )
        decreaseTextSizeButton.toolTip =
            "Decrease application text size."

        resetTextSizeButton.title = "Reset"
        resetTextSizeButton.bezelStyle = .rounded
        resetTextSizeButton.target = self
        resetTextSizeButton.action = #selector(
            resetTextSizeButtonPressed
        )
        resetTextSizeButton.toolTip =
            "Restore the default application text size."

        increaseTextSizeButton.title = "+"
        increaseTextSizeButton.bezelStyle = .rounded
        increaseTextSizeButton.target = self
        increaseTextSizeButton.action = #selector(
            increaseTextSizeButtonPressed
        )
        increaseTextSizeButton.toolTip =
            "Increase application text size."
    }

    @objc
    private func decreaseTextSizeButtonPressed() {
        decreaseTextSizeHandler()
    }

    @objc
    private func resetTextSizeButtonPressed() {
        resetTextSizeHandler()
    }

    @objc
    private func increaseTextSizeButtonPressed() {
        increaseTextSizeHandler()
    }

    private func initializeRuleEditorSession() {
        guard !ruleEditorSession.isInitialized else {
            renderRuleEditor()
            return
        }

        do {
            let rules = try remappingController.loadConfiguredRules()
            ruleEditorSession.initialize(
                with: rules
            )
        } catch {
            ruleEditorSession.initialize(
                with: []
            )
            setStatus(
                "The configured rules could not be loaded.",
                isError: true
            )
            saveButton.isEnabled = false
        }
    }

    /// Rebuilds only the visual rows from session-owned state. Persistent
    /// rules are never loaded here, so closing and reopening this window
    /// cannot erase Undo or Redo history.
    private func renderRuleEditor() {
        endKeyCapture()
        removeAllRuleRows()

        for item in ruleEditorSession.items {
            addRuleRow(
                item: item
            )
        }

        refreshChangeState()
        window?.contentView?.needsLayout = true
    }

    private func addRuleRow(
        item: RemappingRuleEditorItem
    ) {
        let row = RemappingRuleRowView(
            item: item
        )

        row.applyTextScale(textScale)

        row.onSourceKeyRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginRuleKeyCapture(
                in: row,
                field: .source
            )
        }

        row.onDestinationKeyRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginRuleKeyCapture(
                in: row,
                field: .destination
            )
        }

        row.onExceptionsRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.showExceptions(
                for: row
            )
        }

        row.onRemoveRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.requestRuleRemoval(
                row
            )
        }

        row.onRuleChanged = {
            [weak self] updatedItem in

            self?.ruleEditorSession.updateItem(
                updatedItem
            )
        }

        ruleRows.append(row)
        ruleRowsByItemID[item.id] = row

        let insertionIndex = max(
            rulesStackView.arrangedSubviews.count - 1,
            0
        )

        rulesStackView.insertArrangedSubview(
            row,
            at: insertionIndex
        )
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(
            equalTo: rulesStackView.widthAnchor
        ).isActive = true
    }

    private func showExceptions(
        for row: RemappingRuleRowView
    ) {
        endKeyCapture()

        guard exceptionsWindowController == nil,
              let parentWindow = window,
              let rule = row.rule else {
            return
        }

        let editorItemID = row.editorItemID

        let controller = RemapOverridesWindowController(
            parentWindow: parentWindow,
            rule: rule,
            remappingController: remappingController,
            textScale: textScale,
            validateCandidateOverrides: {
                [weak self] candidateOverrides in

                self?.validateCandidateOverrides(
                    candidateOverrides,
                    replacingOverridesFor: editorItemID
                )
            },
            onSave: {
                [weak row] overrides in

                row?.setOverrides(overrides)
            },
            onClose: {
                [weak self] in

                self?.exceptionsWindowController = nil
                self?.updateRuleEditorHistoryControls()
            }
        )

        exceptionsWindowController = controller
        updateRuleEditorHistoryControls()
        controller.showAsSheet()
    }

    private func validateCandidateOverrides(
        _ candidateOverrides: [RemapOverride],
        replacingOverridesFor editorItemID: UUID
    ) -> String? {
        var replacedTargetItem = false

        let candidateRules = ruleEditorSession.items.compactMap {
            item -> RemapRule? in

            var candidateItem = item

            if candidateItem.id == editorItemID {
                candidateItem.overrides = candidateOverrides
                replacedTargetItem = true
            }

            return candidateItem.rule
        }

        guard replacedTargetItem else {
            return "The parent remapping rule is no longer available."
        }

        do {
            try RemappingRulesValidator().validate(
                candidateRules
            )
            return nil
        } catch let error as RemappingRulesValidationError {
            return candidateOverrideValidationMessage(
                for: error
            )
        } catch {
            return "The candidate exceptions could not be validated."
        }
    }

    private func candidateOverrideValidationMessage(
        for error: RemappingRulesValidationError
    ) -> String {
        switch error {
        case .duplicateSourceKey,
             .duplicateSourceCombination:
            return "This exception cannot be enabled because its source combination conflicts with an active exact rule or another enabled exception."

        case .duplicatePreservingSourceKey:
            return "The current rules contain more than one Preserve Modifiers rule for the same source key."

        case .identicalSourceAndDestination,
             .identicalSourceAndDestinationCombination:
            return "An exception cannot replace a source combination with itself."

        case .invalidModifierPreservingEndpoints:
            return "A Preserve Modifiers rule must use source and destination keys without modifiers."

        case .overridesRequireModifierPreservingRule:
            return "Stored exceptions are allowed in both matching modes, but they are active only in Preserve Modifiers."

        case .overrideSourceKeyMismatch:
            return "Every exception must use the same physical source key as its parent rule."
        }
    }

    private func scrollToRuleRow(
        _ row: RemappingRuleRowView
    ) {
        rulesDocumentView.layoutSubtreeIfNeeded()
        rulesStackView.layoutSubtreeIfNeeded()

        let visibleRect = row.convert(
            row.bounds,
            to: rulesDocumentView
        )

        rulesDocumentView.scrollToVisible(
            visibleRect
        )
    }

    private func requestRuleRemoval(
        _ row: RemappingRuleRowView
    ) {
        let confirmationRequired =
            appPreferencesController.preferences.confirmsRuleRemoval

        guard ruleRemovalConfirmationController.shouldRemoveRule(
            confirmationRequired: confirmationRequired
        ) else {
            return
        }

        if captureRow === row {
            endKeyCapture()
        }

        ruleEditorSession.removeItem(
            id: row.editorItemID
        )
    }

    private func removeAllRuleRows() {
        for row in ruleRows {
            rulesStackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        ruleRows.removeAll()
        ruleRowsByItemID.removeAll()
    }

    @objc
    private func addEmptyRule() {
        let itemID = ruleEditorSession.insertEmptyItem()

        if let row = ruleRowsByItemID[itemID] {
            scrollToRuleRow(row)
        }
    }

    private func beginRuleKeyCapture(
        in row: RemappingRuleRowView,
        field: RemappingRuleRowView.KeyField
    ) {
        if captureRow === row,
           captureField == field {
            endKeyCapture()
            refreshChangeState()
            return
        }

        endKeyCapture()
        captureRow = row
        captureField = field
        beginCaptureSession()
        row.showCapturePrompt(
            for: field
        )
        updateRuleEditorHistoryControls()

        if row.matchingMode == .preserveModifiers {
            setStatus(
                "Press a physical key. Modifiers are ignored in Preserve Modifiers mode. Click the same field again to cancel.",
                isError: false
            )
        } else {
            setStatus(
                "Press a key combination. Click the same field again to cancel.",
                isError: false
            )
        }
    }

    private func beginCaptureSession() {
        fnModifierStateTracker.synchronize(
            isPressed: PhysicalFnKeyState.isPressed()
        )
        remappingController.beginKeyCapture()
        globalShortcutController.beginShortcutCapture()
    }

    private func handleFlagsChanged(
        _ event: NSEvent
    ) {
        guard captureRow != nil,
              event.keyCode == UInt16(kVK_Function) else {
            return
        }

        fnModifierStateTracker.handleFlagsChanged(
            isPressed:
                event.modifierFlags.contains(.function)
        )
    }

    private func handleKeyDown(
        _ event: NSEvent
    ) -> Bool {
        guard let captureRow,
              let captureField else {
            return false
        }

        if event.keyCode == UInt16(kVK_Escape) {
            endKeyCapture()
            refreshChangeState()
            return true
        }

        let combination = keyCombination(
            from: event
        )
        captureRow.setCombination(
            combination,
            for: captureField
        )
        endKeyCapture()
        refreshChangeState()
        return true
    }

    private func keyCombination(
        from event: NSEvent
    ) -> KeyCombination {
        KeyCombinationInputNormalizer.combination(
            deliveredKeyCode: CGKeyCode(event.keyCode),
            modifiers: KeyModifiers(
                appKitFlags: event.modifierFlags
            ),
            physicalFnIsPressed:
                fnModifierStateTracker.isPressed
        )
    }

    private func endKeyCapture() {
        guard captureRow != nil else {
            return
        }

        captureRow?.restoreButtonTitles()
        captureRow = nil
        captureField = nil

        do {
            try globalShortcutController.endShortcutCapture()
        } catch {
            setStatus(
                "The previous global shortcut could not be restored after key capture.",
                isError: true
            )
        }

        remappingController.endKeyCapture()
        fnModifierStateTracker.reset()
        updateRuleEditorHistoryControls()
    }

    private var canUndoRuleEditorChange: Bool {
        captureRow == nil
            && exceptionsWindowController == nil
            && ruleEditorSession.canUndo
    }

    private var canRedoRuleEditorChange: Bool {
        captureRow == nil
            && exceptionsWindowController == nil
            && ruleEditorSession.canRedo
    }

    @objc
    private func undoButtonPressed() {
        undoRuleEditorChange()
    }

    @objc
    private func redoButtonPressed() {
        redoRuleEditorChange()
    }

    private func undoRuleEditorChange() {
        guard canUndoRuleEditorChange else {
            return
        }

        ruleEditorSession.undo()
    }

    private func redoRuleEditorChange() {
        guard canRedoRuleEditorChange else {
            return
        }

        ruleEditorSession.redo()
    }

    private func updateRuleEditorHistoryControls() {
        undoButton.isEnabled = canUndoRuleEditorChange
        redoButton.isEnabled = canRedoRuleEditorChange
    }

    private func validationSnapshot() -> ValidationSnapshot {
        var invalidItemIDs = Set<UUID>()
        var exactOwners: [KeyCombination: [UUID]] = [:]
        var preservingOwners: [CGKeyCode: [UUID]] = [:]
        var hasIncompleteRule = false
        var hasIdentityRule = false
        var hasDuplicateSource = false

        for item in ruleEditorSession.items {
            guard let rule = item.rule else {
                hasIncompleteRule = true
                invalidItemIDs.insert(item.id)
                continue
            }

            switch rule.matchingMode {
            case .exact:
                exactOwners[
                    rule.source,
                    default: []
                ].append(item.id)

                if rule.source == rule.destination {
                    hasIdentityRule = true
                    invalidItemIDs.insert(item.id)
                }

            case .preserveModifiers:
                preservingOwners[
                    rule.source.keyCode,
                    default: []
                ].append(item.id)

                if rule.source.keyCode
                    == rule.destination.keyCode
                {
                    hasIdentityRule = true
                    invalidItemIDs.insert(item.id)
                }

                for override in rule.overrides
                where override.isEnabled {
                    exactOwners[
                        override.source,
                        default: []
                    ].append(item.id)

                    if case .replaceWith(let destination) =
                        override.action,
                       override.source == destination {
                        hasIdentityRule = true
                        invalidItemIDs.insert(item.id)
                    }
                }
            }
        }

        for owners in exactOwners.values
        where owners.count > 1 {
            hasDuplicateSource = true
            invalidItemIDs.formUnion(owners)
        }

        for owners in preservingOwners.values
        where owners.count > 1 {
            hasDuplicateSource = true
            invalidItemIDs.formUnion(owners)
        }

        let issue: EditorValidationIssue?

        if hasDuplicateSource {
            issue = .duplicateSource
        } else if hasIdentityRule {
            issue = .identicalSourceAndDestination
        } else if hasIncompleteRule {
            issue = .incompleteRule
        } else {
            issue = nil
        }

        return ValidationSnapshot(
            issue: issue,
            invalidItemIDs: invalidItemIDs
        )
    }

    private func applyValidationAppearance(
        _ snapshot: ValidationSnapshot
    ) {
        for (itemID, row) in ruleRowsByItemID {
            row.setValidationErrorVisible(
                snapshot.invalidItemIDs.contains(itemID)
            )
        }
    }

    private func refreshChangeState() {
        let snapshot = validationSnapshot()
        applyValidationAppearance(snapshot)
        updateRuleEditorHistoryControls()

        let hasChanges =
            ruleEditorSession.hasUnsavedChanges
        saveButton.isEnabled =
            snapshot.issue == nil && hasChanges

        if let issue = snapshot.issue {
            setStatus(
                issue.message,
                isError: true
            )
            return
        }

        if let warning = currentRuleConfigurationWarning {
            setSuggestion(
                warning.message
            )
            return
        }

        if !hasChanges {
            if ruleEditorSession.savedRules.isEmpty {
                setStatus(
                    "No remapping rules are configured.",
                    isError: false
                )
            } else {
                setStatus(
                    "Rules are saved locally on this Mac.",
                    isError: false
                )
            }
            return
        }

        setStatus(
            "You have unsaved rule changes.",
            isError: false
        )
    }

    @objc
    private func saveRules() {
        _ = persistRules()
    }

    @discardableResult
    private func persistRules() -> Bool {
        let snapshot = validationSnapshot()
        applyValidationAppearance(snapshot)

        if let issue = snapshot.issue {
            setStatus(
                issue.message,
                isError: true
            )
            return false
        }

        guard let rules = ruleEditorSession.completeRules else {
            setStatus(
                "Complete every highlighted rule before saving.",
                isError: true
            )
            return false
        }

        do {
            try remappingController.replaceConfiguredRules(
                rules
            )
            ruleEditorSession.markCurrentRulesAsSaved(
                rules
            )
            refreshChangeState()
            return true
        } catch let error as RemappingRulesValidationError {
            switch error {
            case .duplicateSourceKey,
                 .duplicateSourceCombination,
                 .duplicatePreservingSourceKey:
                setStatus(
                    "Each active source key or key combination can appear only once.",
                    isError: true
                )

            case .identicalSourceAndDestination,
                 .identicalSourceAndDestinationCombination:
                setStatus(
                    "A source and destination combination cannot be identical.",
                    isError: true
                )

            case .invalidModifierPreservingEndpoints:
                setStatus(
                    "A Preserve Modifiers rule must use source and destination keys without modifiers.",
                    isError: true
                )

            case .overridesRequireModifierPreservingRule:
                setStatus(
                    "Stored exceptions are allowed in both matching modes, but they are active only in Preserve Modifiers.",
                    isError: true
                )

            case .overrideSourceKeyMismatch:
                setStatus(
                    "Every exception must use the same physical source key as its parent rule.",
                    isError: true
                )
            }

            return false
        } catch {
            setStatus(
                "The remapping rules could not be saved.",
                isError: true
            )
            return false
        }
    }

    private var currentRuleConfigurationWarning:
        KeyCombinationConfigurationWarning?
    {
        guard let rules = ruleEditorSession.completeRules else {
            return nil
        }

        return KeyCombinationConfigurationWarningPolicy.warning(
            for: rules
        )
    }

    private func setStatus(
        _ message: String,
        isError: Bool
    ) {
        statusLabel.stringValue = message
        statusLabel.textColor =
            isError ? .systemRed : .secondaryLabelColor
    }

    private func setSuggestion(
        _ message: String
    ) {
        statusLabel.stringValue = message
        statusLabel.textColor = .systemOrange
    }
}
