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

    private var rowHeightConstraint:
        NSLayoutConstraint?

    private var isShowingValidationError = false
    private var textScale: CGFloat = 1.0

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
        updateValidationAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateValidationAppearance()
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

    /// Highlights this row when its rule is incomplete or invalid.
    func setValidationErrorVisible(
        _ isVisible: Bool
    ) {
        guard
            isShowingValidationError != isVisible
        else {
            return
        }

        isShowingValidationError = isVisible
        updateValidationAppearance()
    }

    /// Applies the text scale selected in the Settings window.
    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale = scale

        let controlFont = NSFont.systemFont(
            ofSize: 14 * scale,
            weight: .regular
        )

        sourceKeyButton.font = controlFont
        destinationKeyButton.font = controlFont

        removeButton.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )

        arrowLabel.font = NSFont.systemFont(
            ofSize: 20 * scale,
            weight: .regular
        )

        rowHeightConstraint?.constant = 40 * scale

        needsLayout = true
    }

    private func configureContent() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        configureKeyButton(
            sourceKeyButton,
            action: #selector(requestSourceKey)
        )

        configureKeyButton(
            destinationKeyButton,
            action: #selector(requestDestinationKey)
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

        let rowHeightConstraint = heightAnchor.constraint(
            equalToConstant: 40
        )

        self.rowHeightConstraint = rowHeightConstraint

        NSLayoutConstraint.activate(
            [
                sourceKeyButton.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: 6
                ),
                sourceKeyButton.topAnchor.constraint(
                    equalTo: topAnchor,
                    constant: 4
                ),
                sourceKeyButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -4
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
                    equalTo: topAnchor,
                    constant: 4
                ),
                destinationKeyButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -4
                ),

                removeButton.leadingAnchor.constraint(
                    equalTo:
                        destinationKeyButton.trailingAnchor,
                    constant: 12
                ),
                removeButton.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -6
                ),
                removeButton.topAnchor.constraint(
                    equalTo: topAnchor,
                    constant: 4
                ),
                removeButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -4
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

                rowHeightConstraint
            ]
        )

        applyTextScale(textScale)
    }

    private func configureKeyButton(
        _ button: NSButton,
        action: Selector
    ) {
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func updateValidationAppearance() {
        guard let layer else {
            return
        }

        if isShowingValidationError {
            layer.borderWidth = 1.5
            layer.borderColor = NSColor.systemRed.cgColor
            layer.backgroundColor = NSColor.systemRed
                .withAlphaComponent(0.08)
                .cgColor
        } else {
            layer.borderWidth = 0
            layer.borderColor = NSColor.clear.cgColor
            layer.backgroundColor = NSColor.clear.cgColor
        }
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
