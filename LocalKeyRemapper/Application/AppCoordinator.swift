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
    private let rulesStore: UserDefaultsRulesStore
    private let rulesValidator: RemappingRulesValidator
    private let appPreferencesStore: UserDefaultsAppPreferencesStore
    private let appPreferencesController: AppPreferencesController
    private let remappingEngine: RemappingEngine
    private let eventTapManager: EventTapManager
    private let remappingController: RemappingController
    private let globalShortcutManager: GlobalShortcutManager
    private let globalShortcutController: GlobalShortcutController

    private var applicationMenuController: ApplicationMenuController?
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    private var isObservingWorkspaceActivation =
        false

    /// Prevents application shutdown from being stored as a
    /// user-requested disabled state.
    private var isStopping = false

    override init() {
        let permissionService = AccessibilityPermissionService()
        let rulesStore = UserDefaultsRulesStore()
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
            rulesStore: rulesStore,
            rulesValidator: rulesValidator,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager
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

        self.permissionService = permissionService
        self.rulesStore = rulesStore
        self.rulesValidator = rulesValidator
        self.appPreferencesStore = appPreferencesStore
        self.appPreferencesController = appPreferencesController
        self.remappingEngine = remappingEngine
        self.eventTapManager = eventTapManager
        self.remappingController = remappingController
        self.globalShortcutManager = globalShortcutManager
        self.globalShortcutController = globalShortcutController

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
        settingsController().showWindow(nil)
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

        settingsWindowController?
            .prepareForApplicationTermination()
        settingsWindowController = nil

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

        isObservingWorkspaceActivation =
            true
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

        isObservingWorkspaceActivation =
            false
    }

    @objc
    private func workspaceDidActivateApplication(
        _ notification:
            Notification
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
        settingsWindowController?.updateMenuBarIconVisibility(
            showsMenuBarIcon
        )
    }

    private func settingsController() -> SettingsWindowController {
        if let settingsWindowController {
            return settingsWindowController
        }

        let controller = SettingsWindowController(
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
            }
        )

        settingsWindowController = controller
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
        settingsWindowController?.updateRemappingState(
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
        let controller = settingsController()

        if controller.window?.isVisible != true {
            controller.showWindow(nil)
        }

        controller.increaseTextSize()
    }

    private func decreaseTextSize() {
        let controller = settingsController()

        if controller.window?.isVisible != true {
            controller.showWindow(nil)
        }

        controller.decreaseTextSize()
    }

    private func resetTextSize() {
        let controller = settingsController()

        if controller.window?.isVisible != true {
            controller.showWindow(nil)
        }

        controller.resetTextSize()
    }
}
