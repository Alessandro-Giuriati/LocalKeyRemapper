//
//  SettingsWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A settings window that can intercept a key press only while
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

/// Manages the application settings window.
@MainActor
final class SettingsWindowController:
    NSWindowController,
    NSWindowDelegate
{

    private enum CaptureTarget {
        case source
        case destination
    }

    private let remappingController:
        RemappingSettingsControlling

    private let sourceKeyButton = NSButton()
    private let destinationKeyButton = NSButton()
    private let saveButton = NSButton()
    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private var sourceKeyCode: CGKeyCode?
    private var destinationKeyCode: CGKeyCode?
    private var captureTarget: CaptureTarget?

    init(
        remappingController: RemappingSettingsControlling
    ) {
        self.remappingController = remappingController

        let window = SettingsWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 560,
                height: 310
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "LocalKeyRemapper Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self

        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureContent()
        loadConfiguredRule()
    }

    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func showWindow(_ sender: Any?) {
        loadConfiguredRule()

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
                "Choose the physical source key and the key that macOS should receive."
        )

        descriptionLabel.textColor =
            .secondaryLabelColor

        let sourceLabel = NSTextField(
            labelWithString: "Source key"
        )

        let destinationLabel = NSTextField(
            labelWithString: "Destination key"
        )

        configureKeyButton(
            sourceKeyButton,
            action: #selector(captureSourceKey)
        )

        configureKeyButton(
            destinationKeyButton,
            action: #selector(captureDestinationKey)
        )

        let sourceStack = NSStackView(
            views: [
                sourceLabel,
                sourceKeyButton
            ]
        )

        sourceStack.orientation = .vertical
        sourceStack.alignment = .leading
        sourceStack.spacing = 8

        let destinationStack = NSStackView(
            views: [
                destinationLabel,
                destinationKeyButton
            ]
        )

        destinationStack.orientation = .vertical
        destinationStack.alignment = .leading
        destinationStack.spacing = 8

        let arrowLabel = NSTextField(
            labelWithString: "→"
        )

        arrowLabel.font = NSFont.systemFont(
            ofSize: 24,
            weight: .regular
        )

        let ruleStack = NSStackView(
            views: [
                sourceStack,
                arrowLabel,
                destinationStack
            ]
        )

        ruleStack.orientation = .horizontal
        ruleStack.alignment = .centerY
        ruleStack.spacing = 18

        saveButton.title = "Save Rule"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveRule)

        statusLabel.textColor =
            .secondaryLabelColor

        statusLabel.font = NSFont.systemFont(
            ofSize: 12
        )

        let mainStack = NSStackView(
            views: [
                titleLabel,
                descriptionLabel,
                ruleStack,
                saveButton,
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
                ),
                sourceKeyButton.widthAnchor.constraint(
                    equalToConstant: 170
                ),
                destinationKeyButton.widthAnchor.constraint(
                    equalToConstant: 170
                )
            ]
        )
    }

    private func configureKeyButton(
        _ button: NSButton,
        action: Selector
    ) {
        button.title = "Choose Key…"
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func loadConfiguredRule() {
        do {
            let rules =
                try remappingController
                    .loadConfiguredRules()

            guard let rule = rules.first else {
                sourceKeyCode = nil
                destinationKeyCode = nil

                updateButtonTitles()
                updateSaveButton()

                statusLabel.stringValue =
                    "No remapping rule is currently configured."

                return
            }

            sourceKeyCode = rule.sourceKeyCode
            destinationKeyCode =
                rule.destinationKeyCode

            updateButtonTitles()
            updateSaveButton()

            statusLabel.stringValue =
                "Changes are stored in memory until the app quits."
        } catch {
            statusLabel.stringValue =
                "The configured rule could not be loaded."

            saveButton.isEnabled = false
        }
    }

    @objc
    private func captureSourceKey() {
        beginKeyCapture(for: .source)
    }

    @objc
    private func captureDestinationKey() {
        beginKeyCapture(for: .destination)
    }

    private func beginKeyCapture(
        for target: CaptureTarget
    ) {
        if captureTarget != nil {
            endKeyCapture()
        }

        captureTarget = target
        remappingController.beginKeyCapture()

        switch target {
        case .source:
            sourceKeyButton.title = "Press a key…"

        case .destination:
            destinationKeyButton.title =
                "Press a key…"
        }

        statusLabel.stringValue =
            "Press a key. Press Escape to cancel."
    }

    private func handleKeyDown(
        _ event: NSEvent
    ) -> Bool {
        guard let captureTarget else {
            return false
        }

        let keyCode = CGKeyCode(event.keyCode)

        if Int(keyCode) == kVK_Escape {
            endKeyCapture()

            statusLabel.stringValue =
                "Key selection cancelled."

            return true
        }

        switch captureTarget {
        case .source:
            sourceKeyCode = keyCode

        case .destination:
            destinationKeyCode = keyCode
        }

        endKeyCapture()
        updateButtonTitles()
        updateSaveButton()

        statusLabel.stringValue =
            "Key selected. Save the rule to apply it."

        return true
    }

    private func endKeyCapture() {
        guard captureTarget != nil else {
            return
        }

        captureTarget = nil
        remappingController.endKeyCapture()

        updateButtonTitles()
    }

    private func updateButtonTitles() {
        if let sourceKeyCode {
            sourceKeyButton.title =
                KeyCodeDisplayName.name(
                    for: sourceKeyCode
                )
        } else {
            sourceKeyButton.title = "Choose Key…"
        }

        if let destinationKeyCode {
            destinationKeyButton.title =
                KeyCodeDisplayName.name(
                    for: destinationKeyCode
                )
        } else {
            destinationKeyButton.title =
                "Choose Key…"
        }
    }

    private func updateSaveButton() {
        saveButton.isEnabled =
            sourceKeyCode != nil
            && destinationKeyCode != nil
    }

    @objc
    private func saveRule() {
        guard
            let sourceKeyCode,
            let destinationKeyCode
        else {
            return
        }

        let rule = RemapRule(
            sourceKeyCode: sourceKeyCode,
            destinationKeyCode:
                destinationKeyCode
        )

        do {
            try remappingController
                .replaceConfiguredRules([rule])

            let sourceName =
                KeyCodeDisplayName.name(
                    for: sourceKeyCode
                )

            let destinationName =
                KeyCodeDisplayName.name(
                    for: destinationKeyCode
                )

            statusLabel.stringValue =
                "Rule applied: \(sourceName) → \(destinationName)"
        } catch {
            statusLabel.stringValue =
                "The remapping rule could not be saved."
        }
    }
}
