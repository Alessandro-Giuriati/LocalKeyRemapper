//
//  RemappingRuleRowView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import CoreGraphics

/// Displays and edits one remapping rule.
@MainActor
final class RemappingRuleRowView: NSView {

    enum KeyField: Equatable {
        case source
        case destination
    }

    var onSourceKeyRequested: (() -> Void)?
    var onDestinationKeyRequested: (() -> Void)?
    var onExceptionsRequested: (() -> Void)?
    var onRemoveRequested: (() -> Void)?
    var onRuleChanged: (() -> Void)?

    private let sourceKeyButton = NSButton()
    private let arrowLabel = NSTextField(labelWithString: "→")
    private let destinationKeyButton = NSButton()
    private let behaviorPopUpButton = NSPopUpButton()
    private let exceptionsButton = NSButton()
    private let removeButton = NSButton()

    private var rowHeightConstraint: NSLayoutConstraint?
    private var isShowingValidationError = false
    private var textScale: CGFloat = 1.0

    private(set) var sourceCombination: KeyCombination?
    private(set) var destinationCombination: KeyCombination?
    private(set) var matchingMode: RemapMatchingMode
    private(set) var overrides: [RemapOverride]

    var sourceKeyCode: CGKeyCode? {
        sourceCombination?.keyCode
    }

    var destinationKeyCode: CGKeyCode? {
        destinationCombination?.keyCode
    }

    var rule: RemapRule? {
        guard
            let sourceCombination,
            let destinationCombination
        else {
            return nil
        }

        return RemapRule(
            source: sourceCombination,
            destination: destinationCombination,
            matchingMode: matchingMode,
            overrides: matchingMode == .preserveModifiers
                ? overrides
                : []
        )
    }

    init(rule: RemapRule? = nil) {
        sourceCombination = rule?.source
        destinationCombination = rule?.destination
        matchingMode = rule?.matchingMode ?? .exact
        overrides = rule?.overrides ?? []

        super.init(frame: .zero)

        configureContent()
        synchronizeBehaviorControl()
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
        let normalizedCombination: KeyCombination

        if matchingMode == .preserveModifiers {
            normalizedCombination = KeyCombination(
                keyCode: combination.keyCode
            )
        } else {
            normalizedCombination = combination
        }

        switch field {
        case .source:
            let previousKeyCode = sourceCombination?.keyCode
            sourceCombination = normalizedCombination

            if
                let previousKeyCode,
                previousKeyCode != normalizedCombination.keyCode
            {
                overrides = []
            }

        case .destination:
            destinationCombination = normalizedCombination
        }

        updateControls()
        onRuleChanged?()
    }

    func setOverrides(_ newOverrides: [RemapOverride]) {
        overrides = newOverrides
        updateControls()
        onRuleChanged?()
    }

    func showCapturePrompt(for field: KeyField) {
        restoreButtonTitles()

        switch field {
        case .source:
            sourceKeyButton.title = "Press combination…"

        case .destination:
            destinationKeyButton.title = "Press combination…"
        }
    }

    func restoreButtonTitles() {
        sourceKeyButton.title = buttonTitle(
            for: sourceCombination
        )

        destinationKeyButton.title = buttonTitle(
            for: destinationCombination
        )
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
            ofSize: 14 * scale,
            weight: .regular
        )

        sourceKeyButton.font = controlFont
        destinationKeyButton.font = controlFont
        behaviorPopUpButton.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )
        exceptionsButton.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )
        removeButton.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )
        arrowLabel.font = NSFont.systemFont(
            ofSize: 20 * scale,
            weight: .regular
        )

        rowHeightConstraint?.constant = 42 * scale
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

        behaviorPopUpButton.addItems(
            withTitles: [
                "Exact only",
                "Preserve modifiers"
            ]
        )
        behaviorPopUpButton.target = self
        behaviorPopUpButton.action = #selector(behaviorChanged)
        behaviorPopUpButton.toolTip =
            "Match only the recorded combination or preserve incoming modifiers."

        exceptionsButton.title = "Exceptions…"
        exceptionsButton.bezelStyle = .rounded
        exceptionsButton.target = self
        exceptionsButton.action = #selector(requestExceptions)

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(requestRemoval)

        let views: [NSView] = [
            sourceKeyButton,
            arrowLabel,
            destinationKeyButton,
            behaviorPopUpButton,
            exceptionsButton,
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
                    constant: 10
                ),
                arrowLabel.centerYAnchor.constraint(
                    equalTo: sourceKeyButton.centerYAnchor
                ),
                arrowLabel.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                destinationKeyButton.leadingAnchor.constraint(
                    equalTo: arrowLabel.trailingAnchor,
                    constant: 10
                ),
                destinationKeyButton.topAnchor.constraint(
                    equalTo: topAnchor,
                    constant: 4
                ),
                destinationKeyButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -4
                ),

                behaviorPopUpButton.leadingAnchor.constraint(
                    equalTo: destinationKeyButton.trailingAnchor,
                    constant: 10
                ),
                behaviorPopUpButton.centerYAnchor.constraint(
                    equalTo: destinationKeyButton.centerYAnchor
                ),
                behaviorPopUpButton.widthAnchor.constraint(
                    equalToConstant: 168
                ),

                exceptionsButton.leadingAnchor.constraint(
                    equalTo: behaviorPopUpButton.trailingAnchor,
                    constant: 10
                ),
                exceptionsButton.centerYAnchor.constraint(
                    equalTo: destinationKeyButton.centerYAnchor
                ),
                exceptionsButton.widthAnchor.constraint(
                    equalToConstant: 116
                ),

                removeButton.leadingAnchor.constraint(
                    equalTo: exceptionsButton.trailingAnchor,
                    constant: 10
                ),
                removeButton.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -6
                ),
                removeButton.centerYAnchor.constraint(
                    equalTo: destinationKeyButton.centerYAnchor
                ),
                removeButton.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceKeyButton.widthAnchor.constraint(
                    equalTo: destinationKeyButton.widthAnchor
                ),
                sourceKeyButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 120
                ),
                destinationKeyButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 120
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

    private func synchronizeBehaviorControl() {
        switch matchingMode {
        case .exact:
            behaviorPopUpButton.selectItem(at: 0)

        case .preserveModifiers:
            behaviorPopUpButton.selectItem(at: 1)
        }
    }

    private func updateControls() {
        restoreButtonTitles()

        exceptionsButton.isEnabled =
            matchingMode == .preserveModifiers &&
            sourceCombination != nil &&
            destinationCombination != nil

        exceptionsButton.title = overrides.isEmpty
            ? "Exceptions…"
            : "Exceptions (\(overrides.count))"
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
        for combination: KeyCombination?
    ) -> String {
        guard let combination else {
            return "Choose Combination…"
        }

        return KeyCombinationDisplayName.name(
            for: combination
        )
    }

    @objc
    private func behaviorChanged() {
        let requestedMode: RemapMatchingMode =
            behaviorPopUpButton.indexOfSelectedItem == 1
                ? .preserveModifiers
                : .exact

        guard requestedMode != matchingMode else {
            return
        }

        if requestedMode == .exact && !overrides.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Remove custom exceptions?"
            alert.informativeText =
                "Exact-only rules cannot contain modifier exceptions."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Remove Exceptions")
            alert.addButton(withTitle: "Cancel")

            guard alert.runModal() == .alertFirstButtonReturn else {
                synchronizeBehaviorControl()
                return
            }

            overrides = []
        }

        matchingMode = requestedMode

        if matchingMode == .preserveModifiers {
            if let sourceCombination {
                self.sourceCombination = KeyCombination(
                    keyCode: sourceCombination.keyCode
                )
            }

            if let destinationCombination {
                self.destinationCombination = KeyCombination(
                    keyCode: destinationCombination.keyCode
                )
            }
        }

        synchronizeBehaviorControl()
        updateControls()
        onRuleChanged?()
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
    private func requestExceptions() {
        onExceptionsRequested?()
    }

    @objc
    private func requestRemoval() {
        onRemoveRequested?()
    }
}
