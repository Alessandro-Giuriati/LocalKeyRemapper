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

    private let remappingController:
        RemappingSettingsControlling

    private let rulesScrollView = NSScrollView()
    private let rulesDocumentView = FlippedView()
    private let rulesStackView = NSStackView()

    private let addRuleButton = NSButton()
    private let saveButton = NSButton()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private var ruleRows: [RemappingRuleRowView] = []

    /// Last rule collection successfully loaded or saved.
    private var savedRules: [RemapRule] = []

    private var captureRow: RemappingRuleRowView?
    private var captureField:
        RemappingRuleRowView.KeyField?

    init(
        remappingController: RemappingSettingsControlling
    ) {
        self.remappingController = remappingController

        let window = SettingsWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 720,
                height: 520
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
            width: 640,
            height: 400
        )

        window.contentMaxSize = NSSize(
            width: 820,
            height: CGFloat.greatestFiniteMagnitude
        )

        window.center()

        super.init(window: window)

        window.delegate = self

        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureContent()
    }

    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible == false {
            loadConfiguredRules()
        }

        super.showWindow(sender)

        window?.center()
        window?.makeKeyAndOrderFront(sender)

        NSApplication.shared.activate(
            ignoringOtherApps: true
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

        let titleLabel = NSTextField(
            labelWithString: "Remapping Rules"
        )

        titleLabel.font = NSFont.systemFont(
            ofSize: 20,
            weight: .semibold
        )

        let descriptionLabel = NSTextField(
            wrappingLabelWithString:
                "Choose the physical source keys and the keys that macOS should receive."
        )

        descriptionLabel.textColor =
            .secondaryLabelColor

        let headerView = NSView()

        let sourceHeader = NSTextField(
            labelWithString: "Source key"
        )

        sourceHeader.font = NSFont.systemFont(
            ofSize: 12,
            weight: .medium
        )

        sourceHeader.textColor =
            .secondaryLabelColor

        let arrowSpacer = NSView()

        let destinationHeader = NSTextField(
            labelWithString: "Destination key"
        )

        destinationHeader.font = NSFont.systemFont(
            ofSize: 12,
            weight: .medium
        )

        destinationHeader.textColor =
            .secondaryLabelColor

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
                    equalTo: headerView.leadingAnchor
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
                    equalTo: headerView.trailingAnchor
                ),
                removeSpacer.widthAnchor.constraint(
                    equalToConstant: 90
                ),

                sourceHeader.widthAnchor.constraint(
                    equalTo: destinationHeader.widthAnchor
                ),

                headerView.heightAnchor.constraint(
                    equalToConstant: 18
                )
            ]
        )

        configureRulesScrollView()

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

        statusLabel.textColor =
            .secondaryLabelColor

        statusLabel.font = NSFont.systemFont(
            ofSize: 12
        )

        let actionsStack = NSStackView(
            views: [
                addRuleButton,
                saveButton
            ]
        )

        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.spacing = 12

        let mainStack = NSStackView(
            views: [
                titleLabel,
                descriptionLabel,
                headerView,
                rulesScrollView,
                actionsStack,
                statusLabel
            ]
        )

        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
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

    private func configureRulesScrollView() {
        rulesStackView.orientation = .vertical
        rulesStackView.alignment = .leading
        rulesStackView.distribution = .fill
        rulesStackView.spacing = 10
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
                    greaterThanOrEqualToConstant: 120
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

            statusLabel.stringValue =
                "The configured rules could not be loaded."

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

        statusLabel.stringValue =
            "Choose both keys for the new rule."
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

        statusLabel.stringValue =
            "Press a key. Press Escape to cancel."
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

            statusLabel.stringValue =
                "Key selection cancelled."

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

    private func refreshChangeState() {
        let rulesAreComplete =
            completeCurrentRules != nil

        saveButton.isEnabled =
            rulesAreComplete
            && hasUnsavedChanges

        if !hasUnsavedChanges {
            if savedRules.isEmpty {
                statusLabel.stringValue =
                    "No remapping rules are configured."
            } else {
                statusLabel.stringValue =
                    "Rules are saved locally on this Mac."
            }

            return
        }

        if !rulesAreComplete {
            statusLabel.stringValue =
                "Complete every rule before saving."
        } else {
            statusLabel.stringValue =
                "You have unsaved changes."
        }
    }

    @objc
    private func saveRules() {
        _ = persistRules()
    }

    @discardableResult
    private func persistRules() -> Bool {
        guard let rules = completeCurrentRules else {
            statusLabel.stringValue =
                "Complete every rule before saving."

            return false
        }

        guard !containsDuplicateSourceKeys(
            in: rules
        ) else {
            statusLabel.stringValue =
                "Each source key can appear only once."

            return false
        }

        guard !containsIdentityRule(
            in: rules
        ) else {
            statusLabel.stringValue =
                "A source and destination key cannot be identical."

            return false
        }

        do {
            try remappingController
                .replaceConfiguredRules(rules)

            savedRules = rules
            refreshChangeState()

            return true
        } catch {
            statusLabel.stringValue =
                "The remapping rules could not be saved."

            return false
        }
    }

    private func containsDuplicateSourceKeys(
        in rules: [RemapRule]
    ) -> Bool {
        let sourceKeyCodes = rules.map {
            $0.sourceKeyCode
        }

        return Set(sourceKeyCodes).count
            != sourceKeyCodes.count
    }

    private func containsIdentityRule(
        in rules: [RemapRule]
    ) -> Bool {
        rules.contains {
            $0.sourceKeyCode
                == $0.destinationKeyCode
        }
    }
}
