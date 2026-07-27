//
//  RemapOverrideRowView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import AppKit

/// Displays and edits one stored exception belonging to a remapping rule.
@MainActor
final class RemapOverrideRowView: NSView {

    enum KeyField: Equatable {
        case source
        case destination
    }

    /// Complete editable state for one exception row.
    ///
    /// Unlike `RemapOverride`, this state can represent an incomplete row
    /// while the user is still selecting a source or destination.
    struct EditorState: Equatable {
        enum ActionKind: Equatable {
            case passThrough
            case replace
        }

        var sourceCombination: KeyCombination?
        var destinationCombination: KeyCombination?
        var actionKind: ActionKind
        var isEnabled: Bool

        init(
            sourceCombination: KeyCombination? = nil,
            destinationCombination: KeyCombination? = nil,
            actionKind: ActionKind = .passThrough,
            isEnabled: Bool = true
        ) {
            self.sourceCombination = sourceCombination
            self.destinationCombination = destinationCombination
            self.actionKind = actionKind
            self.isEnabled = isEnabled
        }

        init(
            override: RemapOverride?
        ) {
            sourceCombination = override?.source
            isEnabled = override?.isEnabled ?? true

            switch override?.action {
            case .replaceWith(
                let destination
            ):
                actionKind = .replace
                destinationCombination = destination

            case .passThrough, .none:
                actionKind = .passThrough
                destinationCombination = nil
            }
        }
    }

    var onSourceRequested: (() -> Void)?
    var onDestinationRequested: (() -> Void)?
    var onRemoveRequested: (() -> Void)?
    var onChange: (() -> Void)?

    /// Returns `true` when a requested enabled-state change may be applied.
    ///
    /// The parent editor can reject activation when the enabled exception
    /// would conflict with another active rule or exception.
    var onEnabledChangeRequested:
        ((Bool) -> Bool)?

    private let enabledSwitch = NSSwitch()

    private let sourceButton = NSButton()

    private let arrowLabel =
        NSTextField(
            labelWithString: "→"
        )

    private let actionPopUpButton =
        NSPopUpButton()

    private let destinationButton =
        NSButton()

    private let warningImageView =
        NSImageView()

    private let removeButton =
        NSButton()

    private var rowHeightConstraint:
        NSLayoutConstraint?

    private var actionKind:
        EditorState.ActionKind

    private var isShowingValidationError =
        false

    private var configurationWarning:
        KeyCombinationConfigurationWarning?

    private var textScale: CGFloat = 1.0

    private(set) var sourceCombination:
        KeyCombination?

    private(set) var destinationCombination:
        KeyCombination?

    private(set) var isEnabled: Bool

    var editorState: EditorState {
        EditorState(
            sourceCombination:
                sourceCombination,
            destinationCombination:
                destinationCombination,
            actionKind:
                actionKind,
            isEnabled:
                isEnabled
        )
    }

    var override: RemapOverride? {
        guard let sourceCombination else {
            return nil
        }

        switch actionKind {
        case .passThrough:
            return RemapOverride(
                source:
                    sourceCombination,
                action:
                    .passThrough,
                isEnabled:
                    isEnabled
            )

        case .replace:
            guard
                let destinationCombination
            else {
                return nil
            }

            return RemapOverride(
                source:
                    sourceCombination,
                action:
                    .replaceWith(
                        destinationCombination
                    ),
                isEnabled:
                    isEnabled
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

        return sourceCombination
            == destinationCombination
    }

    /// Returns the first informational warning currently produced by this
    /// editable exception, including incomplete rows.
    ///
    /// Warning assessment is read-only and does not modify the editor state,
    /// persistence, validation, or Undo/Redo history.
    var currentConfigurationWarning:
        KeyCombinationConfigurationWarning?
    {
        if let sourceCombination,
           let warning =
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        sourceCombination
                )
        {
            return warning
        }

        guard
            actionKind == .replace,
            let destinationCombination
        else {
            return nil
        }

        return KeyCombinationConfigurationWarningPolicy
            .warning(
                for:
                    destinationCombination
            )
    }

    convenience init(
        override: RemapOverride? = nil
    ) {
        self.init(
            editorState:
                EditorState(
                    override: override
                )
        )
    }

    init(
        editorState: EditorState
    ) {
        sourceCombination =
            editorState.sourceCombination

        destinationCombination =
            editorState.destinationCombination

        actionKind =
            editorState.actionKind

        isEnabled =
            editorState.isEnabled

        super.init(frame: .zero)

        configureContent()
        synchronizeActionControl()
        synchronizeEnabledControl()
        updateControls()
        updateValidationAppearance()
        updateConfigurationWarningAppearance()
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateValidationAppearance()
        updateConfigurationWarningAppearance()
    }

    func setCombination(
        _ combination: KeyCombination,
        for field: KeyField
    ) {
        switch field {
        case .source:
            sourceCombination =
                combination

        case .destination:
            destinationCombination =
                combination
        }

        updateControls()
        onChange?()
    }

    func showCapturePrompt(
        for field: KeyField
    ) {
        restoreButtonTitles()

        switch field {
        case .source:
            sourceButton.title =
                "Press combination…"

        case .destination:
            destinationButton.title =
                "Press combination…"
        }
    }

    func restoreButtonTitles() {
        sourceButton.title =
            title(
                for: sourceCombination,
                fallback:
                    "Choose Combination…"
            )

        destinationButton.title =
            title(
                for:
                    destinationCombination,
                fallback:
                    "Choose Destination…"
            )

        if actionKind == .passThrough {
            destinationButton.title =
                "Original Event"
        }
    }

    func setValidationErrorVisible(
        _ isVisible: Bool
    ) {
        guard
            isShowingValidationError
                != isVisible
        else {
            return
        }

        isShowingValidationError =
            isVisible

        updateValidationAppearance()
        updateConfigurationWarningAppearance()
    }

    /// Shows a non-blocking warning indicator for this exception.
    ///
    /// The indicator is hidden while a blocking validation error is visible so
    /// that the error remains the row's primary feedback.
    func setConfigurationWarning(
        _ warning:
            KeyCombinationConfigurationWarning?
    ) {
        configurationWarning =
            warning

        updateConfigurationWarningAppearance()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale = scale

        let controlFont =
            NSFont.systemFont(
                ofSize: 13 * scale,
                weight: .regular
            )

        sourceButton.font =
            controlFont

        destinationButton.font =
            controlFont

        actionPopUpButton.font =
            controlFont

        removeButton.font =
            controlFont

        arrowLabel.font =
            NSFont.systemFont(
                ofSize: 19 * scale,
                weight: .regular
            )

        updateWarningSymbol()

        rowHeightConstraint?.constant =
            42 * scale

        needsLayout = true
    }

    private func configureContent() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        enabledSwitch.controlSize =
            .small

        enabledSwitch.isContinuous =
            false

        enabledSwitch.target = self
        enabledSwitch.action =
            #selector(enabledChanged)

        enabledSwitch.toolTip =
            "Enable or disable this exception without deleting it."

        enabledSwitch.setAccessibilityLabel(
            "Enabled exception"
        )

        enabledSwitch.setAccessibilityHelp(
            "When disabled, this exception remains stored but does not participate in remapping."
        )

        configureButton(
            sourceButton,
            action:
                #selector(requestSource)
        )

        configureButton(
            destinationButton,
            action:
                #selector(
                    requestDestination
                )
        )

        arrowLabel.alignment = .center

        actionPopUpButton.addItems(
            withTitles: [
                "Keep Original",
                "Replace With"
            ]
        )

        actionPopUpButton.target = self
        actionPopUpButton.action =
            #selector(actionChanged)

        warningImageView.imageScaling =
            .scaleProportionallyDown

        warningImageView.setAccessibilityLabel(
            "Configuration warning"
        )

        removeButton.title = "Remove"
        removeButton.bezelStyle =
            .rounded
        removeButton.hasDestructiveAction =
            true
        removeButton.target = self
        removeButton.action =
            #selector(requestRemoval)

        let views: [NSView] = [
            enabledSwitch,
            sourceButton,
            arrowLabel,
            actionPopUpButton,
            destinationButton,
            warningImageView,
            removeButton
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            addSubview(view)
        }

        let rowHeightConstraint =
            heightAnchor.constraint(
                equalToConstant: 42
            )

        self.rowHeightConstraint =
            rowHeightConstraint

        NSLayoutConstraint.activate(
            [
                enabledSwitch.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: 6
                ),

                enabledSwitch.centerYAnchor.constraint(
                    equalTo: centerYAnchor
                ),

                sourceButton.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: 74
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
                    equalTo:
                        sourceButton
                            .trailingAnchor,
                    constant: 10
                ),

                arrowLabel.centerYAnchor.constraint(
                    equalTo:
                        sourceButton
                            .centerYAnchor
                ),

                arrowLabel.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                actionPopUpButton.leadingAnchor.constraint(
                    equalTo:
                        arrowLabel
                            .trailingAnchor,
                    constant: 10
                ),

                actionPopUpButton.centerYAnchor.constraint(
                    equalTo:
                        sourceButton
                            .centerYAnchor
                ),

                actionPopUpButton.widthAnchor.constraint(
                    equalToConstant: 132
                ),

                destinationButton.leadingAnchor.constraint(
                    equalTo:
                        actionPopUpButton
                            .trailingAnchor,
                    constant: 10
                ),

                destinationButton.centerYAnchor.constraint(
                    equalTo:
                        sourceButton
                            .centerYAnchor
                ),

                warningImageView.leadingAnchor.constraint(
                    equalTo:
                        destinationButton
                            .trailingAnchor,
                    constant: 8
                ),

                warningImageView.centerYAnchor.constraint(
                    equalTo:
                        sourceButton
                            .centerYAnchor
                ),

                warningImageView.widthAnchor.constraint(
                    equalToConstant: 24
                ),

                warningImageView.heightAnchor.constraint(
                    equalTo:
                        warningImageView
                            .widthAnchor
                ),

                removeButton.leadingAnchor.constraint(
                    equalTo:
                        warningImageView
                            .trailingAnchor,
                    constant: 8
                ),

                removeButton.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -6
                ),

                removeButton.centerYAnchor.constraint(
                    equalTo:
                        sourceButton
                            .centerYAnchor
                ),

                removeButton.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceButton.widthAnchor.constraint(
                    equalTo:
                        destinationButton
                            .widthAnchor
                ),

                sourceButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        160
                ),

                destinationButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        160
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
            actionPopUpButton.selectItem(
                at: 0
            )

        case .replace:
            actionPopUpButton.selectItem(
                at: 1
            )
        }
    }

    private func synchronizeEnabledControl() {
        enabledSwitch.state =
            isEnabled ? .on : .off
    }

    private func updateControls() {
        destinationButton.isEnabled =
            actionKind == .replace

        let contentAlpha:
            CGFloat =
                isEnabled
                ? 1.0
                : 0.55

        sourceButton.alphaValue =
            contentAlpha

        arrowLabel.alphaValue =
            contentAlpha

        actionPopUpButton.alphaValue =
            contentAlpha

        destinationButton.alphaValue =
            contentAlpha

        restoreButtonTitles()
    }

    private func updateValidationAppearance() {
        guard let layer else {
            return
        }

        if isShowingValidationError {
            layer.borderWidth = 1.5
            layer.borderColor =
                NSColor.systemRed.cgColor

            layer.backgroundColor =
                NSColor.systemRed
                    .withAlphaComponent(0.08)
                    .cgColor
        } else {
            layer.borderWidth = 0
            layer.borderColor =
                NSColor.clear.cgColor

            layer.backgroundColor =
                NSColor.clear.cgColor
        }
    }

    private func updateWarningSymbol() {
        warningImageView.image =
            NSImage(
                systemSymbolName:
                    "exclamationmark.triangle.fill",
                accessibilityDescription:
                    "Configuration warning"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize:
                        13 * textScale,
                    weight:
                        .medium
                )
            )
    }

    private func updateConfigurationWarningAppearance() {
        updateWarningSymbol()

        let shouldShowWarning =
            configurationWarning != nil
            && !isShowingValidationError

        warningImageView.contentTintColor =
            .systemOrange

        warningImageView.alphaValue =
            shouldShowWarning
                ? 1
                : 0

        warningImageView.toolTip =
            configurationWarning?
                .message

        warningImageView.setAccessibilityHidden(
            !shouldShowWarning
        )

        warningImageView.setAccessibilityValue(
            configurationWarning?
                .message
                ?? "No configuration warning"
        )
    }

    private func title(
        for combination:
            KeyCombination?,
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
    private func enabledChanged() {
        let requestedValue =
            enabledSwitch.state == .on

        if let onEnabledChangeRequested,
           !onEnabledChangeRequested(
                requestedValue
           )
        {
            synchronizeEnabledControl()
            return
        }

        isEnabled = requestedValue
        updateControls()
        onChange?()
    }

    @objc
    private func actionChanged() {
        actionKind =
            actionPopUpButton
                .indexOfSelectedItem
                == 1
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
        guard
            actionKind == .replace
        else {
            return
        }

        onDestinationRequested?()
    }

    @objc
    private func requestRemoval() {
        onRemoveRequested?()
    }
}
