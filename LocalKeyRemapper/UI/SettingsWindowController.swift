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

/// Manages the application settings window and its editable
/// collection of remapping rules.
@MainActor
final class SettingsWindowController:
    NSWindowController,
    NSWindowDelegate
{

    private let remappingController:
        RemappingSettingsControlling

    private let rulesStackView = NSStackView()
    private let addRuleButton = NSButton()
    private let saveButton = NSButton()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private var ruleRows: [RemappingRuleRowView] = []

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
                width: 650,
                height: 420
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

        window.minSize = NSSize(
            width: 600,
            height: 360
        )

        window.center()

        super.init(window: window)

        window.delegate = self

        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureContent()
        loadConfiguredRules()
    }

    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func showWindow(_ sender: Any?) {
        loadConfiguredRules()

        super.showWindow(sender)

        window?.center()
        window?.makeKeyAndOrderFront(sender)

        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
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

        let sourceHeader = NSTextField(
            labelWithString: "Source key"
        )

        sourceHeader.font = NSFont.systemFont(
            ofSize: 12,
            weight: .medium
        )

        sourceHeader.textColor =
            .secondaryLabelColor

        let destinationHeader = NSTextField(
            labelWithString: "Destination key"
        )

        destinationHeader.font = NSFont.systemFont(
            ofSize: 12,
            weight: .medium
        )

        destinationHeader.textColor =
            .secondaryLabelColor

        let spacer = NSView()

        let headerStack = NSStackView(
            views: [
                sourceHeader,
                spacer,
                destinationHeader
            ]
        )

        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 14

        sourceHeader.widthAnchor.constraint(
            equalToConstant: 160
        ).isActive = true

        spacer.widthAnchor.constraint(
            equalToConstant: 18
        ).isActive = true

        destinationHeader.widthAnchor.constraint(
            equalToConstant: 160
        ).isActive = true

        rulesStackView.orientation = .vertical
        rulesStackView.alignment = .leading
        rulesStackView.spacing = 10

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
                headerStack,
                rulesStackView,
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
                    lessThanOrEqualTo:
                        contentView.trailingAnchor,
                    constant: -28
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

            for rule in rules {
                addRuleRow(rule: rule)
            }

            if rules.isEmpty {
                statusLabel.stringValue =
                    "No remapping rules are currently configured."
            } else {
                statusLabel.stringValue =
                    "Changes are stored in memory until the app quits."
            }

            updateSaveButton()
            resizeWindowToFitRows()
        } catch {
            statusLabel.stringValue =
                "The configured rules could not be loaded."

            saveButton.isEnabled = false
        }
    }

    private func addRuleRow(
        rule: RemapRule? = nil
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

        updateSaveButton()
        resizeWindowToFitRows()
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

        updateSaveButton()
        resizeWindowToFitRows()

        statusLabel.stringValue =
            "Rule removed. Save the rules to apply the change."
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
        updateSaveButton()

        statusLabel.stringValue =
            "Key selected. Save the rules to apply the change."

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

    private func updateSaveButton() {
        saveButton.isEnabled =
            ruleRows.allSatisfy {
                $0.rule != nil
            }
    }

    @objc
    private func saveRules() {
        let rules = ruleRows.compactMap {
            $0.rule
        }

        guard rules.count == ruleRows.count else {
            statusLabel.stringValue =
                "Complete every rule before saving."

            return
        }

        guard !containsDuplicateSourceKeys(
            in: rules
        ) else {
            statusLabel.stringValue =
                "Each source key can appear only once."

            return
        }

        guard !containsIdentityRule(
            in: rules
        ) else {
            statusLabel.stringValue =
                "A source and destination key cannot be identical."

            return
        }

        do {
            try remappingController
                .replaceConfiguredRules(rules)

            switch rules.count {
            case 0:
                statusLabel.stringValue =
                    "All remapping rules were removed."

            case 1:
                statusLabel.stringValue =
                    "1 remapping rule applied."

            default:
                statusLabel.stringValue =
                    "\(rules.count) remapping rules applied."
            }
        } catch {
            statusLabel.stringValue =
                "The remapping rules could not be saved."
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

    private func resizeWindowToFitRows() {
        guard let window else {
            return
        }

        let rowHeight: CGFloat = 42
        let baseHeight: CGFloat = 350

        let requestedHeight =
            baseHeight
            + CGFloat(ruleRows.count) * rowHeight

        let maximumHeight =
            window.screen?.visibleFrame.height
            ?? 700

        let newHeight = min(
            max(requestedHeight, 380),
            maximumHeight
        )

        guard abs(window.frame.height - newHeight) > 1 else {
            return
        }

        var frame = window.frame

        let currentTop = frame.maxY

        frame.size.height = newHeight
        frame.origin.y = currentTop - newHeight

        window.setFrame(
            frame,
            display: true,
            animate: window.isVisible
        )
    }
}
