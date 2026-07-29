//
//  AppCoordinator.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

/// Creates and connects the main application components.
@MainActor
final class AppCoordinator: NSObject {
    private let permissionService: AccessibilityPermissionService
    private let profilesStore: UserDefaultsRemappingProfilesStore
    private let rulesValidator: RemappingRulesValidator
    private let appPreferencesStore: UserDefaultsAppPreferencesStore
    private let appPreferencesController: AppPreferencesController
    private let remappingEngine: RemappingEngine
    private let eventTapManager: EventTapManager
    private let remappingController: RemappingController
    private let globalShortcutManager: GlobalShortcutManager
    private let globalShortcutController: GlobalShortcutController
    private let ruleEditorSession: RemappingRuleEditorSession

    private var applicationMenuController: ApplicationMenuController?
    private var statusBarController: StatusBarController?
    private var mainWindowController: MainWindowController?
    private var remappingRulesWindowController:
        RemappingRulesWindowController?

    private var isObservingWorkspaceActivation = false

    /// Prevents application shutdown from being stored as a
    /// user-requested disabled state.
    private var isStopping = false

    override init() {
        let permissionService = AccessibilityPermissionService()
        let profilesStore = UserDefaultsRemappingProfilesStore()
        let rulesValidator = RemappingRulesValidator()
        let appPreferencesStore = UserDefaultsAppPreferencesStore()
        let appPreferencesController = AppPreferencesController(
            store: appPreferencesStore
        )
        let remappingEngine = RemappingEngine()
        let eventTapManager = EventTapManager(
            remappingEngine: remappingEngine
        )
        let remappingController = RemappingController(
            permissionService: permissionService,
            profilesStore: profilesStore,
            rulesValidator: rulesValidator,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager,
            shortcutConfigurationProvider: {
                appPreferencesController
                    .preferences
                    .shortcutConfiguration
            }
        )

        eventTapManager.onInterruption = {
            [weak remappingController] in

            remappingController?
                .handleEventTapInterruption()
        }

        let globalShortcutManager = GlobalShortcutManager()
        let globalShortcutController = GlobalShortcutController(
            shortcutManager: globalShortcutManager,
            appPreferencesController: appPreferencesController,
            remappingEngine: remappingEngine,
            configuredRulesProvider: {
                let configuration =
                    try profilesStore
                        .loadConfiguration()

                return configuration
                    .profiles
                    .flatMap {
                        $0.rules
                    }
            },
            actionHandler: {
                [weak remappingController] action in

                guard let remappingController else {
                    return
                }

                switch action {
                case .toggle:
                    remappingController.toggle()

                case .enable:
                    remappingController.enable()

                case .disable:
                    remappingController.disable()
                }
            }
        )
        let ruleEditorSession = RemappingRuleEditorSession()

        self.permissionService = permissionService
        self.profilesStore = profilesStore
        self.rulesValidator = rulesValidator
        self.appPreferencesStore = appPreferencesStore
        self.appPreferencesController = appPreferencesController
        self.remappingEngine = remappingEngine
        self.eventTapManager = eventTapManager
        self.remappingController = remappingController
        self.globalShortcutManager = globalShortcutManager
        self.globalShortcutController = globalShortcutController
        self.ruleEditorSession = ruleEditorSession

        super.init()
    }

    /// Starts the application user interface and registers
    /// the configured global shortcuts.
    func start() {
        isStopping = false

        loadAppPreferences()
        configureRemappingStateObservation()
        startObservingWorkspaceActivation()

        applicationMenuController = ApplicationMenuController(
            increaseTextSizeHandler: {
                [weak self] in

                self?.increaseTextSize()
            },
            decreaseTextSizeHandler: {
                [weak self] in

                self?.decreaseTextSize()
            },
            resetTextSizeHandler: {
                [weak self] in

                self?.resetTextSize()
            },
            showsMenuBarIcon:
                appPreferencesController
                    .preferences
                    .showsMenuBarIcon,
            menuBarVisibilityChangeHandler: {
                [weak self] showsMenuBarIcon in

                guard let self else {
                    return
                }

                try self.setMenuBarIconVisible(
                    showsMenuBarIcon
                )
            }
        )

        applyMenuBarIconVisibility(
            appPreferencesController
                .preferences
                .showsMenuBarIcon
        )

        showMainWindow()
        startGlobalShortcuts()
        enableRemappingAtLaunchIfRequested()
    }

    /// Shows the application's main window.
    ///
    /// The same operation is used at launch, from the menu bar,
    /// and when the user reopens the application from the Dock.
    func showMainWindow() {
        remappingRulesWindowController?.endActiveCapture()
        getOrCreateMainWindowController().showWindow(nil)
    }

    /// Shows the one reusable remapping-rules window.
    ///
    /// Repeated requests bring the existing window to the front instead of
    /// creating additional editors or additional rule sessions.
    func showRemappingRulesWindow() {
        mainWindowController?.endActiveCapture()
        getOrCreateRemappingRulesWindowController().showWindow(nil)
    }

    /// Checks whether Accessibility permission was granted
    /// after the application becomes active again.
    func applicationDidBecomeActive() {
        remappingController.refreshAccessibilityPermission()
    }

    /// Stops active system components before
    /// the application terminates.
    func stop() {
        isStopping = true

        stopObservingWorkspaceActivation()

        mainWindowController?
            .prepareForApplicationTermination()
        remappingRulesWindowController?
            .prepareForApplicationTermination()

        mainWindowController = nil
        remappingRulesWindowController = nil

        globalShortcutController.stop()
        remappingController.disable()
        remappingController.onStateChange = nil

        statusBarController?.stop()
        statusBarController = nil
        applicationMenuController = nil
    }

    private func configureRemappingStateObservation() {
        remappingController.onStateChange = {
            [weak self] state in

            self?.handleRemappingStateChange(state)
        }
    }

    /// Rechecks Accessibility only when macOS activates an application.
    ///
    /// This is event-driven. It does not use a repeating timer or polling.
    private func startObservingWorkspaceActivation() {
        guard !isObservingWorkspaceActivation else {
            return
        }

        NSWorkspace.shared
            .notificationCenter
            .addObserver(
                self,
                selector:
                    #selector(
                        workspaceDidActivateApplication
                    ),
                name:
                    NSWorkspace
                        .didActivateApplicationNotification,
                object:
                    nil
            )

        isObservingWorkspaceActivation = true
    }

    private func stopObservingWorkspaceActivation() {
        guard isObservingWorkspaceActivation else {
            return
        }

        NSWorkspace.shared
            .notificationCenter
            .removeObserver(
                self,
                name:
                    NSWorkspace
                        .didActivateApplicationNotification,
                object:
                    nil
            )

        isObservingWorkspaceActivation = false
    }

    @objc
    private func workspaceDidActivateApplication(
        _ notification: Notification
    ) {
        remappingController
            .refreshAccessibilityPermission()
    }

    private func makeStatusBarController() -> StatusBarController {
        StatusBarController(
            remappingController: remappingController,
            accessibilitySettingsOpener: permissionService,
            refreshRemappingStateHandler: {
                [weak self] in

                self?.remappingController
                    .refreshAccessibilityPermission()
            },
            openSettingsHandler: {
                [weak self] in

                self?.showMainWindow()
            },
            increaseTextSizeHandler: {
                [weak self] in

                self?.increaseTextSize()
            },
            decreaseTextSizeHandler: {
                [weak self] in

                self?.decreaseTextSize()
            },
            resetTextSizeHandler: {
                [weak self] in

                self?.resetTextSize()
            }
        )
    }

    private func setMenuBarIconVisible(
        _ showsMenuBarIcon: Bool
    ) throws {
        try appPreferencesController.setShowsMenuBarIcon(
            showsMenuBarIcon
        )
        applyMenuBarIconVisibility(
            showsMenuBarIcon
        )
    }

    private func applyMenuBarIconVisibility(
        _ showsMenuBarIcon: Bool
    ) {
        if showsMenuBarIcon {
            if statusBarController == nil {
                statusBarController = makeStatusBarController()
            }

            statusBarController?.update(
                for: remappingController.state
            )
        } else {
            statusBarController?.stop()
            statusBarController = nil
        }

        applicationMenuController?.updateMenuBarIconVisibility(
            showsMenuBarIcon
        )
        mainWindowController?.updateMenuBarIconVisibility(
            showsMenuBarIcon
        )
    }

    private func getOrCreateMainWindowController() ->
        MainWindowController
    {
        if let mainWindowController {
            return mainWindowController
        }

        let controller = MainWindowController(
            remappingController: remappingController,
            appPreferencesController: appPreferencesController,
            globalShortcutController: globalShortcutController,
            menuBarVisibilityChangeHandler: {
                [weak self] showsMenuBarIcon in

                guard let self else {
                    return
                }

                try self.setMenuBarIconVisible(
                    showsMenuBarIcon
                )
            },
            openAccessibilitySettingsHandler: {
                [weak self] in

                self?.permissionService
                    .openAccessibilitySettings()
            },
            openRemappingRulesHandler: {
                [weak self] in

                self?.showRemappingRulesWindow()
            },
            increaseTextSizeHandler: {
                [weak self] in

                self?.increaseTextSize()
            },
            decreaseTextSizeHandler: {
                [weak self] in

                self?.decreaseTextSize()
            },
            resetTextSizeHandler: {
                [weak self] in

                self?.resetTextSize()
            },
            textScale:
                InterfaceTextScalePreference.currentScale
        )

        mainWindowController = controller
        return controller
    }

    private func getOrCreateRemappingRulesWindowController() ->
        RemappingRulesWindowController
    {
        if let remappingRulesWindowController {
            return remappingRulesWindowController
        }

        let controller = RemappingRulesWindowController(
            remappingController: remappingController,
            appPreferencesController: appPreferencesController,
            globalShortcutController: globalShortcutController,
            ruleEditorSession: ruleEditorSession,
            increaseTextSizeHandler: {
                [weak self] in

                self?.increaseTextSize()
            },
            decreaseTextSizeHandler: {
                [weak self] in

                self?.decreaseTextSize()
            },
            resetTextSizeHandler: {
                [weak self] in

                self?.resetTextSize()
            },
            textScale:
                InterfaceTextScalePreference.currentScale
        )

        remappingRulesWindowController = controller
        return controller
    }

    private func loadAppPreferences() {
        do {
            try appPreferencesController.loadPreferences()
        } catch {
            // Safe in-memory defaults remain active.
        }
    }

    private func startGlobalShortcuts() {
        do {
            try globalShortcutController.start()
        } catch {
            // A shortcut conflict, invalid configuration, or registration
            // failure must not prevent the application from launching.
            //
            // No keyboard input or error details are logged.
        }
    }

    private func enableRemappingAtLaunchIfRequested() {
        guard appPreferencesController
            .preferences
            .shouldEnableRemappingAtLaunch else {
            return
        }

        remappingController.enable()
    }

    private func handleRemappingStateChange(
        _ state: RemappingState
    ) {
        guard !isStopping else {
            return
        }

        statusBarController?.update(
            for: state
        )
        mainWindowController?.updateRemappingState(
            state
        )

        let isEnabled: Bool

        switch state {
        case .enabled:
            isEnabled = true

        case .disabled:
            isEnabled = false

        case .enabling,
             .permissionRequired,
             .failed:
            return
        }

        do {
            try appPreferencesController.setLastRemappingEnabled(
                isEnabled
            )
        } catch {
            // A preference write failure must not interrupt remapping.
        }
    }

    private func increaseTextSize() {
        ensureAnApplicationWindowIsVisible()
        applyTextScaleToExistingWindows(
            InterfaceTextScalePreference.increase()
        )
    }

    private func decreaseTextSize() {
        ensureAnApplicationWindowIsVisible()
        applyTextScaleToExistingWindows(
            InterfaceTextScalePreference.decrease()
        )
    }

    private func resetTextSize() {
        ensureAnApplicationWindowIsVisible()
        applyTextScaleToExistingWindows(
            InterfaceTextScalePreference.reset()
        )
    }

    private func ensureAnApplicationWindowIsVisible() {
        let mainIsVisible =
            mainWindowController?.window?.isVisible == true
        let rulesAreVisible =
            remappingRulesWindowController?.window?.isVisible == true

        guard !mainIsVisible && !rulesAreVisible else {
            return
        }

        showMainWindow()
    }

    private func applyTextScaleToExistingWindows(
        _ scale: CGFloat
    ) {
        mainWindowController?.applyTextScale(
            scale
        )
        remappingRulesWindowController?.applyTextScale(
            scale
        )
    }
}
