//
//  SettingsWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A settings window that intercepts a key press only while
/// the user is explicitly selecting a remapping key.
///
/// The handler receives events only from this window.
/// It is not a global keyboard monitor.
@MainActor
private final class SettingsWindow: NSWindow {

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

/// Keeps scrollable content anchored to the top-left corner.
@MainActor
private final class FlippedView: NSView {

    override var isFlipped: Bool {
        true
    }
}

/// Manages the application settings window and its editable
/// collection of remapping rules.
@MainActor
final class SettingsWindowController:
    NSWindowController,
    NSWindowDelegate
{

    private enum TextSizePreference {
        static let storageKey =
            "settingsTextScale.v1"

        static let defaultScale: CGFloat = 1.0
        static let minimumScale: CGFloat = 0.8
        static let maximumScale: CGFloat = 1.4
        static let step: CGFloat = 0.1
    }

    private enum EditorValidationIssue {
        case incompleteRule
        case duplicateSourceKey
        case identicalSourceAndDestination

        var message: String {
            switch self {
            case .incompleteRule:
                return "Complete every highlighted rule before saving."

            case .duplicateSourceKey:
                return "Each source key can appear only once."

            case .identicalSourceAndDestination:
                return "A source and destination key cannot be identical."
            }
        }
    }

    private struct ValidationSnapshot {
        let issue: EditorValidationIssue?
        let invalidRows: Set<ObjectIdentifier>
    }

    private let remappingController:
        RemappingSettingsControlling

    private let appPreferencesController:
        AppPreferencesControlling

    private let titleLabel = NSTextField(
        labelWithString: "Remapping Rules"
    )

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Choose the physical source keys and the keys that macOS should receive."
    )

    private let headerView = NSView()

    private let sourceHeader = NSTextField(
        labelWithString: "Source key"
    )

    private let destinationHeader = NSTextField(
        labelWithString: "Destination key"
    )

    private let launchRemappingCheckbox = NSButton(
        checkboxWithTitle:
            "Enable remapping when the app launches",
        target: nil,
        action: nil
    )

    private let rulesScrollView = NSScrollView()
    private let rulesDocumentView = FlippedView()
    private let rulesStackView = NSStackView()

    private let addRuleButton = NSButton()
    private let saveButton = NSButton()

    private let actionsStack = NSStackView()
    private let mainStack = NSStackView()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private var ruleRows: [RemappingRuleRowView] = []

    /// Last rule collection successfully loaded or saved.
    private var savedRules: [RemapRule] = []

    private var captureRow: RemappingRuleRowView?
    private var captureField:
        RemappingRuleRowView.KeyField?

    private var textScale: CGFloat

    init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController:
            AppPreferencesControlling
    ) {
        self.remappingController = remappingController
        self.appPreferencesController =
            appPreferencesController

        let storedScale = UserDefaults.standard.double(
            forKey: TextSizePreference.storageKey
        )

        if storedScale == 0 {
            textScale = TextSizePreference.defaultScale
        } else {
            textScale = Self.clampedTextScale(
                CGFloat(storedScale)
            )
        }

        let window = SettingsWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 740,
                height: 540
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

        window.title = "LocalKeyRemapper Settings"
        window.isReleasedWhenClosed = false

        window.contentMinSize = NSSize(
            width: 660,
            height: 420
        )

        window.contentMaxSize = NSSize(
            width: 980,
            height: CGFloat.greatestFiniteMagnitude
        )

        window.center()

        super.init(window: window)

        window.delegate = self

        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureContent()
        synchronizeLaunchPreference()
        applyTextScale()
    }

    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible == false {
            synchronizeLaunchPreference()
            loadConfiguredRules()
        }

        super.showWindow(sender)

        window?.center()
        window?.makeKeyAndOrderFront(sender)

        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
    }

    /// Increases the Settings interface text size.
    func increaseTextSize() {
        setTextScale(
            textScale + TextSizePreference.step
        )
    }

    /// Decreases the Settings interface text size.
    func decreaseTextSize() {
        setTextScale(
            textScale - TextSizePreference.step
        )
    }

    /// Restores the default Settings interface text size.
    func resetTextSize() {
        setTextScale(
            TextSizePreference.defaultScale
        )
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        endKeyCapture()

        guard hasUnsavedChanges else {
            return true
        }

        let alert = NSAlert()

        alert.messageText =
            "Save changes before closing?"

        alert.informativeText =
            "Your remapping rules have been modified."

        alert.alertStyle = .warning

        alert.addButton(
            withTitle: "Save"
        )

        alert.addButton(
            withTitle: "Discard Changes"
        )

        alert.addButton(
            withTitle: "Cancel"
        )

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return persistRules()

        case .alertSecondButtonReturn:
            loadConfiguredRules()
            return true

        default:
            return false
        }
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        endKeyCapture()
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        descriptionLabel.textColor =
            .secondaryLabelColor

        sourceHeader.textColor =
            .secondaryLabelColor

        destinationHeader.textColor =
            .secondaryLabelColor

        configureHeaderView()
        configureLaunchPreference()
        configureRulesScrollView()
        configureActionButtons()

        actionsStack.setViews(
            [
                addRuleButton,
                saveButton
            ],
            in: .leading
        )

        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                launchRemappingCheckbox,
                headerView,
                rulesScrollView,
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
                mainStack.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -28
                ),

                rulesScrollView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),

                headerView.widthAnchor.constraint(
                    equalTo:
                        rulesScrollView.contentView.widthAnchor,
                    constant: -24
                )
            ]
        )
    }

    private func configureHeaderView() {
        let arrowSpacer = NSView()
        let removeSpacer = NSView()

        let headerSubviews: [NSView] = [
            sourceHeader,
            arrowSpacer,
            destinationHeader,
            removeSpacer
        ]

        for view in headerSubviews {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            headerView.addSubview(view)
        }

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

                arrowSpacer.leadingAnchor.constraint(
                    equalTo: sourceHeader.trailingAnchor,
                    constant: 12
                ),
                arrowSpacer.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                destinationHeader.leadingAnchor.constraint(
                    equalTo: arrowSpacer.trailingAnchor,
                    constant: 12
                ),
                destinationHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                destinationHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),

                removeSpacer.leadingAnchor.constraint(
                    equalTo: destinationHeader.trailingAnchor,
                    constant: 12
                ),
                removeSpacer.trailingAnchor.constraint(
                    equalTo: headerView.trailingAnchor,
                    constant: -6
                ),
                removeSpacer.widthAnchor.constraint(
                    equalToConstant: 90
                ),

                sourceHeader.widthAnchor.constraint(
                    equalTo: destinationHeader.widthAnchor
                ),

                headerView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 20
                )
            ]
        )
    }

    private func configureLaunchPreference() {
        launchRemappingCheckbox.allowsMixedState = false
        launchRemappingCheckbox.target = self
        launchRemappingCheckbox.action =
            #selector(launchPreferenceChanged)

        launchRemappingCheckbox.toolTip =
            "Automatically attempts to enable remapping after the app launches."
    }

    private func synchronizeLaunchPreference() {
        launchRemappingCheckbox.state =
            appPreferencesController
                .preferences
                .enableRemappingAtLaunch
                ? .on
                : .off
    }

    @objc
    private func launchPreferenceChanged() {
        let previousValue =
            appPreferencesController
                .preferences
                .enableRemappingAtLaunch

        let requestedValue =
            launchRemappingCheckbox.state == .on

        do {
            try appPreferencesController
                .setEnableRemappingAtLaunch(
                    requestedValue
                )

            refreshChangeState()
        } catch {
            launchRemappingCheckbox.state =
                previousValue ? .on : .off

            setStatus(
                "The launch preference could not be saved.",
                isError: true
            )
        }
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

        saveButton.title = "Save Rules"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveRules)
    }

    private func configureRulesScrollView() {
        rulesStackView.orientation = .vertical
        rulesStackView.alignment = .leading
        rulesStackView.distribution = .fill
        rulesStackView.translatesAutoresizingMaskIntoConstraints =
            false

        rulesDocumentView.translatesAutoresizingMaskIntoConstraints =
            false

        rulesDocumentView.addSubview(
            rulesStackView
        )

        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.autohidesScrollers = true
        rulesScrollView.borderType = .bezelBorder
        rulesScrollView.drawsBackground = false
        rulesScrollView.documentView = rulesDocumentView
        rulesScrollView.translatesAutoresizingMaskIntoConstraints =
            false

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

                rulesDocumentView.widthAnchor.constraint(
                    equalTo:
                        rulesScrollView.contentView.widthAnchor
                ),

                rulesDocumentView.heightAnchor.constraint(
                    greaterThanOrEqualTo:
                        rulesScrollView.contentView.heightAnchor
                ),

                rulesScrollView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 140
                )
            ]
        )
    }

    private func loadConfiguredRules() {
        endKeyCapture()
        removeAllRuleRows()

        do {
            let rules =
                try remappingController
                    .loadConfiguredRules()

            savedRules = rules

            for rule in rules {
                addRuleRow(
                    rule: rule,
                    scrollIntoView: false
                )
            }

            refreshChangeState()
        } catch {
            savedRules = []

            setStatus(
                "The configured rules could not be loaded.",
                isError: true
            )

            saveButton.isEnabled = false
        }
    }

    private func addRuleRow(
        rule: RemapRule? = nil,
        scrollIntoView: Bool = true
    ) {
        let row = RemappingRuleRowView(
            rule: rule
        )

        row.applyTextScale(textScale)

        row.onSourceKeyRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginKeyCapture(
                in: row,
                field: .source
            )
        }

        row.onDestinationKeyRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginKeyCapture(
                in: row,
                field: .destination
            )
        }

        row.onRemoveRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.removeRuleRow(row)
        }

        ruleRows.append(row)
        rulesStackView.addArrangedSubview(row)

        row.translatesAutoresizingMaskIntoConstraints =
            false

        row.widthAnchor.constraint(
            equalTo: rulesStackView.widthAnchor
        ).isActive = true

        refreshChangeState()

        if scrollIntoView {
            scrollToRuleRow(row)
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

    private func removeRuleRow(
        _ row: RemappingRuleRowView
    ) {
        if captureRow === row {
            endKeyCapture()
        }

        guard let index = ruleRows.firstIndex(
            where: { $0 === row }
        ) else {
            return
        }

        ruleRows.remove(at: index)
        rulesStackView.removeArrangedSubview(row)
        row.removeFromSuperview()

        refreshChangeState()
    }

    private func removeAllRuleRows() {
        for row in ruleRows {
            rulesStackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        ruleRows.removeAll()
    }

    @objc
    private func addEmptyRule() {
        addRuleRow()
    }

    private func beginKeyCapture(
        in row: RemappingRuleRowView,
        field: RemappingRuleRowView.KeyField
    ) {
        if captureRow != nil {
            endKeyCapture()
        }

        captureRow = row
        captureField = field

        remappingController.beginKeyCapture()

        row.showCapturePrompt(
            for: field
        )

        setStatus(
            "Press a key. Press Escape to cancel.",
            isError: false
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

        let keyCode = CGKeyCode(event.keyCode)

        if Int(keyCode) == kVK_Escape {
            endKeyCapture()
            refreshChangeState()
            return true
        }

        captureRow.setKeyCode(
            keyCode,
            for: captureField
        )

        endKeyCapture()
        refreshChangeState()

        return true
    }

    private func endKeyCapture() {
        guard captureRow != nil else {
            return
        }

        captureRow?.restoreButtonTitles()

        captureRow = nil
        captureField = nil

        remappingController.endKeyCapture()
    }

    /// Returns all current rules only when every row is complete.
    private var completeCurrentRules: [RemapRule]? {
        let rules = ruleRows.compactMap {
            $0.rule
        }

        guard rules.count == ruleRows.count else {
            return nil
        }

        return rules
    }

    /// Indicates whether the editor content differs from the
    /// last successfully loaded or saved rule collection.
    private var hasUnsavedChanges: Bool {
        guard let currentRules = completeCurrentRules else {
            return true
        }

        return normalizedRules(currentRules)
            != normalizedRules(savedRules)
    }

    /// Sorts rules into a stable order before comparison.
    ///
    /// Rule order has no semantic meaning for the remapping engine.
    private func normalizedRules(
        _ rules: [RemapRule]
    ) -> [RemapRule] {
        rules.sorted {
            if $0.sourceKeyCode == $1.sourceKeyCode {
                return $0.destinationKeyCode
                    < $1.destinationKeyCode
            }

            return $0.sourceKeyCode
                < $1.sourceKeyCode
        }
    }

    private func validationSnapshot() -> ValidationSnapshot {
        var invalidRows = Set<ObjectIdentifier>()
        var rowsBySourceKey:
            [CGKeyCode: [RemappingRuleRowView]] = [:]

        var hasIncompleteRule = false
        var hasIdentityRule = false
        var hasDuplicateSourceKey = false

        for row in ruleRows {
            if
                row.sourceKeyCode == nil ||
                row.destinationKeyCode == nil
            {
                hasIncompleteRule = true
                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }

            if
                let sourceKeyCode = row.sourceKeyCode,
                let destinationKeyCode = row.destinationKeyCode,
                sourceKeyCode == destinationKeyCode
            {
                hasIdentityRule = true
                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }

            if let sourceKeyCode = row.sourceKeyCode {
                rowsBySourceKey[
                    sourceKeyCode,
                    default: []
                ].append(row)
            }
        }

        for rows in rowsBySourceKey.values
        where rows.count > 1 {
            hasDuplicateSourceKey = true

            for row in rows {
                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }
        }

        let issue: EditorValidationIssue?

        if hasDuplicateSourceKey {
            issue = .duplicateSourceKey
        } else if hasIdentityRule {
            issue = .identicalSourceAndDestination
        } else if hasIncompleteRule {
            issue = .incompleteRule
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
        for row in ruleRows {
            let isInvalid = snapshot.invalidRows.contains(
                ObjectIdentifier(row)
            )

            row.setValidationErrorVisible(
                isInvalid
            )
        }
    }

    private func refreshChangeState() {
        let snapshot = validationSnapshot()
        applyValidationAppearance(snapshot)

        let hasChanges = hasUnsavedChanges

        saveButton.isEnabled =
            snapshot.issue == nil && hasChanges

        if let issue = snapshot.issue {
            setStatus(
                issue.message,
                isError: true
            )
            return
        }

        if !hasChanges {
            if savedRules.isEmpty {
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
            "You have unsaved changes.",
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

        guard let rules = completeCurrentRules else {
            setStatus(
                "Complete every highlighted rule before saving.",
                isError: true
            )
            return false
        }

        do {
            try remappingController
                .replaceConfiguredRules(rules)

            savedRules = rules
            refreshChangeState()

            return true
        } catch let error as RemappingRulesValidationError {
            switch error {
            case .duplicateSourceKey:
                setStatus(
                    EditorValidationIssue
                        .duplicateSourceKey
                        .message,
                    isError: true
                )

            case .identicalSourceAndDestination:
                setStatus(
                    EditorValidationIssue
                        .identicalSourceAndDestination
                        .message,
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

    private func setStatus(
        _ message: String,
        isError: Bool
    ) {
        statusLabel.stringValue = message
        statusLabel.textColor =
            isError ? .systemRed : .secondaryLabelColor
    }

    private func setTextScale(
        _ proposedScale: CGFloat
    ) {
        let newScale = Self.clampedTextScale(
            proposedScale
        )

        guard newScale != textScale else {
            return
        }

        textScale = newScale

        UserDefaults.standard.set(
            Double(newScale),
            forKey: TextSizePreference.storageKey
        )

        applyTextScale()
    }

    private func applyTextScale() {
        titleLabel.font = NSFont.systemFont(
            ofSize: 22 * textScale,
            weight: .semibold
        )

        descriptionLabel.font = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        sourceHeader.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .medium
        )

        destinationHeader.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .medium
        )

        statusLabel.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )

        let actionFont = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        launchRemappingCheckbox.font = actionFont
        addRuleButton.font = actionFont
        saveButton.font = actionFont

        rulesStackView.spacing = 10 * textScale
        actionsStack.spacing = 12 * textScale
        mainStack.spacing = 16 * textScale

        for row in ruleRows {
            row.applyTextScale(textScale)
        }

        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    private static func clampedTextScale(
        _ scale: CGFloat
    ) -> CGFloat {
        min(
            max(
                scale,
                TextSizePreference.minimumScale
            ),
            TextSizePreference.maximumScale
        )
    }
}
