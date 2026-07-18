//
//  GlobalShortcutSettingsView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import AppKit

/// Displays and edits the application's global shortcut configuration.
///
/// This view stores only explicitly configured combinations.
/// It never receives global keyboard input.
@MainActor
final class GlobalShortcutSettingsView:
    NSView
{
    enum CaptureField:
        Equatable
    {
        case toggle
        case enable
        case disable
    }

    private enum Mode:
        Int
    {
        case disabled = 0
        case toggle = 1
        case separate = 2
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

            titleLabel.widthAnchor.constraint(
                equalToConstant:
                    150
            ).isActive =
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

            clearButton.widthAnchor.constraint(
                equalToConstant:
                    70
            ).isActive =
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

            cancelButton.widthAnchor.constraint(
                equalToConstant:
                    70
            ).isActive =
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
                10 * scale
        }
    }

    private static let defaultEnableShortcut =
        KeyCombination(
            keyCode:
                KeyCode.e,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )

    private static let defaultDisableShortcut =
        KeyCombination(
            keyCode:
                KeyCode.d,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )

    var onCaptureRequested:
        ((
            CaptureField
        ) -> Void)?

    var onCaptureCancellationRequested:
        (() -> Void)?

    var onSaveRequested:
        ((
            RemappingShortcutConfiguration
        ) throws -> Void)?

    private let titleLabel =
        NSTextField(
            labelWithString:
                "Global shortcuts"
        )

    private let descriptionLabel =
        NSTextField(
            wrappingLabelWithString:
                "Use one shortcut to toggle remapping, use separate shortcuts to enable and disable it, or turn keyboard control off."
        )

    private let modeControl =
        NSSegmentedControl(
            labels: [
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
                "globalShortcut.toggle"
        )

    private let enableRow =
        ShortcutRowView(
            title:
                "Enable Remapping",
            identifierPrefix:
                "globalShortcut.enable"
        )

    private let disableRow =
        ShortcutRowView(
            title:
                "Disable Remapping",
            identifierPrefix:
                "globalShortcut.disable"
        )

    private let saveButton =
        NSButton()

    private let cancelButton =
        NSButton()

    private let shortcutActionsStack =
        NSStackView()

    private let statusLabel =
        NSTextField(
            wrappingLabelWithString:
                ""
        )

    private let mainStack =
        NSStackView()

    private var savedConfiguration:
        RemappingShortcutConfiguration

    private var toggleShortcut:
        KeyCombination?

    private var enableShortcut:
        KeyCombination?

    private var disableShortcut:
        KeyCombination?

    private(set) var activeCaptureField:
        CaptureField?

    init(
        configuration:
            RemappingShortcutConfiguration
    ) {
        savedConfiguration =
            configuration

        toggleShortcut =
            AppPreferences
                .defaultToggleShortcut

        enableShortcut =
            Self
                .defaultEnableShortcut

        disableShortcut =
            Self
                .defaultDisableShortcut

        super.init(
            frame:
                .zero
        )

        configureContent()

        load(
            configuration:
                configuration
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

    func load(
        configuration:
            RemappingShortcutConfiguration
    ) {
        savedConfiguration =
            configuration

        toggleShortcut =
            AppPreferences
                .defaultToggleShortcut

        enableShortcut =
            Self
                .defaultEnableShortcut

        disableShortcut =
            Self
                .defaultDisableShortcut

        switch configuration {
        case .disabled:
            modeControl.selectedSegment =
                Mode.disabled.rawValue

        case .toggle(
            let shortcut
        ):
            modeControl.selectedSegment =
                Mode.toggle.rawValue

            toggleShortcut =
                shortcut

        case .separate(
            let enable,
            let disable
        ):
            modeControl.selectedSegment =
                Mode.separate.rawValue

            enableShortcut =
                enable

            disableShortcut =
                disable
        }

        endCapturePrompt()
        updateControls()
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
            isError:
                false
        )

        saveButton.isEnabled =
            false

        cancelButton.isEnabled =
            true

        updateSaveButtonAppearance()
    }

    func setCapturedShortcut(
        _ shortcut:
            KeyCombination,
        for field:
            CaptureField
    ) {
        switch field {
        case .toggle:
            toggleShortcut =
                shortcut

        case .enable:
            enableShortcut =
                shortcut

        case .disable:
            disableShortcut =
                shortcut
        }

        endCapturePrompt()
        updateControls()
    }

    func endCapturePrompt() {
        activeCaptureField =
            nil

        restoreButtonTitles()
        updateCaptureControls()
        refreshChangeState()
    }

    /// Indicates whether the editor differs from the last
    /// successfully stored shortcut configuration.
    var hasUnsavedChanges:
        Bool
    {
        guard
            let proposedConfiguration
        else {
            return true
        }

        return proposedConfiguration
            != savedConfiguration
    }

    /// Restores the last successfully stored configuration.
    func discardChanges() {
        load(
            configuration:
                savedConfiguration
        )
    }

    /// Shows that the previous shortcut could not be restored
    /// after a local capture session.
    func showCaptureRestorationFailure() {
        setStatus(
            "The previous global shortcut could not be restored. It may now be used by macOS or another application.",
            isError:
                true
        )
    }

    func applyTextScale(
        _ scale:
            CGFloat
    ) {
        titleLabel.font =
            NSFont.systemFont(
                ofSize:
                    14 * scale,
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

        let actionFont =
            NSFont.systemFont(
                ofSize:
                    14 * scale,
                weight:
                    .regular
            )

        saveButton.font =
            actionFont

        cancelButton.font =
            actionFont

        shortcutActionsStack.spacing =
            10 * scale

        statusLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * scale,
                weight:
                    .regular
            )

        mainStack.spacing =
            8 * scale

        needsLayout =
            true
    }

    private func configureContent() {
        descriptionLabel.textColor =
            .secondaryLabelColor

        modeControl.segmentStyle =
            .rounded

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

        saveButton.title =
            "Save Shortcuts"

        saveButton.bezelStyle =
            .rounded

        saveButton.identifier =
            NSUserInterfaceItemIdentifier(
                "globalShortcut.save"
            )

        saveButton.target =
            self

        saveButton.action =
            #selector(
                saveConfiguration
            )

        cancelButton.title =
            "Cancel"

        cancelButton.bezelStyle =
            .rounded

        cancelButton.identifier =
            NSUserInterfaceItemIdentifier(
                "globalShortcut.cancel"
            )

        cancelButton.target =
            self

        cancelButton.action =
            #selector(
                cancelChanges
            )

        shortcutActionsStack.setViews(
            [
                saveButton,
                cancelButton
            ],
            in:
                .leading
        )

        shortcutActionsStack.orientation =
            .horizontal

        shortcutActionsStack.alignment =
            .centerY

        shortcutActionsStack.spacing =
            10

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                modeControl,
                toggleRow,
                enableRow,
                disableRow,
                shortcutActionsStack,
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

    private func updateControls() {
        toggleRow.isHidden =
            selectedMode
                != .toggle

        enableRow.isHidden =
            selectedMode
                != .separate

        disableRow.isHidden =
            selectedMode
                != .separate

        restoreButtonTitles()
        updateCaptureControls()
        refreshChangeState()
    }

    private func updateCaptureControls() {
        for field in
            [
                CaptureField.toggle,
                CaptureField.enable,
                CaptureField.disable
            ]
        {
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
                    true

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
                    toggleShortcut
            )

        enableRow.recordButton.title =
            title(
                for:
                    enableShortcut
            )

        disableRow.recordButton.title =
            title(
                for:
                    disableShortcut
            )
    }

    private func title(
        for shortcut:
            KeyCombination?
    ) -> String {
        guard let shortcut else {
            return "Choose Shortcut…"
        }

        return KeyCombinationDisplayName
            .name(
                for:
                    shortcut
            )
    }

    private var selectedMode:
        Mode
    {
        Mode(
            rawValue:
                modeControl
                    .selectedSegment
        ) ?? .disabled
    }

    private var proposedConfiguration:
        RemappingShortcutConfiguration?
    {
        switch selectedMode {
        case .disabled:
            return .disabled

        case .toggle:
            guard let toggleShortcut else {
                return nil
            }

            return .toggle(
                toggleShortcut
            )

        case .separate:
            guard
                let enableShortcut,
                let disableShortcut
            else {
                return nil
            }

            return .separate(
                enable:
                    enableShortcut,
                disable:
                    disableShortcut
            )
        }
    }

    private func validationMessage(
        for configuration:
            RemappingShortcutConfiguration
    ) -> String? {
        do {
            try GlobalShortcutConfigurationPolicy
                .validate(
                    configuration
                )

            return nil
        } catch let error as
            GlobalShortcutConfigurationError
        {
            switch error {
            case .duplicateShortcut:
                return "Enable and Disable must use different shortcuts."

            case .insufficientModifiers:
                return "Every global shortcut must contain at least one modifier."
            }
        } catch {
            return "The shortcut configuration is not valid."
        }
    }

    private func refreshChangeState() {
        guard
            activeCaptureField == nil
        else {
            setActionButtons(
                saveEnabled:
                    false,
                cancelEnabled:
                    true
            )

            return
        }

        guard
            let proposedConfiguration
        else {
            setActionButtons(
                saveEnabled:
                    false,
                cancelEnabled:
                    hasUnsavedChanges
            )

            setStatus(
                "Choose every shortcut required by the selected mode.",
                isError:
                    true
            )

            return
        }

        if let message =
            validationMessage(
                for:
                    proposedConfiguration
            )
        {
            setActionButtons(
                saveEnabled:
                    false,
                cancelEnabled:
                    hasUnsavedChanges
            )

            setStatus(
                message,
                isError:
                    true
            )

            return
        }

        let hasChanges =
            hasUnsavedChanges

        setActionButtons(
            saveEnabled:
                hasChanges,
            cancelEnabled:
                hasChanges
        )

        if let suggestion =
            GlobalShortcutConfigurationPolicy
                .suggestion(
                    for:
                        proposedConfiguration
                )
        {
            setSuggestion(
                suggestion.message
            )

            return
        }

        setStatus(
            hasChanges
                ? "You have unsaved shortcut changes."
                : "Shortcut settings are saved locally on this Mac.",
            isError:
                false
        )
    }

    private func setActionButtons(
        saveEnabled:
            Bool,
        cancelEnabled:
            Bool
    ) {
        saveButton.isEnabled =
            saveEnabled

        cancelButton.isEnabled =
            cancelEnabled

        updateSaveButtonAppearance()
    }

    private func updateSaveButtonAppearance() {
        saveButton.bezelColor =
            saveButton.isEnabled
                ? .controlAccentColor
                : nil
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
            toggleShortcut =
                nil

        case .enable:
            enableShortcut =
                nil

        case .disable:
            disableShortcut =
                nil
        }

        endCapturePrompt()
        updateControls()
    }

    private func setStatus(
        _ message:
            String,
        isError:
            Bool
    ) {
        statusLabel.stringValue =
            message

        statusLabel.textColor =
            isError
                ? .systemRed
                : .secondaryLabelColor
    }

    private func setSuggestion(
        _ message:
            String
    ) {
        statusLabel.stringValue =
            message

        statusLabel.textColor =
            .systemOrange
    }

    @objc
    private func modeChanged() {
        onCaptureCancellationRequested?()
        endCapturePrompt()
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
    private func cancelChanges() {
        onCaptureCancellationRequested?()

        discardChanges()
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

    /// Validates, registers, and persists the current configuration.
    ///
    /// Registration and persistence remain atomic inside
    /// GlobalShortcutController.
    @discardableResult
    func persistConfiguration()
        -> Bool
    {
        onCaptureCancellationRequested?()
        endCapturePrompt()

        guard
            let proposedConfiguration
        else {
            refreshChangeState()
            return false
        }

        if let message =
            validationMessage(
                for:
                    proposedConfiguration
            )
        {
            setStatus(
                message,
                isError:
                    true
            )

            return false
        }

        guard let onSaveRequested else {
            setStatus(
                "The shortcut configuration could not be saved.",
                isError:
                    true
            )

            return false
        }

        do {
            try onSaveRequested(
                proposedConfiguration
            )

            savedConfiguration =
                proposedConfiguration

            refreshChangeState()
            return true
        } catch let error as
            GlobalShortcutConfigurationError
        {
            switch error {
            case .duplicateShortcut:
                setStatus(
                    "Enable and Disable must use different shortcuts.",
                    isError:
                        true
                )

            case .insufficientModifiers:
                setStatus(
                    "Every global shortcut must contain at least one modifier.",
                    isError:
                        true
                )
            }

            return false
        } catch let error as
            GlobalShortcutError
        {
            switch error {
            case .registrationFailed:
                setStatus(
                    "The shortcut could not be registered. It may already be used by macOS or another application.",
                    isError:
                        true
                )

            default:
                setStatus(
                    "The shortcut configuration could not be applied.",
                    isError:
                        true
                )
            }

            return false
        } catch {
            setStatus(
                "The shortcut configuration could not be saved.",
                isError:
                    true
            )

            return false
        }
    }

    @objc
    private func saveConfiguration() {
        _ =
            persistConfiguration()
    }

}
