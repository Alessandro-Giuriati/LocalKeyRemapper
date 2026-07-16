//
//  RemappingRuleRowView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import CoreGraphics

/// Displays and edits one remapping rule.
///
/// The row owns only its visual state.
/// The Settings window remains responsible for keyboard capture,
/// validation, saving, and removing rules.
@MainActor
final class RemappingRuleRowView: NSView {

    enum KeyField {
        case source
        case destination
    }

    var onSourceKeyRequested: (() -> Void)?
    var onDestinationKeyRequested: (() -> Void)?
    var onRemoveRequested: (() -> Void)?

    private let sourceKeyButton = NSButton()
    private let arrowLabel = NSTextField(
        labelWithString: "→"
    )
    private let destinationKeyButton = NSButton()
    private let removeButton = NSButton()

    private(set) var sourceKeyCode: CGKeyCode?
    private(set) var destinationKeyCode: CGKeyCode?

    /// Returns a complete remapping rule when both keys
    /// have been selected.
    var rule: RemapRule? {
        guard
            let sourceKeyCode,
            let destinationKeyCode
        else {
            return nil
        }

        return RemapRule(
            sourceKeyCode: sourceKeyCode,
            destinationKeyCode: destinationKeyCode
        )
    }

    init(rule: RemapRule? = nil) {
        sourceKeyCode = rule?.sourceKeyCode
        destinationKeyCode = rule?.destinationKeyCode

        super.init(frame: .zero)

        configureContent()
        restoreButtonTitles()
    }

    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    /// Updates one of the two key codes represented by this row.
    func setKeyCode(
        _ keyCode: CGKeyCode,
        for field: KeyField
    ) {
        switch field {
        case .source:
            sourceKeyCode = keyCode

        case .destination:
            destinationKeyCode = keyCode
        }

        restoreButtonTitles()
    }

    /// Shows that this row is waiting for a physical key press.
    func showCapturePrompt(
        for field: KeyField
    ) {
        restoreButtonTitles()

        switch field {
        case .source:
            sourceKeyButton.title = "Press a key…"

        case .destination:
            destinationKeyButton.title = "Press a key…"
        }
    }

    /// Restores the readable names of the selected keys.
    func restoreButtonTitles() {
        sourceKeyButton.title = buttonTitle(
            for: sourceKeyCode
        )

        destinationKeyButton.title = buttonTitle(
            for: destinationKeyCode
        )
    }

    private func configureContent() {
        configureKeyButton(
            sourceKeyButton,
            action: #selector(requestSourceKey)
        )

        configureKeyButton(
            destinationKeyButton,
            action: #selector(requestDestinationKey)
        )

        arrowLabel.font = NSFont.systemFont(
            ofSize: 18,
            weight: .regular
        )

        arrowLabel.alignment = .center

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(requestRemoval)

        let views: [NSView] = [
            sourceKeyButton,
            arrowLabel,
            destinationKeyButton,
            removeButton
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            addSubview(view)
        }

        NSLayoutConstraint.activate(
            [
                sourceKeyButton.leadingAnchor.constraint(
                    equalTo: leadingAnchor
                ),
                sourceKeyButton.topAnchor.constraint(
                    equalTo: topAnchor
                ),
                sourceKeyButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor
                ),

                arrowLabel.leadingAnchor.constraint(
                    equalTo: sourceKeyButton.trailingAnchor,
                    constant: 12
                ),
                arrowLabel.centerYAnchor.constraint(
                    equalTo: sourceKeyButton.centerYAnchor
                ),
                arrowLabel.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                destinationKeyButton.leadingAnchor.constraint(
                    equalTo: arrowLabel.trailingAnchor,
                    constant: 12
                ),
                destinationKeyButton.topAnchor.constraint(
                    equalTo: topAnchor
                ),
                destinationKeyButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor
                ),

                removeButton.leadingAnchor.constraint(
                    equalTo:
                        destinationKeyButton.trailingAnchor,
                    constant: 12
                ),
                removeButton.trailingAnchor.constraint(
                    equalTo: trailingAnchor
                ),
                removeButton.topAnchor.constraint(
                    equalTo: topAnchor
                ),
                removeButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor
                ),

                sourceKeyButton.widthAnchor.constraint(
                    equalTo:
                        destinationKeyButton.widthAnchor
                ),

                sourceKeyButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 140
                ),

                destinationKeyButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 140
                ),

                removeButton.widthAnchor.constraint(
                    equalToConstant: 90
                ),

                heightAnchor.constraint(
                    equalToConstant: 32
                )
            ]
        )
    }

    private func configureKeyButton(
        _ button: NSButton,
        action: Selector
    ) {
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func buttonTitle(
        for keyCode: CGKeyCode?
    ) -> String {
        guard let keyCode else {
            return "Choose Key…"
        }

        return KeyCodeDisplayName.name(
            for: keyCode
        )
    }

    @objc
    private func requestSourceKey() {
        onSourceKeyRequested?()
    }

    @objc
    private func requestDestinationKey() {
        onDestinationKeyRequested?()
    }

    @objc
    private func requestRemoval() {
        onRemoveRequested?()
    }
}
