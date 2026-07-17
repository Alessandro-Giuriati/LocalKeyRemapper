//
//  RemapOverrideRowView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import AppKit

/// Displays and edits one exact exception belonging to a
/// modifier-preserving remapping rule.
@MainActor
final class RemapOverrideRowView: NSView {

    enum KeyField: Equatable {
        case source
        case destination
    }

    private enum ActionKind: Equatable {
        case passThrough
        case replace
    }

    var onSourceRequested: (() -> Void)?
    var onDestinationRequested: (() -> Void)?
    var onRemoveRequested: (() -> Void)?
    var onChange: (() -> Void)?

    private let sourceButton = NSButton()
    private let arrowLabel = NSTextField(labelWithString: "→")
    private let actionPopUpButton = NSPopUpButton()
    private let destinationButton = NSButton()
    private let removeButton = NSButton()

    private var rowHeightConstraint: NSLayoutConstraint?
    private var actionKind: ActionKind
    private var isShowingValidationError = false
    private var textScale: CGFloat = 1.0

    private(set) var sourceCombination: KeyCombination?
    private(set) var destinationCombination: KeyCombination?

    var override: RemapOverride? {
        guard let sourceCombination else {
            return nil
        }

        switch actionKind {
        case .passThrough:
            return RemapOverride(
                source: sourceCombination,
                action: .passThrough
            )

        case .replace:
            guard let destinationCombination else {
                return nil
            }

            return RemapOverride(
                source: sourceCombination,
                action: .replaceWith(destinationCombination)
            )
        }
    }

    var hasIdentityReplacement: Bool {
        guard
            actionKind == .replace,
            let sourceCombination,
            let destinationCombination
        else {
            return false
        }

        return sourceCombination == destinationCombination
    }

    init(override: RemapOverride? = nil) {
        sourceCombination = override?.source

        switch override?.action {
        case .replaceWith(let destination):
            actionKind = .replace
            destinationCombination = destination

        case .passThrough, .none:
            actionKind = .passThrough
            destinationCombination = nil
        }

        super.init(frame: .zero)

        configureContent()
        synchronizeActionControl()
        updateControls()
        updateValidationAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateValidationAppearance()
    }

    func setCombination(
        _ combination: KeyCombination,
        for field: KeyField
    ) {
        switch field {
        case .source:
            sourceCombination = combination

        case .destination:
            destinationCombination = combination
        }

        updateControls()
        onChange?()
    }

    func showCapturePrompt(for field: KeyField) {
        restoreButtonTitles()

        switch field {
        case .source:
            sourceButton.title = "Press combination…"

        case .destination:
            destinationButton.title = "Press combination…"
        }
    }

    func restoreButtonTitles() {
        sourceButton.title = title(
            for: sourceCombination,
            fallback: "Choose Combination…"
        )

        destinationButton.title = title(
            for: destinationCombination,
            fallback: "Choose Destination…"
        )

        if actionKind == .passThrough {
            destinationButton.title = "Original Event"
        }
    }

    func setValidationErrorVisible(_ isVisible: Bool) {
        guard isShowingValidationError != isVisible else {
            return
        }

        isShowingValidationError = isVisible
        updateValidationAppearance()
    }

    func applyTextScale(_ scale: CGFloat) {
        textScale = scale

        let controlFont = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )

        sourceButton.font = controlFont
        destinationButton.font = controlFont
        actionPopUpButton.font = controlFont
        removeButton.font = controlFont
        arrowLabel.font = NSFont.systemFont(
            ofSize: 19 * scale,
            weight: .regular
        )

        rowHeightConstraint?.constant = 42 * scale
        needsLayout = true
    }

    private func configureContent() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        configureButton(
            sourceButton,
            action: #selector(requestSource)
        )

        configureButton(
            destinationButton,
            action: #selector(requestDestination)
        )

        arrowLabel.alignment = .center

        actionPopUpButton.addItems(
            withTitles: [
                "Keep Original",
                "Replace With"
            ]
        )
        actionPopUpButton.target = self
        actionPopUpButton.action = #selector(actionChanged)

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(requestRemoval)

        let views: [NSView] = [
            sourceButton,
            arrowLabel,
            actionPopUpButton,
            destinationButton,
            removeButton
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        let rowHeightConstraint = heightAnchor.constraint(
            equalToConstant: 42
        )
        self.rowHeightConstraint = rowHeightConstraint

        NSLayoutConstraint.activate(
            [
                sourceButton.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: 6
                ),
                sourceButton.topAnchor.constraint(
                    equalTo: topAnchor,
                    constant: 4
                ),
                sourceButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -4
                ),

                arrowLabel.leadingAnchor.constraint(
                    equalTo: sourceButton.trailingAnchor,
                    constant: 10
                ),
                arrowLabel.centerYAnchor.constraint(
                    equalTo: sourceButton.centerYAnchor
                ),
                arrowLabel.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                actionPopUpButton.leadingAnchor.constraint(
                    equalTo: arrowLabel.trailingAnchor,
                    constant: 10
                ),
                actionPopUpButton.centerYAnchor.constraint(
                    equalTo: sourceButton.centerYAnchor
                ),
                actionPopUpButton.widthAnchor.constraint(
                    equalToConstant: 132
                ),

                destinationButton.leadingAnchor.constraint(
                    equalTo: actionPopUpButton.trailingAnchor,
                    constant: 10
                ),
                destinationButton.centerYAnchor.constraint(
                    equalTo: sourceButton.centerYAnchor
                ),

                removeButton.leadingAnchor.constraint(
                    equalTo: destinationButton.trailingAnchor,
                    constant: 10
                ),
                removeButton.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -6
                ),
                removeButton.centerYAnchor.constraint(
                    equalTo: sourceButton.centerYAnchor
                ),
                removeButton.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceButton.widthAnchor.constraint(
                    equalTo: destinationButton.widthAnchor
                ),
                sourceButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 180
                ),
                destinationButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 180
                ),

                rowHeightConstraint
            ]
        )

        applyTextScale(textScale)
    }

    private func configureButton(
        _ button: NSButton,
        action: Selector
    ) {
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func synchronizeActionControl() {
        switch actionKind {
        case .passThrough:
            actionPopUpButton.selectItem(at: 0)

        case .replace:
            actionPopUpButton.selectItem(at: 1)
        }
    }

    private func updateControls() {
        destinationButton.isEnabled = actionKind == .replace
        restoreButtonTitles()
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

    private func title(
        for combination: KeyCombination?,
        fallback: String
    ) -> String {
        guard let combination else {
            return fallback
        }

        return KeyCombinationDisplayName.name(
            for: combination
        )
    }

    @objc
    private func actionChanged() {
        actionKind = actionPopUpButton.indexOfSelectedItem == 1
            ? .replace
            : .passThrough

        updateControls()
        onChange?()
    }

    @objc
    private func requestSource() {
        onSourceRequested?()
    }

    @objc
    private func requestDestination() {
        guard actionKind == .replace else {
            return
        }

        onDestinationRequested?()
    }

    @objc
    private func requestRemoval() {
        onRemoveRequested?()
    }
}
