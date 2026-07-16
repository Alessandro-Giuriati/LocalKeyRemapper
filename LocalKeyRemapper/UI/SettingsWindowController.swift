//
//  SettingsWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit

/// Manages the application settings window.
///
/// The window is created only when the user opens Settings
/// and remains available for future reuse.
@MainActor
final class SettingsWindowController: NSWindowController {

    init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 520,
                height: 320
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

        configureContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)

        window?.center()
        window?.makeKeyAndOrderFront(sender)

        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
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
                "Configurable remapping rules will be added here."
        )

        descriptionLabel.textColor = .secondaryLabelColor

        let currentRuleLabel = NSTextField(
            labelWithString: "Current rule: V → W"
        )

        currentRuleLabel.font = NSFont.systemFont(
            ofSize: 14,
            weight: .regular
        )

        let stackView = NSStackView(
            views: [
                titleLabel,
                descriptionLabel,
                currentRuleLabel
            ]
        )

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate(
            [
                stackView.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: 28
                ),
                stackView.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 28
                ),
                stackView.trailingAnchor.constraint(
                    lessThanOrEqualTo: contentView.trailingAnchor,
                    constant: -28
                )
            ]
        )
    }
}
