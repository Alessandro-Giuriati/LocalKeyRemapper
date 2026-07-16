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

        let arrowLabel = NSTextField(
            labelWithString: "→"
        )

        arrowLabel.font = NSFont.systemFont(
            ofSize: 18,
            weight: .regular
        )

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(requestRemoval)

        let stackView = NSStackView(
            views: [
                sourceKeyButton,
                arrowLabel,
                destinationKeyButton,
                removeButton
            ]
        )

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints =
            false

        addSubview(stackView)

        NSLayoutConstraint.activate(
            [
                stackView.topAnchor.constraint(
                    equalTo: topAnchor
                ),
                stackView.leadingAnchor.constraint(
                    equalTo: leadingAnchor
                ),
                stackView.trailingAnchor.constraint(
                    equalTo: trailingAnchor
                ),
                stackView.bottomAnchor.constraint(
                    equalTo: bottomAnchor
                ),

                sourceKeyButton.widthAnchor.constraint(
                    equalToConstant: 160
                ),
                destinationKeyButton.widthAnchor.constraint(
                    equalToConstant: 160
                ),
                removeButton.widthAnchor.constraint(
                    equalToConstant: 80
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
