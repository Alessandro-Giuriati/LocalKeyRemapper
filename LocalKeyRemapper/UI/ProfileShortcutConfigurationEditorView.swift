//
//  ProfileShortcutConfigurationEditorView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import AppKit

/// Displays the temporary shortcut configuration edited for one profile.
///
/// The view owns presentation state only. It never persists an override,
/// changes the active profile, registers a Carbon shortcut, or modifies the
/// remapping engine.
///
/// The future sheet controller will read `proposal` and apply the resulting
/// override through `HomeConfigurationEditorSession` only after the user
/// explicitly confirms the change.
@MainActor
final class ProfileShortcutConfigurationEditorView:
    NSView
{
    enum CaptureField:
        Equatable
    {
        case toggle
        case enable
        case disable
    }

    private final class ShortcutRowView:
        NSStackView
    {
        let recordButton =
            NSButton()

        let clearButton =
            NSButton()

        let cancelButton =
            NSButton()

        private let titleLabel:
            NSTextField

        init(
            title:
                String,
            identifierPrefix:
                String
        ) {
            titleLabel =
                NSTextField(
                    labelWithString:
                        title
                )

            super.init(
                frame:
                    .zero
            )

            orientation =
                .horizontal

            alignment =
                .centerY

            spacing =
                10

            titleLabel.widthAnchor
                .constraint(
                    equalToConstant:
                        150
                )
                .isActive =
                    true

            recordButton.bezelStyle =
                .rounded

            recordButton.identifier =
                NSUserInterfaceItemIdentifier(
                    "\(identifierPrefix).record"
                )

            recordButton.setContentHuggingPriority(
                .defaultLow,
                for:
                    .horizontal
            )

            clearButton.title =
                "Clear"

            clearButton.bezelStyle =
                .rounded

            clearButton.identifier =
                NSUserInterfaceItemIdentifier(
                    "\(identifierPrefix).clear"
                )

            clearButton.widthAnchor
                .constraint(
                    equalToConstant:
                        70
                )
                .isActive =
                    true

            cancelButton.title =
                "Cancel"

            cancelButton.bezelStyle =
                .rounded

            cancelButton.identifier =
                NSUserInterfaceItemIdentifier(
                    "\(identifierPrefix).cancel"
                )

            cancelButton.isHidden =
                true

            cancelButton.widthAnchor
                .constraint(
                    equalToConstant:
                        70
                )
                .isActive =
                    true

            setViews(
                [
                    titleLabel,
                    recordButton,
                    cancelButton,
                    clearButton
                ],
                in:
                    .leading
            )
        }

        required init?(
            coder:
                NSCoder
        ) {
            fatalError(
                "init(coder:) has not been implemented"
            )
        }

        func applyTextScale(
            _ scale:
                CGFloat
        ) {
            let font =
                NSFont.systemFont(
                    ofSize:
                        14 * scale,
                    weight:
                        .regular
                )

            titleLabel.font =
                font

            recordButton.font =
                font

            clearButton.font =
                font

            cancelButton.font =
                font

            spacing =
                InterfaceLayoutMetrics.scaled(
                    10,
                    for:
                        scale,
                    minimum:
                        7,
                    maximum:
                        15
                )
        }
    }

    var onCaptureRequested:
        ((CaptureField) -> Void)?

    var onCaptureCancellationRequested:
        (() -> Void)?

    /// Called whenever the temporary editor state or its validation changes.
    ///
    /// The receiver may use this to enable or disable the sheet's Apply button.
    var onStateChange:
        (() -> Void)?

    /// Performs blocking validation that depends on the profile collection.
    ///
    /// The closure receives the effective configuration represented by the
    /// editor. For Use Default this is the current default configuration.
    var onAdditionalValidationRequested:
        ((RemappingShortcutConfiguration) -> String?)?

    /// Provides non-blocking guidance that depends on the profile collection.
    var onAdditionalSuggestionRequested:
        ((RemappingShortcutConfiguration) -> String?)?

    private let titleLabel =
        NSTextField(
            labelWithString:
                "Profile Shortcut"
        )

    private let descriptionLabel =
        NSTextField(
            wrappingLabelWithString:
                "Use Default Global Shortcuts, turn shortcuts off for this profile, or configure a custom Toggle or Separate shortcut."
        )

    private let defaultConfigurationLabel =
        NSTextField(
            wrappingLabelWithString:
                ""
        )

    private let modeControl =
        NSSegmentedControl(
            labels: [
                "Use Default",
                "Off",
                "Toggle",
                "Separate"
            ],
            trackingMode:
                .selectOne,
            target:
                nil,
            action:
                nil
        )

    private let toggleRow =
        ShortcutRowView(
            title:
                "Toggle Remapping",
            identifierPrefix:
                "profileShortcut.toggle"
        )

    private let enableRow =
        ShortcutRowView(
            title:
                "Enable Remapping",
            identifierPrefix:
                "profileShortcut.enable"
        )

    private let disableRow =
        ShortcutRowView(
            title:
                "Disable Remapping",
            identifierPrefix:
                "profileShortcut.disable"
        )

    private let statusLabel =
        NSTextField(
            wrappingLabelWithString:
                ""
        )

    private let mainStack =
        NSStackView()

    private(set) var draft:
        ProfileShortcutConfigurationDraft

    private(set) var originalOverride:
        RemappingShortcutConfiguration?

    private(set) var defaultConfiguration:
        RemappingShortcutConfiguration

    private(set) var activeCaptureField:
        CaptureField?

    init(
        shortcutConfigurationOverride:
            RemappingShortcutConfiguration?,
        shortcutMemory:
            RemappingProfileShortcutMemory = .empty,
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) {
        originalOverride =
            shortcutConfigurationOverride

        self.defaultConfiguration =
            defaultConfiguration

        draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    shortcutConfigurationOverride,
                shortcutMemory:
                    shortcutMemory
            )

        super.init(
            frame:
                .zero
        )

        configureContent()
        synchronizeControlsFromDraft()
    }

    required init?(
        coder:
            NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    /// Complete override currently represented by the editor.
    ///
    /// `.complete(nil)` means Use Default.
    /// `.complete(.disabled)` means explicit Off.
    var proposal:
        ProfileShortcutConfigurationOverrideProposal
    {
        draft.proposal
    }

    /// Effective configuration represented by the current editor controls.
    ///
    /// Nil means that the selected custom mode is incomplete.
    var effectiveConfiguration:
        RemappingShortcutConfiguration?
    {
        proposal.effectiveConfiguration(
            defaultConfiguration:
                defaultConfiguration
        )
    }

    /// Indicates whether the editor represents a change from the profile value
    /// present when the view was loaded.
    var hasChanges:
        Bool
    {
        draft.differs(
            from:
                originalOverride
        )
    }

    /// Current blocking validation message.
    ///
    /// Nil means that Apply may proceed, provided capture is not active.
    var currentValidationMessage:
        String?
    {
        guard
            let effectiveConfiguration
        else {
            return "Choose every shortcut required by the selected mode."
        }

        do {
            try GlobalShortcutConfigurationPolicy
                .validate(
                    effectiveConfiguration
                )
        } catch let error as
            GlobalShortcutConfigurationError
        {
            switch error {
            case .duplicateShortcut:
                return "Enable and Disable must use different shortcuts."

            case .insufficientModifiers:
                return "Every custom shortcut must contain at least one modifier."
            }
        } catch {
            return "The profile shortcut configuration is not valid."
        }

        return onAdditionalValidationRequested?(
            effectiveConfiguration
        )
    }

    /// True only when the editor is complete, valid, changed, and not capturing.
    var canApply:
        Bool
    {
        activeCaptureField == nil
            && hasChanges
            && currentValidationMessage == nil
    }

    /// Replaces the complete temporary editor state.
    ///
    /// This operation does not report a user edit or modify Home history.
    func load(
        shortcutConfigurationOverride:
            RemappingShortcutConfiguration?,
        shortcutMemory:
            RemappingProfileShortcutMemory = .empty,
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) {
        endCapturePrompt()

        originalOverride =
            shortcutConfigurationOverride

        self.defaultConfiguration =
            defaultConfiguration

        draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    shortcutConfigurationOverride,
                shortcutMemory:
                    shortcutMemory
            )

        synchronizeControlsFromDraft()
    }

    func beginCapturePrompt(
        for field:
            CaptureField
    ) {
        activeCaptureField =
            field

        restoreButtonTitles()

        row(
            for:
                field
        )
        .recordButton
        .title =
            "Press shortcut…"

        updateCaptureControls()

        setStatus(
            "Press a key with one or more modifiers. Use Cancel or press Escape to stop recording.",
            presentation:
                .normal
        )

        onStateChange?()
    }

    func setCapturedShortcut(
        _ shortcut:
            KeyCombination,
        for field:
            CaptureField
    ) {
        switch field {
        case .toggle:
            draft.toggleShortcut =
                shortcut

        case .enable:
            draft.enableShortcut =
                shortcut

        case .disable:
            draft.disableShortcut =
                shortcut
        }

        endCapturePrompt()
        refreshState()
    }

    func endCapturePrompt() {
        activeCaptureField =
            nil

        restoreButtonTitles()
        updateCaptureControls()
        refreshState()
    }

    func refreshValidationState() {
        refreshState()
    }

    func applyTextScale(
        _ scale:
            CGFloat
    ) {
        titleLabel.font =
            NSFont.systemFont(
                ofSize:
                    16 * scale,
                weight:
                    .semibold
            )

        descriptionLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * scale,
                weight:
                    .regular
            )

        defaultConfigurationLabel.font =
            NSFont.systemFont(
                ofSize:
                    12 * scale,
                weight:
                    .regular
            )

        modeControl.font =
            NSFont.systemFont(
                ofSize:
                    14 * scale,
                weight:
                    .regular
            )

        toggleRow.applyTextScale(
            scale
        )

        enableRow.applyTextScale(
            scale
        )

        disableRow.applyTextScale(
            scale
        )

        statusLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * scale,
                weight:
                    .regular
            )

        mainStack.spacing =
            InterfaceLayoutMetrics.scaled(
                8,
                for:
                    scale,
                minimum:
                    6,
                maximum:
                    13
            )

        needsLayout =
            true
    }

    // MARK: - Test support

    var modeForTesting:
        ProfileShortcutConfigurationMode
    {
        draft.mode
    }

    var defaultDescriptionForTesting:
        String
    {
        defaultConfigurationLabel
            .stringValue
    }

    var statusTextForTesting:
        String
    {
        statusLabel.stringValue
    }

    func setModeForTesting(
        _ mode:
            ProfileShortcutConfigurationMode
    ) {
        modeControl.selectedSegment =
            mode.rawValue

        modeChanged()
    }

    func clearShortcutForTesting(
        _ field:
            CaptureField
    ) {
        clear(
            field
        )
    }

    func isRowVisibleForTesting(
        _ field:
            CaptureField
    ) -> Bool {
        !row(
            for:
                field
        )
        .isHidden
    }

    private enum StatusPresentation {
        case normal
        case suggestion
        case error
    }

    private func configureContent() {
        descriptionLabel.textColor =
            .secondaryLabelColor

        defaultConfigurationLabel.textColor =
            .secondaryLabelColor

        modeControl.segmentStyle =
            .automatic

        modeControl.identifier =
            NSUserInterfaceItemIdentifier(
                "profileShortcut.mode"
            )

        modeControl.target =
            self

        modeControl.action =
            #selector(
                modeChanged
            )

        configure(
            toggleRow,
            captureAction:
                #selector(
                    captureToggle
                ),
            clearAction:
                #selector(
                    clearToggle
                ),
            cancelAction:
                #selector(
                    cancelCapture
                )
        )

        configure(
            enableRow,
            captureAction:
                #selector(
                    captureEnable
                ),
            clearAction:
                #selector(
                    clearEnable
                ),
            cancelAction:
                #selector(
                    cancelCapture
                )
        )

        configure(
            disableRow,
            captureAction:
                #selector(
                    captureDisable
                ),
            clearAction:
                #selector(
                    clearDisable
                ),
            cancelAction:
                #selector(
                    cancelCapture
                )
        )

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                defaultConfigurationLabel,
                modeControl,
                toggleRow,
                enableRow,
                disableRow,
                statusLabel
            ],
            in:
                .leading
        )

        mainStack.orientation =
            .vertical

        mainStack.alignment =
            .leading

        mainStack.translatesAutoresizingMaskIntoConstraints =
            false

        addSubview(
            mainStack
        )

        NSLayoutConstraint.activate(
            [
                mainStack.topAnchor.constraint(
                    equalTo:
                        topAnchor
                ),

                mainStack.leadingAnchor.constraint(
                    equalTo:
                        leadingAnchor
                ),

                mainStack.trailingAnchor.constraint(
                    equalTo:
                        trailingAnchor
                ),

                mainStack.bottomAnchor.constraint(
                    equalTo:
                        bottomAnchor
                ),

                descriptionLabel.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                defaultConfigurationLabel.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                modeControl.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                toggleRow.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                enableRow.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                disableRow.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                statusLabel.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                )
            ]
        )

        applyTextScale(
            1.0
        )
    }

    private func configure(
        _ row:
            ShortcutRowView,
        captureAction:
            Selector,
        clearAction:
            Selector,
        cancelAction:
            Selector
    ) {
        row.recordButton.target =
            self

        row.recordButton.action =
            captureAction

        row.clearButton.target =
            self

        row.clearButton.action =
            clearAction

        row.cancelButton.target =
            self

        row.cancelButton.action =
            cancelAction
    }

    private func synchronizeControlsFromDraft() {
        modeControl.selectedSegment =
            draft.mode.rawValue

        defaultConfigurationLabel.stringValue =
            ProfileShortcutConfigurationPresentation
                .detailTitle(
                    for:
                        nil,
                    defaultConfiguration:
                        defaultConfiguration
                )

        updateControls()
    }

    private func updateControls() {
        toggleRow.isHidden =
            draft.mode
                != .toggle

        enableRow.isHidden =
            draft.mode
                != .separate

        disableRow.isHidden =
            draft.mode
                != .separate

        restoreButtonTitles()
        updateCaptureControls()
        refreshState()
    }

    private func updateCaptureControls() {
        for field in [
            CaptureField.toggle,
            CaptureField.enable,
            CaptureField.disable
        ] {
            let shortcutRow =
                row(
                    for:
                        field
                )

            let isCapturing =
                activeCaptureField
                    == field

            shortcutRow
                .recordButton
                .isEnabled =
                    !isCapturing

            shortcutRow
                .cancelButton
                .isHidden =
                    !isCapturing

            shortcutRow
                .clearButton
                .isHidden =
                    isCapturing
        }
    }

    private func restoreButtonTitles() {
        toggleRow.recordButton.title =
            title(
                for:
                    draft.toggleShortcut
            )

        enableRow.recordButton.title =
            title(
                for:
                    draft.enableShortcut
            )

        disableRow.recordButton.title =
            title(
                for:
                    draft.disableShortcut
            )
    }

    private func title(
        for shortcut:
            KeyCombination?
    ) -> String {
        guard
            let shortcut
        else {
            return "Choose Shortcut…"
        }

        return KeyCombinationDisplayName
            .name(
                for:
                    shortcut
            )
    }

    private func refreshState() {
        guard
            activeCaptureField == nil
        else {
            onStateChange?()
            return
        }

        if let currentValidationMessage {
            setStatus(
                currentValidationMessage,
                presentation:
                    .error
            )

            onStateChange?()
            return
        }

        if let effectiveConfiguration,
           let additionalSuggestion =
               onAdditionalSuggestionRequested?(
                   effectiveConfiguration
               )
        {
            setStatus(
                additionalSuggestion,
                presentation:
                    .suggestion
            )

            onStateChange?()
            return
        }

        if let effectiveConfiguration,
           let suggestion =
               GlobalShortcutConfigurationPolicy
                   .suggestion(
                       for:
                           effectiveConfiguration
                   )
        {
            setStatus(
                suggestion.message,
                presentation:
                    .suggestion
            )

            onStateChange?()
            return
        }

        setStatus(
            hasChanges
                ? "The profile shortcut change is ready to apply."
                : "No profile shortcut changes.",
            presentation:
                .normal
        )

        onStateChange?()
    }

    private func row(
        for field:
            CaptureField
    ) -> ShortcutRowView {
        switch field {
        case .toggle:
            return toggleRow

        case .enable:
            return enableRow

        case .disable:
            return disableRow
        }
    }

    private func requestCapture(
        _ field:
            CaptureField
    ) {
        onCaptureRequested?(
            field
        )
    }

    private func clear(
        _ field:
            CaptureField
    ) {
        onCaptureCancellationRequested?()

        switch field {
        case .toggle:
            draft.toggleShortcut =
                nil

        case .enable:
            draft.enableShortcut =
                nil

        case .disable:
            draft.disableShortcut =
                nil
        }

        endCapturePrompt()
        updateControls()
    }

    private func setStatus(
        _ message:
            String,
        presentation:
            StatusPresentation
    ) {
        statusLabel.stringValue =
            message

        switch presentation {
        case .normal:
            statusLabel.textColor =
                .secondaryLabelColor

        case .suggestion:
            statusLabel.textColor =
                .systemOrange

        case .error:
            statusLabel.textColor =
                .systemRed
        }
    }

    @objc
    private func modeChanged() {
        onCaptureCancellationRequested?()
        endCapturePrompt()

        draft.mode =
            ProfileShortcutConfigurationMode(
                rawValue:
                    modeControl.selectedSegment
            )
            ?? .useDefault

        updateControls()
    }

    @objc
    private func captureToggle() {
        requestCapture(
            .toggle
        )
    }

    @objc
    private func captureEnable() {
        requestCapture(
            .enable
        )
    }

    @objc
    private func captureDisable() {
        requestCapture(
            .disable
        )
    }

    @objc
    private func cancelCapture() {
        guard
            activeCaptureField != nil
        else {
            return
        }

        if let onCaptureCancellationRequested {
            onCaptureCancellationRequested()
        } else {
            endCapturePrompt()
        }
    }

    @objc
    private func clearToggle() {
        clear(
            .toggle
        )
    }

    @objc
    private func clearEnable() {
        clear(
            .enable
        )
    }

    @objc
    private func clearDisable() {
        clear(
            .disable
        )
    }
}
