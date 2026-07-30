//
//  MainWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A main application window that intercepts a key press only while the user
/// is explicitly recording a global shortcut.
///
/// The handler receives events only from this window. It is not a global
/// keyboard monitor.
@MainActor
private final class MainWindow: NSWindow {
    var flagsChangedHandler: ((NSEvent) -> Void)?
    var keyDownHandler: ((NSEvent) -> Bool)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            flagsChangedHandler?(event)
        }

        if event.type == .keyDown,
           keyDownHandler?(event) == true {
            return
        }

        super.sendEvent(event)
    }
}

/// Keeps the scrollable Home content anchored to the top-left corner.
@MainActor
private final class MainContentFlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

/// Manages application-wide controls and preferences.
///
/// Detailed remapping-rule editing is intentionally owned by
/// `RemappingRulesWindowController` so this window remains focused on the
/// overall state of the application.
@MainActor
final class MainWindowController:
    NSWindowController,
    NSWindowDelegate
{
    private let remappingController: RemappingSettingsControlling
    private let appPreferencesController: AppPreferencesControlling
    private let globalShortcutController: GlobalShortcutController
    private let homeConfigurationEditorSession:
        HomeConfigurationEditorSession?
    private let saveHomeConfigurationHandler:
        (() throws -> Void)?
    private let profilesConfigurationProvider:
        () throws -> RemappingProfilesConfiguration
    private let menuBarVisibilityChangeHandler: (Bool) throws -> Void
    private let openAccessibilitySettingsHandler: () -> Void
    private let openRemappingRulesHandler: () -> Void
    private let openRemappingRulesForProfileHandler: (UUID) -> Void
    private let profileNameChangeHandler:
        ((RemappingProfile, String) -> Void)?
    private let increaseTextSizeHandler: () -> Void
    private let decreaseTextSizeHandler: () -> Void
    private let resetTextSizeHandler: () -> Void

    private let globalShortcutSettingsView: GlobalShortcutSettingsView
    private let profilesSectionView: HomeProfilesSectionView

    /// The application controller implements both the settings and runtime
    /// remapping interfaces. Keeping the cast here avoids widening the
    /// settings-only protocol used by tests and other UI components.
    private var remappingRuntimeController: RemappingControlling? {
        remappingController as? RemappingControlling
    }

    private let titleLabel = NSTextField(
        labelWithString: "LocalKeyRemapper"
    )

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Control keyboard remapping and configure application-wide behavior. Detailed rules are managed in their own window."
    )

    private let remappingSectionTitleLabel = NSTextField(
        labelWithString: "Remapping"
    )

    private let remappingSectionDescriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Enable or disable the active remapping configuration."
    )

    private let remappingLabel = NSTextField(
        labelWithString: "Keyboard remapping"
    )

    private let remappingSwitch = NSSwitch()
    private let remappingControlStack = NSStackView()

    private let accessibilityPermissionLabel = NSTextField(
        labelWithString: "Accessibility Permission Required"
    )

    private let openAccessibilitySettingsButton = NSButton()
    private let accessibilityPermissionStack = NSStackView()

    private let launchBehaviorTitleLabel = NSTextField(
        labelWithString: "Remapping at launch"
    )

    private let launchBehaviorDescriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Choose how remapping should behave when LocalKeyRemapper starts."
    )

    private let launchBehaviorControl = NSSegmentedControl(
        labels: [
            "Always Off",
            "Restore Last State",
            "Always On"
        ],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private let launchBehaviorStack = NSStackView()

    private let interfaceSectionTitleLabel = NSTextField(
        labelWithString: "Interface"
    )

    private let showMenuBarIconLabel = NSTextField(
        labelWithString: "Show icon in menu bar"
    )

    private let showMenuBarIconSwitch = NSSwitch()
    private let menuBarIconVisibilityStack = NSStackView()

    private let textSizeLabel = NSTextField(
        labelWithString: "Text size"
    )

    private let decreaseTextSizeButton = NSButton()
    private let resetTextSizeButton = NSButton()
    private let increaseTextSizeButton = NSButton()
    private let textSizeStack = NSStackView()
    private let interfaceStack = NSStackView()

    private let homeUndoButton = NSButton()
    private let homeRedoButton = NSButton()
    private let homeSaveButton = NSButton()
    private let homeActionsStack = NSStackView()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private let mainStack = NSStackView()
    private let contentScrollView = NSScrollView()
    private let contentDocumentView = MainContentFlippedView()

    private var contentDocumentHeightConstraint:
        NSLayoutConstraint?

    private var mainStackTopConstraint:
        NSLayoutConstraint?

    private var isAdjustingWindowFrame = false

    private var shortcutCaptureField:
        GlobalShortcutSettingsView.CaptureField?

    private var fnModifierStateTracker =
        FnModifierStateTracker()

    private var lastDisplayedProfileNames:
        [UUID: String] = [:]

    private var textScale: CGFloat

    init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        homeConfigurationEditorSession:
            HomeConfigurationEditorSession? = nil,
        saveHomeConfigurationHandler:
            (() throws -> Void)? = nil,
        profilesConfigurationProvider:
            @escaping () throws -> RemappingProfilesConfiguration = {
                throw HomeConfigurationSaveError
                    .editorSessionUnavailable
            },
        menuBarVisibilityChangeHandler:
            @escaping (Bool) throws -> Void,
        openAccessibilitySettingsHandler: @escaping () -> Void = {},
        openRemappingRulesHandler: @escaping () -> Void,
        openRemappingRulesForProfileHandler:
            ((UUID) -> Void)? = nil,
        profileNameChangeHandler:
            ((RemappingProfile, String) -> Void)? = nil,
        increaseTextSizeHandler: @escaping () -> Void,
        decreaseTextSizeHandler: @escaping () -> Void,
        resetTextSizeHandler: @escaping () -> Void,
        textScale: CGFloat? = nil
    ) {
        self.remappingController = remappingController
        self.appPreferencesController = appPreferencesController
        self.globalShortcutController = globalShortcutController
        self.homeConfigurationEditorSession =
            homeConfigurationEditorSession
        self.saveHomeConfigurationHandler =
            saveHomeConfigurationHandler
        self.profilesConfigurationProvider =
            profilesConfigurationProvider
        self.menuBarVisibilityChangeHandler =
            menuBarVisibilityChangeHandler
        self.openAccessibilitySettingsHandler =
            openAccessibilitySettingsHandler
        self.openRemappingRulesHandler =
            openRemappingRulesHandler
        self.openRemappingRulesForProfileHandler =
            openRemappingRulesForProfileHandler
                ?? {
                    _ in

                    openRemappingRulesHandler()
                }
        self.profileNameChangeHandler =
            profileNameChangeHandler
        self.increaseTextSizeHandler =
            increaseTextSizeHandler
        self.decreaseTextSizeHandler =
            decreaseTextSizeHandler
        self.resetTextSizeHandler =
            resetTextSizeHandler
        self.textScale = InterfaceTextScalePreference.clamped(
            textScale ?? InterfaceTextScalePreference.currentScale
        )

        let initialHomeSnapshot =
            homeConfigurationEditorSession?
                .draft

        globalShortcutSettingsView = GlobalShortcutSettingsView(
            configuration:
                initialHomeSnapshot?
                    .shortcutConfiguration
                    ?? appPreferencesController
                        .preferences
                        .shortcutConfiguration
        )

        let initialProfilesConfiguration =
            initialHomeSnapshot?
                .profilesConfiguration
                ?? (try? profilesConfigurationProvider())
                ?? RemappingProfilesConfiguration.initial()

        profilesSectionView =
            HomeProfilesSectionView(
                editorSession:
                    homeConfigurationEditorSession,
                initialConfiguration:
                    initialProfilesConfiguration
            )

        let window = MainWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 780,
                height: 760
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "LocalKeyRemapper"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(
            width: 680,
            height: 420
        )
        window.contentMaxSize = NSSize(
            width: 980,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.center()

        super.init(window: window)

        window.delegate = self
        window.flagsChangedHandler = { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureShortcutSettingsCallbacks()
        configureProfilesSectionCallbacks()
        configureConfigurationChangeObservation()
        configureHomeSessionObservation()
        configureContent()
        synchronizeHomeDraft()
        synchronizeMenuBarIconVisibility()
        updateRemappingState(
            remappingRuntimeController?.state ?? .disabled
        )
        applyTextScale(
            self.textScale
        )
    }

    /// Compatibility initializer retained for existing tests and call sites.
    convenience init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        menuBarVisibilityChangeHandler:
            @escaping (Bool) throws -> Void,
        openAccessibilitySettingsHandler: @escaping () -> Void = {}
    ) {
        self.init(
            remappingController: remappingController,
            appPreferencesController: appPreferencesController,
            globalShortcutController: globalShortcutController,
            menuBarVisibilityChangeHandler:
                menuBarVisibilityChangeHandler,
            openAccessibilitySettingsHandler:
                openAccessibilitySettingsHandler,
            openRemappingRulesHandler: {},
            increaseTextSizeHandler: {},
            decreaseTextSizeHandler: {},
            resetTextSizeHandler: {}
        )
    }

    /// Compatibility initializer retained while rule editing moves into its
    /// dedicated controller. The supplied session remains owned externally.
    convenience init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        ruleEditorSession: RemappingRuleEditorSession,
        menuBarVisibilityChangeHandler:
            @escaping (Bool) throws -> Void,
        openAccessibilitySettingsHandler: @escaping () -> Void = {}
    ) {
        self.init(
            remappingController: remappingController,
            appPreferencesController: appPreferencesController,
            globalShortcutController: globalShortcutController,
            menuBarVisibilityChangeHandler:
                menuBarVisibilityChangeHandler,
            openAccessibilitySettingsHandler:
                openAccessibilitySettingsHandler,
            openRemappingRulesHandler: {},
            increaseTextSizeHandler: {},
            decreaseTextSizeHandler: {},
            resetTextSizeHandler: {}
        )
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func showWindow(
        _ sender: Any?
    ) {
        if window?.isVisible == false {
            synchronizeHomeDraft()
            synchronizeMenuBarIconVisibility()
            updateRemappingState(
                remappingRuntimeController?.state ?? .disabled
            )
        }

        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApplication.shared.activate(
            ignoringOtherApps: true
        )

        requestWindowResizeToFitContent()
    }

    /// Ends local shortcut capture before another window starts its own
    /// capture session or before application-level components stop.
    func endActiveCapture() {
        endShortcutCapture()
    }

    func prepareForApplicationTermination() {
        endShortcutCapture()

        homeConfigurationEditorSession?
            .onChange =
                nil

        NotificationCenter.default.removeObserver(
            self,
            name:
                AppConfigurationNotification
                    .remappingRulesDidChange,
            object:
                nil
        )
    }

    func windowDidBecomeKey(
        _ notification: Notification
    ) {
        globalShortcutSettingsView
            .refreshValidationState()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale = InterfaceTextScalePreference.clamped(
            scale
        )

        titleLabel.font = NSFont.systemFont(
            ofSize: 22 * textScale,
            weight: .semibold
        )
        descriptionLabel.font = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        let sectionTitleFont = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .semibold
        )
        let descriptionFont = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )
        let controlFont = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        remappingSectionTitleLabel.font = sectionTitleFont
        remappingSectionDescriptionLabel.font = descriptionFont
        remappingLabel.font = controlFont
        accessibilityPermissionLabel.font = descriptionFont
        openAccessibilitySettingsButton.font = controlFont

        launchBehaviorTitleLabel.font = sectionTitleFont
        launchBehaviorDescriptionLabel.font = descriptionFont
        launchBehaviorControl.font = controlFont

        profilesSectionView.applyTextScale(
            textScale
        )

        interfaceSectionTitleLabel.font = sectionTitleFont
        showMenuBarIconLabel.font = controlFont
        textSizeLabel.font = controlFont
        decreaseTextSizeButton.font = controlFont
        resetTextSizeButton.font = controlFont
        increaseTextSizeButton.font = controlFont
        homeUndoButton.font = controlFont
        homeRedoButton.font = controlFont
        homeSaveButton.font = controlFont
        statusLabel.font = descriptionFont

        globalShortcutSettingsView.applyTextScale(
            textScale
        )

        remappingControlStack.spacing =
            InterfaceLayoutMetrics.scaled(
                8,
                for: textScale,
                minimum: 6,
                maximum: 12
            )

        accessibilityPermissionStack.spacing =
            InterfaceLayoutMetrics.scaled(
                8,
                for: textScale,
                minimum: 6,
                maximum: 12
            )

        menuBarIconVisibilityStack.spacing =
            InterfaceLayoutMetrics.scaled(
                8,
                for: textScale,
                minimum: 6,
                maximum: 12
            )

        textSizeStack.spacing =
            InterfaceLayoutMetrics.scaled(
                7,
                for: textScale,
                minimum: 5,
                maximum: 11
            )

        homeActionsStack.spacing =
            InterfaceLayoutMetrics.scaled(
                8,
                for: textScale,
                minimum: 6,
                maximum: 12
            )

        applyLayoutMetrics()

        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()

        requestWindowResizeToFitContent()
    }

    /// Compatibility methods retained for direct controller use. The
    /// coordinator normally applies the shared scale to every open window.
    func increaseTextSize() {
        applyTextScale(
            InterfaceTextScalePreference.set(
                textScale + InterfaceTextScalePreference.step
            )
        )
    }

    func decreaseTextSize() {
        applyTextScale(
            InterfaceTextScalePreference.set(
                textScale - InterfaceTextScalePreference.step
            )
        )
    }

    func resetTextSize() {
        applyTextScale(
            InterfaceTextScalePreference.reset()
        )
    }

    /// Updates controls to reflect the real backend state.
    func updateRemappingState(
        _ state: RemappingState
    ) {
        let canControlRemapping =
            remappingRuntimeController != nil

        switch state {
        case .disabled:
            remappingSwitch.state = .off
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = true

        case .enabling:
            remappingSwitch.state = .on
            remappingSwitch.isEnabled = false
            accessibilityPermissionStack.isHidden = true

        case .enabled:
            remappingSwitch.state = .on
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = true

        case .permissionRequired:
            remappingSwitch.state = .off
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = false

        case .failed:
            remappingSwitch.state = .off
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = true
        }

        requestWindowResizeToFitContent()
    }

    /// Updates the switch when the preference changes elsewhere, such as
    /// from the application's native menu.
    func updateMenuBarIconVisibility(
        _ showsMenuBarIcon: Bool
    ) {
        showMenuBarIconSwitch.state =
            showsMenuBarIcon ? .on : .off
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        endShortcutCapture()

        guard hasUnsavedHomeChanges else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Save changes before closing?"
        alert.informativeText =
            "Profiles, Remapping at Launch, or Global Shortcut settings have been modified."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveHomeConfiguration()

        case .alertSecondButtonReturn:
            discardHomeChanges()
            return true

        default:
            return false
        }
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        endShortcutCapture()
    }

    func windowDidResize(
        _ notification: Notification
    ) {
        guard !isAdjustingWindowFrame else {
            return
        }

        updateScrollableContentHeight()
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        descriptionLabel.textColor = .secondaryLabelColor
        remappingSectionDescriptionLabel.textColor = .secondaryLabelColor
        launchBehaviorDescriptionLabel.textColor = .secondaryLabelColor
        statusLabel.textColor = .secondaryLabelColor

        configureRemappingSection()
        configureLaunchBehavior()
        configureMenuBarVisibilityPreference()
        configureTextSizeControls()
        configureHomeActions()
        configureAccessibilityPermissionNotice()

        interfaceStack.setViews(
            [
                interfaceSectionTitleLabel,
                menuBarIconVisibilityStack,
                textSizeStack
            ],
            in: .leading
        )
        interfaceStack.orientation = .vertical
        interfaceStack.alignment = .leading

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                remappingSectionTitleLabel,
                remappingSectionDescriptionLabel,
                remappingControlStack,
                accessibilityPermissionStack,
                launchBehaviorStack,
                globalShortcutSettingsView,
                profilesSectionView,
                interfaceStack,
                homeActionsStack,
                statusLabel
            ],
            in: .leading
        )
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        globalShortcutSettingsView.translatesAutoresizingMaskIntoConstraints =
            false
        launchBehaviorStack.translatesAutoresizingMaskIntoConstraints = false
        remappingControlStack.translatesAutoresizingMaskIntoConstraints = false
        accessibilityPermissionStack.translatesAutoresizingMaskIntoConstraints =
            false
        profilesSectionView.translatesAutoresizingMaskIntoConstraints = false
        interfaceStack.translatesAutoresizingMaskIntoConstraints = false
        menuBarIconVisibilityStack.translatesAutoresizingMaskIntoConstraints =
            false
        homeActionsStack.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        configureContentScrollView()

        contentDocumentView.addSubview(
            mainStack
        )

        contentView.addSubview(
            contentScrollView
        )

        let mainStackTopConstraint =
            mainStack.topAnchor.constraint(
                equalTo:
                    contentDocumentView.topAnchor
            )

        let contentDocumentHeightConstraint =
            contentDocumentView.heightAnchor.constraint(
                equalToConstant: 1
            )

        self.mainStackTopConstraint =
            mainStackTopConstraint

        self.contentDocumentHeightConstraint =
            contentDocumentHeightConstraint

        NSLayoutConstraint.activate(
            [
                contentScrollView.topAnchor.constraint(
                    equalTo:
                        contentView.topAnchor
                ),
                contentScrollView.leadingAnchor.constraint(
                    equalTo:
                        contentView.leadingAnchor
                ),
                contentScrollView.trailingAnchor.constraint(
                    equalTo:
                        contentView.trailingAnchor
                ),
                contentScrollView.bottomAnchor.constraint(
                    equalTo:
                        contentView.bottomAnchor
                ),
                contentDocumentView.widthAnchor.constraint(
                    equalTo:
                        contentScrollView.contentView.widthAnchor
                ),
                contentDocumentHeightConstraint,
                mainStackTopConstraint,
                mainStack.leadingAnchor.constraint(
                    equalTo:
                        contentDocumentView.leadingAnchor,
                    constant: 28
                ),
                mainStack.trailingAnchor.constraint(
                    equalTo:
                        contentDocumentView.trailingAnchor,
                    constant: -28
                ),
                remappingControlStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                accessibilityPermissionStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                launchBehaviorStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                globalShortcutSettingsView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                profilesSectionView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                interfaceStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                menuBarIconVisibilityStack.widthAnchor.constraint(
                    equalTo: interfaceStack.widthAnchor
                ),
                homeActionsStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                statusLabel.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                )
            ]
        )
    }

    private func configureContentScrollView() {
        contentScrollView.hasVerticalScroller = true
        contentScrollView.autohidesScrollers = true
        contentScrollView.borderType = .noBorder
        contentScrollView.drawsBackground = false
        contentScrollView.documentView = contentDocumentView
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false

        contentDocumentView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func applyLayoutMetrics() {
        mainStackTopConstraint?.constant =
            InterfaceLayoutMetrics.topContentMargin(
                for: textScale
            )

        mainStack.spacing =
            InterfaceLayoutMetrics.scaled(
                7,
                for: textScale,
                minimum: 5,
                maximum: 11
            )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                5,
                for: textScale,
                minimum: 4,
                maximum: 8
            ),
            after: titleLabel
        )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                12,
                for: textScale,
                minimum: 9,
                maximum: 18
            ),
            after: descriptionLabel
        )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                4,
                for: textScale,
                minimum: 3,
                maximum: 7
            ),
            after: remappingSectionTitleLabel
        )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                6,
                for: textScale,
                minimum: 4,
                maximum: 9
            ),
            after: remappingSectionDescriptionLabel
        )

        let sectionSpacing =
            InterfaceLayoutMetrics.scaled(
                12,
                for: textScale,
                minimum: 9,
                maximum: 18
            )

        mainStack.setCustomSpacing(
            sectionSpacing,
            after: remappingControlStack
        )

        mainStack.setCustomSpacing(
            sectionSpacing,
            after: accessibilityPermissionStack
        )

        mainStack.setCustomSpacing(
            sectionSpacing,
            after: launchBehaviorStack
        )

        mainStack.setCustomSpacing(
            sectionSpacing,
            after: globalShortcutSettingsView
        )

        mainStack.setCustomSpacing(
            sectionSpacing,
            after: profilesSectionView
        )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                12,
                for: textScale,
                minimum: 9,
                maximum: 18
            ),
            after: interfaceStack
        )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                8,
                for: textScale,
                minimum: 6,
                maximum: 12
            ),
            after: homeActionsStack
        )

        launchBehaviorStack.spacing =
            InterfaceLayoutMetrics.scaled(
                5,
                for: textScale,
                minimum: 4,
                maximum: 8
            )

        launchBehaviorStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                4,
                for: textScale,
                minimum: 3,
                maximum: 7
            ),
            after: launchBehaviorTitleLabel
        )

        launchBehaviorStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                6,
                for: textScale,
                minimum: 4,
                maximum: 9
            ),
            after: launchBehaviorDescriptionLabel
        )

        interfaceStack.spacing =
            InterfaceLayoutMetrics.scaled(
                7,
                for: textScale,
                minimum: 5,
                maximum: 11
            )

        interfaceStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                5,
                for: textScale,
                minimum: 4,
                maximum: 8
            ),
            after: interfaceSectionTitleLabel
        )
    }

    private var bottomContentMargin: CGFloat {
        InterfaceLayoutMetrics.scaled(
            15,
            for: textScale,
            minimum: 12,
            maximum: 24
        )
    }

    @discardableResult
    private func updateScrollableContentHeight() -> CGFloat {
        guard
            contentDocumentHeightConstraint != nil
        else {
            return 0
        }

        window?.contentView?.layoutSubtreeIfNeeded()
        contentDocumentView.layoutSubtreeIfNeeded()
        mainStack.layoutSubtreeIfNeeded()

        let requiredHeight =
            ceil(
                InterfaceLayoutMetrics.topContentMargin(
                    for: textScale
                )
                + mainStack.fittingSize.height
                + bottomContentMargin
            )

        let viewportHeight =
            contentScrollView
                .contentView
                .bounds
                .height

        contentDocumentHeightConstraint?.constant =
            max(
                requiredHeight,
                viewportHeight
            )

        return requiredHeight
    }

    private func requestWindowResizeToFitContent() {
        DispatchQueue.main.async {
            [weak self] in

            self?.resizeWindowToFitContent()
        }
    }

    private func resizeWindowToFitContent() {
        guard
            let window,
            let screen =
                window.screen
                    ?? NSScreen.main
        else {
            return
        }

        window.contentView?.layoutSubtreeIfNeeded()

        let requiredContentHeight =
            updateScrollableContentHeight()

        guard requiredContentHeight > 0 else {
            return
        }

        let currentContentRect =
            window.contentRect(
                forFrameRect:
                    window.frame
            )

        let desiredFrameRect =
            window.frameRect(
                forContentRect:
                    NSRect(
                        origin: .zero,
                        size:
                            NSSize(
                                width:
                                    currentContentRect.width,
                                height:
                                    requiredContentHeight
                            )
                    )
            )

        let minimumFrameRect =
            window.frameRect(
                forContentRect:
                    NSRect(
                        origin: .zero,
                        size:
                            window.contentMinSize
                    )
            )

        let visibleFrame =
            screen.visibleFrame

        let targetHeight =
            min(
                max(
                    desiredFrameRect.height,
                    minimumFrameRect.height
                ),
                visibleFrame.height
            )

        let preservedTop =
            min(
                window.frame.maxY,
                visibleFrame.maxY
            )

        var targetFrame =
            window.frame

        targetFrame.size.height =
            targetHeight

        targetFrame.origin.y =
            preservedTop - targetHeight

        if targetFrame.minY
            < visibleFrame.minY
        {
            targetFrame.origin.y =
                visibleFrame.minY
        }

        if targetFrame.maxY
            > visibleFrame.maxY
        {
            targetFrame.origin.y =
                visibleFrame.maxY
                    - targetHeight
        }

        targetFrame.origin.x =
            min(
                max(
                    targetFrame.origin.x,
                    visibleFrame.minX
                ),
                visibleFrame.maxX
                    - targetFrame.width
            )

        isAdjustingWindowFrame = true

        window.setFrame(
            targetFrame,
            display: true,
            animate: false
        )

        isAdjustingWindowFrame = false

        updateScrollableContentHeight()

        if requiredContentHeight
            > contentScrollView
                .contentView
                .bounds
                .height
        {
            contentScrollView
                .contentView
                .scroll(
                    to: .zero
                )

            contentScrollView
                .reflectScrolledClipView(
                    contentScrollView
                        .contentView
                )
        }
    }

    private func configureRemappingSection() {
        remappingLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        remappingSwitch.target = self
        remappingSwitch.action = #selector(
            remappingSwitchChanged
        )
        remappingSwitch.toolTip =
            "Enable or disable keyboard remapping."
        remappingSwitch.setAccessibilityLabel(
            "Keyboard remapping"
        )
        remappingSwitch.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        let spacer = NSView()
        spacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        remappingControlStack.setViews(
            [
                remappingLabel,
                spacer,
                remappingSwitch
            ],
            in: .leading
        )
        remappingControlStack.orientation = .horizontal
        remappingControlStack.alignment = .centerY
    }

    @objc
    private func remappingSwitchChanged() {
        guard let remappingRuntimeController else {
            updateRemappingState(.disabled)
            return
        }

        if remappingSwitch.state == .on {
            remappingRuntimeController.enable()
        } else {
            remappingRuntimeController.disable()
        }

        updateRemappingState(
            remappingRuntimeController.state
        )
    }

    private func configureAccessibilityPermissionNotice() {
        accessibilityPermissionLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        openAccessibilitySettingsButton.title =
            "Open Accessibility Settings…"
        openAccessibilitySettingsButton.bezelStyle = .rounded
        openAccessibilitySettingsButton.target = self
        openAccessibilitySettingsButton.action = #selector(
            openAccessibilitySettings
        )

        accessibilityPermissionStack.setViews(
            [
                accessibilityPermissionLabel,
                openAccessibilitySettingsButton
            ],
            in: .leading
        )
        accessibilityPermissionStack.orientation = .horizontal
        accessibilityPermissionStack.alignment = .centerY
        accessibilityPermissionStack.isHidden = true
    }

    @objc
    private func openAccessibilitySettings() {
        openAccessibilitySettingsHandler()
    }

    private func configureLaunchBehavior() {
        launchBehaviorControl.segmentStyle = .automatic
        launchBehaviorControl.identifier =
            NSUserInterfaceItemIdentifier(
                "home.launchBehavior"
            )
        launchBehaviorControl.target = self
        launchBehaviorControl.action = #selector(
            launchBehaviorChanged
        )
        launchBehaviorControl.toolTip =
            "Choose whether remapping starts off, restores its last state, or starts on."

        launchBehaviorStack.setViews(
            [
                launchBehaviorTitleLabel,
                launchBehaviorDescriptionLabel,
                launchBehaviorControl
            ],
            in: .leading
        )
        launchBehaviorStack.orientation = .vertical
        launchBehaviorStack.alignment = .leading

        launchBehaviorControl.translatesAutoresizingMaskIntoConstraints =
            false
        launchBehaviorControl.widthAnchor.constraint(
            equalTo: launchBehaviorStack.widthAnchor
        ).isActive = true
    }

    private func synchronizeLaunchBehavior() {
        let launchBehavior =
            homeConfigurationEditorSession?
                .draft
                .launchBehavior
                ?? appPreferencesController
                    .preferences
                    .launchBehavior

        launchBehaviorControl.selectedSegment = segmentIndex(
            for:
                launchBehavior
        )
    }

    @objc
    private func launchBehaviorChanged() {
        guard let requestedBehavior = launchBehavior(
            for: launchBehaviorControl.selectedSegment
        ) else {
            synchronizeLaunchBehavior()
            return
        }

        if let homeConfigurationEditorSession {
            homeConfigurationEditorSession
                .setLaunchBehavior(
                    requestedBehavior
                )

            setStatus(
                "The launch behavior was added to the Home draft.",
                isError: false
            )

            return
        }

        let previousBehavior =
            appPreferencesController
                .preferences
                .launchBehavior

        do {
            try appPreferencesController.setLaunchBehavior(
                requestedBehavior
            )
            setStatus(
                "The launch behavior was saved locally on this Mac.",
                isError: false
            )
        } catch {
            launchBehaviorControl.selectedSegment = segmentIndex(
                for: previousBehavior
            )
            setStatus(
                "The launch behavior could not be saved.",
                isError: true
            )
        }
    }

    private func segmentIndex(
        for launchBehavior: RemappingLaunchBehavior
    ) -> Int {
        switch launchBehavior {
        case .alwaysOff:
            return 0
        case .restoreLastState:
            return 1
        case .alwaysOn:
            return 2
        }
    }

    private func launchBehavior(
        for segmentIndex: Int
    ) -> RemappingLaunchBehavior? {
        switch segmentIndex {
        case 0:
            return .alwaysOff
        case 1:
            return .restoreLastState
        case 2:
            return .alwaysOn
        default:
            return nil
        }
    }

    private func configureMenuBarVisibilityPreference() {
        showMenuBarIconLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        showMenuBarIconSwitch.target = self
        showMenuBarIconSwitch.action = #selector(
            menuBarIconVisibilityChanged
        )
        showMenuBarIconSwitch.toolTip =
            "Show or hide the optional LocalKeyRemapper menu bar icon."
        showMenuBarIconSwitch.setAccessibilityLabel(
            "Show icon in menu bar"
        )
        showMenuBarIconSwitch.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        let spacer = NSView()
        spacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        menuBarIconVisibilityStack.setViews(
            [
                showMenuBarIconLabel,
                spacer,
                showMenuBarIconSwitch
            ],
            in: .leading
        )
        menuBarIconVisibilityStack.orientation = .horizontal
        menuBarIconVisibilityStack.alignment = .centerY
    }

    private func synchronizeMenuBarIconVisibility() {
        updateMenuBarIconVisibility(
            appPreferencesController.preferences.showsMenuBarIcon
        )
    }

    @objc
    private func menuBarIconVisibilityChanged() {
        let previousVisibility =
            appPreferencesController.preferences.showsMenuBarIcon
        let requestedVisibility =
            showMenuBarIconSwitch.state == .on

        do {
            try menuBarVisibilityChangeHandler(
                requestedVisibility
            )
            setStatus(
                "The menu bar preference was saved locally on this Mac.",
                isError: false
            )
        } catch {
            updateMenuBarIconVisibility(
                previousVisibility
            )
            setStatus(
                "The menu bar preference could not be saved.",
                isError: true
            )
        }
    }

    private func configureTextSizeControls() {
        decreaseTextSizeButton.title = "−"
        decreaseTextSizeButton.bezelStyle = .rounded
        decreaseTextSizeButton.target = self
        decreaseTextSizeButton.action = #selector(
            decreaseTextSizeButtonPressed
        )
        decreaseTextSizeButton.toolTip =
            "Decrease application text size."

        resetTextSizeButton.title = "Reset"
        resetTextSizeButton.bezelStyle = .rounded
        resetTextSizeButton.target = self
        resetTextSizeButton.action = #selector(
            resetTextSizeButtonPressed
        )
        resetTextSizeButton.toolTip =
            "Restore the default application text size."

        increaseTextSizeButton.title = "+"
        increaseTextSizeButton.bezelStyle = .rounded
        increaseTextSizeButton.target = self
        increaseTextSizeButton.action = #selector(
            increaseTextSizeButtonPressed
        )
        increaseTextSizeButton.toolTip =
            "Increase application text size."

        for button in [
            decreaseTextSizeButton,
            resetTextSizeButton,
            increaseTextSizeButton
        ] {
            button.setContentHuggingPriority(
                .required,
                for: .horizontal
            )
        }

        textSizeStack.setViews(
            [
                textSizeLabel,
                decreaseTextSizeButton,
                resetTextSizeButton,
                increaseTextSizeButton
            ],
            in: .leading
        )
        textSizeStack.orientation = .horizontal
        textSizeStack.alignment = .centerY
    }

    @objc
    private func decreaseTextSizeButtonPressed() {
        decreaseTextSizeHandler()
    }

    @objc
    private func resetTextSizeButtonPressed() {
        resetTextSizeHandler()
    }

    @objc
    private func increaseTextSizeButtonPressed() {
        increaseTextSizeHandler()
    }

    private func configureConfigurationChangeObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector:
                #selector(
                    remappingRulesDidChange
                ),
            name:
                AppConfigurationNotification
                    .remappingRulesDidChange,
            object:
                nil
        )
    }

    @objc
    private func remappingRulesDidChange(
        _ notification: Notification
    ) {
        guard
            window?.isVisible == true
        else {
            return
        }

        globalShortcutSettingsView
            .refreshValidationState()

        if let persistedConfiguration =
            try? profilesConfigurationProvider()
        {
            profilesSectionView
                .updatePersistedRuleCounts(
                    from:
                        persistedConfiguration
                )
        }

        // Rules are saved independently from Home. Recompute the Home action
        // state because a saved rule change may remove or introduce a shortcut
        // conflict without changing the Home draft itself.
        updateHomeActionControls()
    }

    private func configureProfilesSectionCallbacks() {
        profilesSectionView.onOpenProfile = {
            [weak self] profileID in

            guard let self else {
                return
            }

            self.endShortcutCapture()
            self.openRemappingRulesForProfileHandler(
                profileID
            )
        }

        profilesSectionView.onStatusChange = {
            [weak self] message,
            isError in

            self?.setStatus(
                message,
                isError:
                    isError
            )
        }

        profilesSectionView.onPreferredHeightChange = {
            [weak self] in

            self?.requestWindowResizeToFitContent()
        }
    }

    private func configureShortcutSettingsCallbacks() {
        globalShortcutSettingsView.onCaptureRequested = {
            [weak self] field in

            self?.beginShortcutCapture(field)
        }

        globalShortcutSettingsView.onCaptureCancellationRequested = {
            [weak self] in

            self?.endShortcutCapture()
        }

        globalShortcutSettingsView.onAdditionalValidationRequested = {
            [weak self] configuration in

            self?.shortcutConflictValidationMessage(
                for:
                    configuration
            )
        }

        globalShortcutSettingsView.onAdditionalSuggestionRequested = {
            [weak self] configuration in

            self?.shortcutPreserveWarningMessage(
                for:
                    configuration
            )
        }

        globalShortcutSettingsView.onConfigurationChangeRequested = {
            [weak self] configuration in

            guard let self else {
                return
            }

            if let homeConfigurationEditorSession =
                self.homeConfigurationEditorSession
            {
                homeConfigurationEditorSession
                    .setShortcutConfiguration(
                        configuration
                    )

                self.setStatus(
                    "The shortcut configuration was added to the Home draft.",
                    isError:
                        false
                )
            } else {
                do {
                    try self.globalShortcutController
                        .setConfiguration(
                            configuration
                        )

                    self.globalShortcutSettingsView
                        .load(
                            configuration:
                                configuration
                        )
                } catch {
                    self.setStatus(
                        "The shortcut configuration could not be applied.",
                        isError:
                            true
                    )
                }
            }
        }
    }

    /// Returns the profile collection that a Home Save would validate now.
    ///
    /// Home metadata comes from the shared draft, while Rules content is merged
    /// from the latest persisted configuration so independent Rules saves are
    /// reflected immediately without entering Home Undo/Redo history.
    private func profilesConfigurationForShortcutValidation()
        throws -> RemappingProfilesConfiguration
    {
        let persistedConfiguration =
            try profilesConfigurationProvider()

        guard
            let draftConfiguration =
                homeConfigurationEditorSession?
                    .draft
                    .profilesConfiguration
        else {
            return persistedConfiguration
        }

        return HomeProfilesConfigurationMerger
            .merging(
                homeDraft:
                    draftConfiguration,
                persisted:
                    persistedConfiguration
            )
    }

    /// Returns a blocking message when the proposed shortcut configuration
    /// conflicts with an exact mapping in any profile participating in the
    /// current Home draft.
    private func shortcutConflictValidationMessage(
        for configuration:
            RemappingShortcutConfiguration
    ) -> String? {
        guard
            !configuration
                .registrations
                .isEmpty
        else {
            return nil
        }

        do {
            let profilesConfiguration =
                try profilesConfigurationForShortcutValidation()

            let affectedProfiles =
                profilesConfiguration
                    .profiles
                    .compactMap {
                        profile -> String? in

                        guard
                            !RemappingShortcutRuleConflictPolicy
                                .conflicts(
                                    rules:
                                        profile.rules,
                                    shortcutConfiguration:
                                        configuration
                                )
                                .isEmpty
                        else {
                            return nil
                        }

                        return profile.name
                    }

            guard
                !affectedProfiles.isEmpty
            else {
                return nil
            }

            let quotedNames =
                affectedProfiles
                    .map {
                        "“\($0)”"
                    }
                    .joined(
                        separator:
                            ", "
                    )

            if affectedProfiles.count == 1 {
                return "The proposed shortcut conflicts with an exact mapping in \(quotedNames). Change the mapping, remove the matching exception, or choose a different shortcut before saving."
            }

            return "The proposed shortcuts conflict with exact mappings in \(affectedProfiles.count) profiles: \(quotedNames)."
        } catch {
            return "The remapping profiles could not be loaded for shortcut validation."
        }
    }

    /// Returns non-blocking guidance when one or more profiles contain a
    /// matching Preserve Modifiers rule.
    private func shortcutPreserveWarningMessage(
        for configuration:
            RemappingShortcutConfiguration
    ) -> String? {
        guard
            !configuration
                .registrations
                .isEmpty
        else {
            return nil
        }

        do {
            let profilesConfiguration =
                try profilesConfigurationForShortcutValidation()

            let affectedProfiles =
                profilesConfiguration
                    .profiles
                    .compactMap {
                        profile -> String? in

                        guard
                            !RemappingShortcutRuleConflictPolicy
                                .warnings(
                                    rules:
                                        profile.rules,
                                    shortcutConfiguration:
                                        configuration
                                )
                                .isEmpty
                        else {
                            return nil
                        }

                        return profile.name
                    }

            guard
                !affectedProfiles.isEmpty
            else {
                return nil
            }

            let quotedNames =
                affectedProfiles
                    .map {
                        "“\($0)”"
                    }
                    .joined(
                        separator:
                            ", "
                    )

            if affectedProfiles.count == 1 {
                return "The application shortcuts remain reserved and bypass matching Preserve Modifiers rules in \(quotedNames)."
            }

            return "The application shortcuts remain reserved and bypass matching Preserve Modifiers rules in \(affectedProfiles.count) profiles: \(quotedNames)."
        } catch {
            // Loading failures are surfaced by blocking validation.
            return nil
        }
    }

    private func beginShortcutCapture(
        _ field: GlobalShortcutSettingsView.CaptureField
    ) {
        if shortcutCaptureField == field {
            endShortcutCapture()
            return
        }

        endShortcutCapture()
        shortcutCaptureField = field
        beginCaptureSession()
        globalShortcutSettingsView.beginCapturePrompt(
            for: field
        )
        updateHomeActionControls()
    }

    private func beginCaptureSession() {
        fnModifierStateTracker.synchronize(
            isPressed: PhysicalFnKeyState.isPressed()
        )
        remappingController.beginKeyCapture()
        globalShortcutController.beginShortcutCapture()
    }

    private func handleFlagsChanged(
        _ event: NSEvent
    ) {
        guard shortcutCaptureField != nil,
              event.keyCode == UInt16(kVK_Function) else {
            return
        }

        fnModifierStateTracker.handleFlagsChanged(
            isPressed:
                event.modifierFlags.contains(.function)
        )
    }

    private func handleKeyDown(
        _ event: NSEvent
    ) -> Bool {
        if let shortcutCaptureField {
            if event.keyCode == UInt16(kVK_Escape) {
                endShortcutCapture()
                return true
            }

            let combination = keyCombination(
                from: event
            )
            globalShortcutSettingsView.setCapturedShortcut(
                combination,
                for: shortcutCaptureField
            )
            endShortcutCapture()
            return true
        }

        let relevantModifiers =
            event
                .modifierFlags
                .intersection(
                    .deviceIndependentFlagsMask
                )

        guard
            event.keyCode == UInt16(kVK_ANSI_Z),
            relevantModifiers.contains(.command)
        else {
            return false
        }

        if relevantModifiers.contains(.shift) {
            redoHomeConfiguration()
        } else {
            undoHomeConfiguration()
        }

        return true
    }

    private func keyCombination(
        from event: NSEvent
    ) -> KeyCombination {
        KeyCombinationInputNormalizer.combination(
            deliveredKeyCode: CGKeyCode(event.keyCode),
            modifiers: KeyModifiers(
                appKitFlags: event.modifierFlags
            ),
            physicalFnIsPressed:
                fnModifierStateTracker.isPressed
        )
    }

    private func endShortcutCapture() {
        guard shortcutCaptureField != nil else {
            return
        }

        globalShortcutSettingsView.endCapturePrompt()
        shortcutCaptureField = nil

        do {
            try globalShortcutController.endShortcutCapture()
        } catch {
            globalShortcutSettingsView.showCaptureRestorationFailure()
            setStatus(
                "The previous global shortcut could not be restored after key capture.",
                isError: true
            )
        }

        remappingController.endKeyCapture()
        fnModifierStateTracker.reset()
        updateHomeActionControls()
    }

    private func configureHomeSessionObservation() {
        homeConfigurationEditorSession?
            .onChange = {
                [weak self] in

                self?.synchronizeHomeDraft()
            }
    }

    private func configureHomeActions() {
        homeUndoButton.title =
            "Undo"
        homeUndoButton.identifier =
            NSUserInterfaceItemIdentifier(
                "home.undo"
            )
        homeUndoButton.bezelStyle =
            .rounded
        homeUndoButton.target =
            self
        homeUndoButton.action =
            #selector(
                undoHomeConfiguration
            )
        homeUndoButton.toolTip =
            "Undo the most recent Home configuration change (Command-Z)."

        homeRedoButton.title =
            "Redo"
        homeRedoButton.identifier =
            NSUserInterfaceItemIdentifier(
                "home.redo"
            )
        homeRedoButton.bezelStyle =
            .rounded
        homeRedoButton.target =
            self
        homeRedoButton.action =
            #selector(
                redoHomeConfiguration
            )
        homeRedoButton.toolTip =
            "Redo the most recently undone Home change (Shift-Command-Z)."

        homeSaveButton.title =
            "Save"
        homeSaveButton.identifier =
            NSUserInterfaceItemIdentifier(
                "home.save"
            )
        homeSaveButton.bezelStyle =
            .rounded
        homeSaveButton.target =
            self
        homeSaveButton.action =
            #selector(
                saveHomeConfigurationButtonPressed
            )
        homeSaveButton.toolTip =
            "Validate and save the complete Home configuration."

        let spacer =
            NSView()
        spacer.setContentHuggingPriority(
            .defaultLow,
            for:
                .horizontal
        )

        homeActionsStack.setViews(
            [
                homeUndoButton,
                homeRedoButton,
                spacer,
                homeSaveButton
            ],
            in:
                .leading
        )
        homeActionsStack.orientation =
            .horizontal
        homeActionsStack.alignment =
            .centerY

        updateHomeActionControls()
    }

    private func synchronizeHomeDraft(
        forceShortcutReload:
            Bool = false
    ) {
        synchronizeLaunchBehavior()

        let profilesConfiguration =
            homeConfigurationEditorSession?
                .draft
                .profilesConfiguration
                ?? (try? profilesConfigurationProvider())

        if let profilesConfiguration {
            synchronizeDisplayedProfileNames(
                with:
                    profilesConfiguration
            )

            profilesSectionView.load(
                configuration:
                    profilesConfiguration
            )
        }

        let shortcutConfiguration =
            homeConfigurationEditorSession?
                .draft
                .shortcutConfiguration
                ?? appPreferencesController
                    .preferences
                    .shortcutConfiguration

        if forceShortcutReload
            || globalShortcutSettingsView
                .authoritativeConfiguration
                != shortcutConfiguration
        {
            globalShortcutSettingsView.load(
                configuration:
                    shortcutConfiguration
            )
        } else {
            globalShortcutSettingsView
                .refreshValidationState()
        }

        updateHomeActionControls()
        requestWindowResizeToFitContent()
    }

    private func synchronizeDisplayedProfileNames(
        with configuration:
            RemappingProfilesConfiguration
    ) {
        let previousNames =
            lastDisplayedProfileNames

        let currentNames =
            Dictionary(
                uniqueKeysWithValues:
                    configuration
                        .profiles
                        .map {
                            profile in

                            (
                                profile.id,
                                profile.name
                            )
                        }
            )

        if !previousNames.isEmpty {
            for profile in configuration.profiles {
                guard
                    let previousName =
                        previousNames[
                            profile.id
                        ],
                    previousName != profile.name
                else {
                    continue
                }

                profileNameChangeHandler?(
                    profile,
                    previousName
                )
            }
        }

        lastDisplayedProfileNames =
            currentNames
    }

    private var hasUnsavedHomeChanges:
        Bool
    {
        homeConfigurationEditorSession?
            .hasUnsavedChanges
            == true
            || globalShortcutSettingsView
                .hasTransientEditorChanges
    }

    private func updateHomeActionControls() {
        let isCapturing =
            shortcutCaptureField != nil

        let hasTransientShortcutChanges =
            globalShortcutSettingsView
                .hasTransientEditorChanges

        homeUndoButton.isEnabled =
            !isCapturing
                && !hasTransientShortcutChanges
                && homeConfigurationEditorSession?
                    .canUndo
                    == true

        homeRedoButton.isEnabled =
            !isCapturing
                && !hasTransientShortcutChanges
                && homeConfigurationEditorSession?
                    .canRedo
                    == true

        homeSaveButton.isEnabled =
            !isCapturing
                && homeConfigurationEditorSession?
                    .hasUnsavedChanges
                    == true
                && globalShortcutSettingsView
                    .currentValidationMessage
                    == nil
                && !globalShortcutSettingsView
                    .hasTransientEditorChanges

        homeSaveButton.bezelColor =
            homeSaveButton.isEnabled
                ? .controlAccentColor
                : nil
    }

    @objc
    private func undoHomeConfiguration() {
        guard
            shortcutCaptureField == nil,
            !globalShortcutSettingsView
                .hasTransientEditorChanges
        else {
            return
        }

        homeConfigurationEditorSession?
            .undo()
    }

    @objc
    private func redoHomeConfiguration() {
        guard
            shortcutCaptureField == nil,
            !globalShortcutSettingsView
                .hasTransientEditorChanges
        else {
            return
        }

        homeConfigurationEditorSession?
            .redo()
    }

    @objc
    private func saveHomeConfigurationButtonPressed() {
        _ = saveHomeConfiguration()
    }

    @discardableResult
    private func saveHomeConfiguration() -> Bool {
        endShortcutCapture()

        if let validationMessage =
            globalShortcutSettingsView
                .currentValidationMessage
        {
            setStatus(
                validationMessage,
                isError:
                    true
            )

            updateHomeActionControls()
            return false
        }

        guard
            !globalShortcutSettingsView
                .hasTransientEditorChanges
        else {
            setStatus(
                "Complete the shortcut configuration before saving Home.",
                isError:
                    true
            )

            updateHomeActionControls()
            return false
        }

        guard let saveHomeConfigurationHandler else {
            setStatus(
                "The Home configuration could not be saved.",
                isError:
                    true
            )

            return false
        }

        do {
            try saveHomeConfigurationHandler()

            synchronizeHomeDraft(
                forceShortcutReload:
                    true
            )
            setStatus(
                "The Home configuration was saved locally on this Mac.",
                isError:
                    false
            )

            return true
        } catch HomeConfigurationSaveTransactionError
            .profileRollbackFailed
        {
            setStatus(
                "The Home configuration could not be saved, and the previous profile configuration could not be restored. Remapping was not switched. Reopen the app before making further changes.",
                isError:
                    true
            )
        } catch {
            setStatus(
                "The Home configuration could not be saved. The previous stored configuration remains active.",
                isError:
                    true
            )
        }

        updateHomeActionControls()
        return false
    }

    private func discardHomeChanges() {
        homeConfigurationEditorSession?
            .restoreSavedSnapshot()

        synchronizeHomeDraft(
            forceShortcutReload:
                true
        )

        setStatus(
            "The unsaved Home changes were discarded.",
            isError:
                false
        )
    }

    private func setStatus(
        _ message: String,
        isError: Bool
    ) {
        statusLabel.stringValue = message
        statusLabel.textColor =
            isError ? .systemRed : .secondaryLabelColor
    }
}
