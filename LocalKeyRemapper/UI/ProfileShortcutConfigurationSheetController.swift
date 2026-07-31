//
//  ProfileShortcutConfigurationSheetController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A sheet window that intercepts keyboard input only while the user is
/// explicitly recording a profile shortcut.
///
/// This is a local window event override. It is not a global keyboard monitor
/// and does not store or log keyboard input.
@MainActor
private final class ProfileShortcutConfigurationSheetWindow:
    NSWindow
{
    var flagsChangedHandler:
        ((NSEvent) -> Void)?

    var keyDownHandler:
        ((NSEvent) -> Bool)?

    override func sendEvent(
        _ event:
            NSEvent
    ) {
        if event.type == .flagsChanged {
            flagsChangedHandler?(
                event
            )
        }

        if event.type == .keyDown,
           keyDownHandler?(
               event
           ) == true
        {
            return
        }

        super.sendEvent(
            event
        )
    }
}

/// Presents and coordinates the temporary shortcut editor for one profile.
///
/// The controller:
///
/// - displays the profile shortcut editor as an attached sheet;
/// - captures shortcuts only from its own sheet window;
/// - temporarily suspends remapping and Carbon registrations during capture;
/// - restores the previous runtime configuration after capture;
/// - invokes `applyHandler` only after the user explicitly presses Apply.
///
/// It never persists configuration directly and never modifies the active
/// runtime profile.
@MainActor
final class ProfileShortcutConfigurationSheetController:
    NSWindowController
{
    private let remappingController:
        RemappingSettingsControlling

    private let globalShortcutController:
        GlobalShortcutController

    private let applyHandler:
        (
            RemappingShortcutConfiguration?
        ) throws -> Void

    private let dismissalHandler:
        (() -> Void)?

    private let editorView:
        ProfileShortcutConfigurationEditorView

    private let applyButton =
        NSButton()

    private let cancelButton =
        NSButton()

    private let sheetStatusLabel =
        NSTextField(
            wrappingLabelWithString:
                ""
        )

    private let buttonsStack =
        NSStackView()

    private let contentStack =
        NSStackView()

    private var shortcutCaptureField:
        ProfileShortcutConfigurationEditorView
            .CaptureField?

    private var fnModifierStateTracker =
        FnModifierStateTracker()

    private var isFinished =
        false

    init(
        profileName:
            String,
        shortcutConfigurationOverride:
            RemappingShortcutConfiguration?,
        shortcutMemory:
            RemappingProfileShortcutMemory = .empty,
        defaultConfiguration:
            RemappingShortcutConfiguration,
        remappingController:
            RemappingSettingsControlling,
        globalShortcutController:
            GlobalShortcutController,
        additionalValidationHandler:
            ((
                RemappingShortcutConfiguration
            ) -> String?)? = nil,
        additionalSuggestionHandler:
            ((
                RemappingShortcutConfiguration
            ) -> String?)? = nil,
        applyHandler:
            @escaping (
                RemappingShortcutConfiguration?
            ) throws -> Void,
        dismissalHandler:
            (() -> Void)? = nil,
        textScale:
            CGFloat = 1.0
    ) {
        self.remappingController =
            remappingController

        self.globalShortcutController =
            globalShortcutController

        self.applyHandler =
            applyHandler

        self.dismissalHandler =
            dismissalHandler

        editorView =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    shortcutConfigurationOverride,
                shortcutMemory:
                    shortcutMemory,
                defaultConfiguration:
                    defaultConfiguration
            )

        let window =
            ProfileShortcutConfigurationSheetWindow(
                contentRect:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            620,
                        height:
                            360
                    ),
                styleMask: [
                    .titled
                ],
                backing:
                    .buffered,
                defer:
                    false
            )

        window.title =
            "Shortcut for \(profileName)"

        window.isReleasedWhenClosed =
            false

        window.contentMinSize =
            NSSize(
                width:
                    540,
                height:
                    300
            )

        super.init(
            window:
                window
        )

        editorView
            .onAdditionalValidationRequested =
                additionalValidationHandler

        editorView
            .onAdditionalSuggestionRequested =
                additionalSuggestionHandler

        configureContent()
        configureCallbacks()
        applyTextScale(
            textScale
        )

        window.flagsChangedHandler = {
            [weak self] event in

            self?.handleFlagsChanged(
                event
            )
        }

        window.keyDownHandler = {
            [weak self] event in

            self?.handleKeyDown(
                event
            )
            ?? false
        }

        updateApplyButton()
    }

    required init?(
        coder:
            NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    /// Presents this window as a sheet attached to the supplied parent.
    func present(
        attachedTo parentWindow:
            NSWindow
    ) {
        guard
            !isFinished,
            let window,
            window.sheetParent == nil
        else {
            return
        }

        parentWindow.beginSheet(
            window
        )
    }

    /// Re-evaluates profile-dependent conflicts and warnings.
    ///
    /// This is used after Rules are saved independently while the sheet remains
    /// open. It does not change the temporary shortcut proposal.
    func refreshValidationState() {
        guard
            !isFinished
        else {
            return
        }

        editorView
            .refreshValidationState()

        updateApplyButton()
    }

    /// Ends active capture and dismisses the sheet before application
    /// termination.
    func prepareForApplicationTermination() {
        endShortcutCapture()
        finish()
    }

    func applyTextScale(
        _ scale:
            CGFloat
    ) {
        let clampedScale =
            InterfaceTextScalePreference
                .clamped(
                    scale
                )

        editorView.applyTextScale(
            clampedScale
        )

        let buttonFont =
            NSFont.systemFont(
                ofSize:
                    14 * clampedScale,
                weight:
                    .regular
            )

        applyButton.font =
            buttonFont

        cancelButton.font =
            buttonFont

        sheetStatusLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * clampedScale,
                weight:
                    .regular
            )

        contentStack.spacing =
            InterfaceLayoutMetrics.scaled(
                12,
                for:
                    clampedScale,
                minimum:
                    9,
                maximum:
                    18
            )

        buttonsStack.spacing =
            InterfaceLayoutMetrics.scaled(
                8,
                for:
                    clampedScale,
                minimum:
                    6,
                maximum:
                    12
            )

        window?
            .contentView?
            .needsLayout =
                true

        window?
            .contentView?
            .layoutSubtreeIfNeeded()
    }

    // MARK: - Test support

    var canApplyForTesting:
        Bool
    {
        applyButton.isEnabled
    }

    var activeCaptureFieldForTesting:
        ProfileShortcutConfigurationEditorView
            .CaptureField?
    {
        shortcutCaptureField
    }

    var proposalForTesting:
        ProfileShortcutConfigurationOverrideProposal
    {
        editorView.proposal
    }

    var validationMessageForTesting:
        String?
    {
        editorView.currentValidationMessage
    }

    var sheetStatusForTesting:
        String
    {
        sheetStatusLabel.stringValue
    }

    var isFinishedForTesting:
        Bool
    {
        isFinished
    }

    func setModeForTesting(
        _ mode:
            ProfileShortcutConfigurationMode
    ) {
        editorView.setModeForTesting(
            mode
        )
    }

    func beginCaptureForTesting(
        _ field:
            ProfileShortcutConfigurationEditorView
                .CaptureField
    ) {
        beginShortcutCapture(
            field
        )
    }

    func captureShortcutForTesting(
        _ shortcut:
            KeyCombination
    ) {
        guard
            let shortcutCaptureField
        else {
            return
        }

        editorView.setCapturedShortcut(
            shortcut,
            for:
                shortcutCaptureField
        )

        endShortcutCapture()
    }

    func cancelCaptureForTesting() {
        endShortcutCapture()
    }

    func applyForTesting() {
        applyShortcutConfiguration()
    }

    func cancelForTesting() {
        cancelSheet()
    }

    private func configureContent() {
        guard
            let window
        else {
            return
        }

        let contentView =
            NSView()

        contentView.translatesAutoresizingMaskIntoConstraints =
            false

        editorView.translatesAutoresizingMaskIntoConstraints =
            false

        sheetStatusLabel.textColor =
            .systemRed

        sheetStatusLabel.isHidden =
            true

        sheetStatusLabel.translatesAutoresizingMaskIntoConstraints =
            false

        applyButton.title =
            "Apply"

        applyButton.bezelStyle =
            .rounded

        applyButton.keyEquivalent =
            "\r"

        applyButton.target =
            self

        applyButton.action =
            #selector(
                applyShortcutConfiguration
            )

        applyButton.setAccessibilityLabel(
            "Apply profile shortcut"
        )

        cancelButton.title =
            "Cancel"

        cancelButton.bezelStyle =
            .rounded

        cancelButton.target =
            self

        cancelButton.action =
            #selector(
                cancelSheet
            )

        cancelButton.setAccessibilityLabel(
            "Cancel profile shortcut editing"
        )

        applyButton.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        cancelButton.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        let buttonsSpacer =
            NSView()

        buttonsSpacer.setContentHuggingPriority(
            .defaultLow,
            for:
                .horizontal
        )

        buttonsStack.setViews(
            [
                buttonsSpacer,
                cancelButton,
                applyButton
            ],
            in:
                .leading
        )

        buttonsStack.orientation =
            .horizontal

        buttonsStack.alignment =
            .centerY

        buttonsStack.translatesAutoresizingMaskIntoConstraints =
            false

        contentStack.setViews(
            [
                editorView,
                sheetStatusLabel,
                buttonsStack
            ],
            in:
                .leading
        )

        contentStack.orientation =
            .vertical

        contentStack.alignment =
            .leading

        contentStack.translatesAutoresizingMaskIntoConstraints =
            false

        contentView.addSubview(
            contentStack
        )

        window.contentView =
            contentView

        NSLayoutConstraint.activate(
            [
                contentStack.topAnchor.constraint(
                    equalTo:
                        contentView.topAnchor,
                    constant:
                        22
                ),

                contentStack.leadingAnchor.constraint(
                    equalTo:
                        contentView.leadingAnchor,
                    constant:
                        24
                ),

                contentStack.trailingAnchor.constraint(
                    equalTo:
                        contentView.trailingAnchor,
                    constant:
                        -24
                ),

                contentStack.bottomAnchor.constraint(
                    equalTo:
                        contentView.bottomAnchor,
                    constant:
                        -20
                ),

                editorView.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                ),

                sheetStatusLabel.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                ),

                buttonsStack.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                )
            ]
        )
    }

    private func configureCallbacks() {
        editorView.onCaptureRequested = {
            [weak self] field in

            self?.beginShortcutCapture(
                field
            )
        }

        editorView
            .onCaptureCancellationRequested = {
                [weak self] in

                self?.endShortcutCapture()
            }

        editorView.onStateChange = {
            [weak self] in

            self?.updateApplyButton()
        }
    }

    private func updateApplyButton() {
        applyButton.isEnabled =
            !isFinished
                && editorView.canApply
    }

    private func beginShortcutCapture(
        _ field:
            ProfileShortcutConfigurationEditorView
                .CaptureField
    ) {
        guard
            !isFinished
        else {
            return
        }

        if shortcutCaptureField
            == field
        {
            endShortcutCapture()
            return
        }

        endShortcutCapture()
        clearSheetStatus()

        shortcutCaptureField =
            field

        fnModifierStateTracker.synchronize(
            isPressed:
                PhysicalFnKeyState
                    .isPressed()
        )

        remappingController
            .beginKeyCapture()

        globalShortcutController
            .beginShortcutCapture()

        editorView.beginCapturePrompt(
            for:
                field
        )

        updateApplyButton()
    }

    private func handleFlagsChanged(
        _ event:
            NSEvent
    ) {
        guard
            shortcutCaptureField != nil,
            event.keyCode
                == UInt16(
                    kVK_Function
                )
        else {
            return
        }

        fnModifierStateTracker
            .handleFlagsChanged(
                isPressed:
                    event
                        .modifierFlags
                        .contains(
                            .function
                        )
            )
    }

    private func handleKeyDown(
        _ event:
            NSEvent
    ) -> Bool {
        if let shortcutCaptureField {
            if event.keyCode
                == UInt16(
                    kVK_Escape
                )
            {
                endShortcutCapture()
                return true
            }

            let combination =
                KeyCombinationInputNormalizer
                    .combination(
                        deliveredKeyCode:
                            CGKeyCode(
                                event.keyCode
                            ),
                        modifiers:
                            KeyModifiers(
                                appKitFlags:
                                    event
                                        .modifierFlags
                            ),
                        physicalFnIsPressed:
                            fnModifierStateTracker
                                .isPressed
                    )

            editorView.setCapturedShortcut(
                combination,
                for:
                    shortcutCaptureField
            )

            endShortcutCapture()
            return true
        }

        if event.keyCode
            == UInt16(
                kVK_Escape
            )
        {
            cancelSheet()
            return true
        }

        return false
    }

    private func endShortcutCapture() {
        guard
            shortcutCaptureField != nil
        else {
            return
        }

        editorView.endCapturePrompt()

        shortcutCaptureField =
            nil

        do {
            try globalShortcutController
                .endShortcutCapture()

            clearSheetStatus()
        } catch {
            showSheetError(
                "The previous global shortcut could not be restored after key capture. It may now be used by macOS or another application."
            )
        }

        remappingController
            .endKeyCapture()

        fnModifierStateTracker
            .reset()

        updateApplyButton()
    }

    @objc
    private func applyShortcutConfiguration() {
        guard
            !isFinished,
            editorView.canApply
        else {
            updateApplyButton()
            return
        }

        guard
            case let .complete(
                proposedOverride
            ) =
                editorView.proposal
        else {
            updateApplyButton()
            return
        }

        endShortcutCapture()

        do {
            try applyHandler(
                proposedOverride
            )
        } catch {
            showSheetError(
                "The profile shortcut change could not be added to the Home draft."
            )

            updateApplyButton()
            return
        }

        finish()
    }

    @objc
    private func cancelSheet() {
        guard
            !isFinished
        else {
            return
        }

        endShortcutCapture()
        finish()
    }

    private func finish() {
        guard
            !isFinished
        else {
            return
        }

        isFinished =
            true

        updateApplyButton()

        guard
            let window
        else {
            dismissalHandler?()
            return
        }

        if let sheetParent =
            window.sheetParent
        {
            sheetParent.endSheet(
                window
            )
        } else {
            window.orderOut(
                nil
            )
        }

        dismissalHandler?()
    }

    private func showSheetError(
        _ message:
            String
    ) {
        sheetStatusLabel.stringValue =
            message

        sheetStatusLabel.isHidden =
            false
    }

    private func clearSheetStatus() {
        sheetStatusLabel.stringValue =
            ""

        sheetStatusLabel.isHidden =
            true
    }
}
