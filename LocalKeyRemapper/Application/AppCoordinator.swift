//
//  AppCoordinator.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

/// Represents a Home Save operation that cannot start because its shared
/// editor session is unavailable.
nonisolated enum HomeConfigurationSaveError:
    Error,
    Equatable
{
    case editorSessionUnavailable
}

/// Creates and connects the main application components.
@MainActor
final class AppCoordinator: NSObject {
    private let permissionService: AccessibilityPermissionService
    private let profilesStore: UserDefaultsRemappingProfilesStore
    private let rulesValidator: RemappingRulesValidator
    private let appPreferencesStore: UserDefaultsAppPreferencesStore
    private let appPreferencesController: AppPreferencesController
    private let rulesWindowAppPreferencesController:
        RulesWindowAppPreferencesController
    private let remappingEngine: RemappingEngine
    private let eventTapManager: EventTapManager
    private let remappingController: RemappingController
    private let globalShortcutManager: GlobalShortcutManager
    private let globalShortcutController: GlobalShortcutController
    private let homeConfigurationSaveTransaction:
        HomeConfigurationSaveTransaction
    private let ruleEditorSessionRegistry:
        ProfileRuleEditorSessionRegistry

    private var homeConfigurationEditorSession:
        HomeConfigurationEditorSession?

    /// Result waiting for the shared Home session to synchronize its immediate
    /// active-profile identity before notifications are published.
    private var pendingImmediateProfileActivationResult:
        HomeConfigurationSaveTransactionResult?

    private var applicationMenuController: ApplicationMenuController?
    private var statusBarController: StatusBarController?
    private var mainWindowController: MainWindowController?
    private var homeProfileShortcutSheetCoordinator:
        HomeProfileShortcutSheetCoordinator?
    private var remappingRulesWindowController:
        RemappingRulesWindowController?

    /// Stable identity currently displayed by the reusable Rules window.
    private var displayedRulesProfileID:
        UUID?

    private var isObservingWorkspaceActivation = false

    /// Prevents application shutdown from being stored as a
    /// user-requested disabled state.
    private var isStopping = false

    override init() {
        let permissionService =
            AccessibilityPermissionService()

        let profilesConfigurationValidator =
            RemappingProfilesConfigurationValidator()

        let profilesStore =
            UserDefaultsRemappingProfilesStore(
                validator:
                    profilesConfigurationValidator
            )

        let rulesValidator =
            RemappingRulesValidator()

        let appPreferencesStore =
            UserDefaultsAppPreferencesStore()

        let appPreferencesController =
            AppPreferencesController(
                store:
                    appPreferencesStore
            )

        let rulesWindowAppPreferencesController =
            RulesWindowAppPreferencesController(
                baseController:
                    appPreferencesController,
                profilesStore:
                    profilesStore
            )

        let persistedEffectiveShortcutConfigurationProvider =
            PersistedEffectiveRemappingShortcutConfigurationProvider(
                profilesStore:
                    profilesStore,
                defaultConfigurationProvider: {
                    appPreferencesController
                        .preferences
                        .shortcutConfiguration
                }
            )

        let remappingEngine =
            RemappingEngine()

        let eventTapManager =
            EventTapManager(
                remappingEngine:
                    remappingEngine
            )

        let remappingController =
            RemappingController(
                permissionService:
                    permissionService,
                profilesStore:
                    profilesStore,
                rulesValidator:
                    rulesValidator,
                remappingEngine:
                    remappingEngine,
                eventTapManager:
                    eventTapManager,
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

        let globalShortcutManager =
            GlobalShortcutManager()

        let globalShortcutController =
            GlobalShortcutController(
                shortcutManager:
                    globalShortcutManager,
                appPreferencesController:
                    appPreferencesController,
                remappingEngine:
                    remappingEngine,
                configuredRulesProvider: {
                    let configuration =
                        try profilesStore
                            .loadConfiguration()

                    guard
                        let activeProfile =
                            configuration.activeProfile
                    else {
                        throw RemappingProfilesConfigurationValidationError
                            .missingActiveProfile(
                                configuration.activeProfileID
                            )
                    }

                    return activeProfile.rules
                },
                effectiveConfigurationProvider: {
                    try persistedEffectiveShortcutConfigurationProvider
                        .configuration()
                },
                rulesEditorShortcutConfigurationProvider: {
                    rulesWindowAppPreferencesController
                        .preferences
                        .shortcutConfiguration
                },
                actionHandler: {
                    [weak remappingController] action in

                    guard
                        let remappingController
                    else {
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

        let homeConfigurationSaveTransaction =
            HomeConfigurationSaveTransaction(
                profilesStore:
                    profilesStore,
                profilesValidator:
                    profilesConfigurationValidator,
                rulesValidator:
                    rulesValidator,
                appPreferencesController:
                    appPreferencesController,
                globalShortcutController:
                    globalShortcutController,
                activeRulesApplyHandler: {
                    rules in

                    remappingEngine.replaceRules(
                        rules
                    )
                }
            )

        let ruleEditorSessionRegistry =
            ProfileRuleEditorSessionRegistry()

        self.permissionService =
            permissionService

        self.profilesStore =
            profilesStore

        self.rulesValidator =
            rulesValidator

        self.appPreferencesStore =
            appPreferencesStore

        self.appPreferencesController =
            appPreferencesController

        self.rulesWindowAppPreferencesController =
            rulesWindowAppPreferencesController

        self.remappingEngine =
            remappingEngine

        self.eventTapManager =
            eventTapManager

        self.remappingController =
            remappingController

        self.globalShortcutManager =
            globalShortcutManager

        self.globalShortcutController =
            globalShortcutController

        self.homeConfigurationSaveTransaction =
            homeConfigurationSaveTransaction

        self.ruleEditorSessionRegistry =
            ruleEditorSessionRegistry

        super.init()
    }

    /// Starts the application user interface and registers the effective global
    /// shortcuts belonging to the active persisted profile.
    func start() {
        isStopping =
            false

        loadAppPreferences()
        initializeHomeConfigurationEditorSession()
        configureRulesWindowShortcutScope()
        configureRemappingStateObservation()
        startObservingWorkspaceActivation()

        applicationMenuController =
            ApplicationMenuController(
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

                    guard
                        let self
                    else {
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
        remappingRulesWindowController?
            .endActiveCapture()

        getOrCreateMainWindowController()
            .showWindow(
                nil
            )
    }

    /// Shows the Rules window for the currently active profile.
    func showRemappingRulesWindow() {
        do {
            let profilesConfiguration =
                try currentHomeProfilesConfiguration()

            showRemappingRulesWindow(
                for:
                    profilesConfiguration.activeProfileID,
                in:
                    profilesConfiguration
            )
        } catch {
            // A storage failure must not crash or partially open the editor.
        }
    }

    /// Shows the one reusable Rules window for a specific profile UUID.
    func showRemappingRulesWindow(
        for profileID:
            UUID
    ) {
        do {
            let profilesConfiguration =
                try currentHomeProfilesConfiguration()

            showRemappingRulesWindow(
                for:
                    profileID,
                in:
                    profilesConfiguration
            )
        } catch {
            // A storage failure must not crash or partially open the editor.
        }
    }

    private func showRemappingRulesWindow(
        for profileID:
            UUID,
        in configuration:
            RemappingProfilesConfiguration
    ) {
        guard
            let profile =
                configuration.profile(
                    id:
                        profileID
                )
        else {
            return
        }

        mainWindowController?
            .endActiveCapture()

        let ruleEditorSession =
            ruleEditorSessionRegistry
                .session(
                    for:
                        profileID
                )

        if !ruleEditorSession.isInitialized {
            ruleEditorSession.initialize(
                with:
                    profile.rules
            )
        }

        rulesWindowAppPreferencesController.profileID =
            profileID

        let controller =
            getOrCreateRemappingRulesWindowController(
                profile:
                    profile,
                ruleEditorSession:
                    ruleEditorSession
            )

        displayedRulesProfileID =
            profileID

        controller.showWindow(
            nil
        )
    }

    /// Checks whether Accessibility permission was granted
    /// after the application becomes active again.
    func applicationDidBecomeActive() {
        remappingController
            .refreshAccessibilityPermission()
    }

    /// Stops active system components before
    /// the application terminates.
    func stop() {
        isStopping =
            true

        stopObservingWorkspaceActivation()

        homeProfileShortcutSheetCoordinator?
            .stop()

        homeProfileShortcutSheetCoordinator =
            nil

        mainWindowController?
            .prepareForApplicationTermination()

        remappingRulesWindowController?
            .prepareForApplicationTermination()

        homeConfigurationEditorSession?
            .onChange =
                nil

        homeConfigurationEditorSession?
            .onActiveProfileChangeRequested =
                nil

        homeConfigurationEditorSession?
            .onImmediateActiveProfileChangeCommitted =
                nil

        pendingImmediateProfileActivationResult =
            nil

        homeConfigurationEditorSession =
            nil

        mainWindowController =
            nil

        remappingRulesWindowController =
            nil

        displayedRulesProfileID =
            nil

        rulesWindowAppPreferencesController.profileID =
            nil

        rulesWindowAppPreferencesController
            .homeProfilesConfigurationProvider =
                nil

        rulesWindowAppPreferencesController
            .homeShortcutConfigurationProvider =
                nil

        ruleEditorSessionRegistry
            .removeAllSessions()

        globalShortcutController.stop()
        remappingController.disable()

        remappingController.onStateChange =
            nil

        statusBarController?
            .stop()

        statusBarController =
            nil

        applicationMenuController =
            nil
    }

    private func configureRemappingStateObservation() {
        remappingController.onStateChange = {
            [weak self] state in

            self?.handleRemappingStateChange(
                state
            )
        }
    }

    /// Rechecks Accessibility only when macOS activates an application.
    ///
    /// This is event-driven. It does not use a repeating timer or polling.
    private func startObservingWorkspaceActivation() {
        guard
            !isObservingWorkspaceActivation
        else {
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
        guard
            isObservingWorkspaceActivation
        else {
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

    private func makeStatusBarController()
        -> StatusBarController
    {
        StatusBarController(
            remappingController:
                remappingController,
            accessibilitySettingsOpener:
                permissionService,
            refreshRemappingStateHandler: {
                [weak self] in

                self?.remappingController
                    .refreshAccessibilityPermission()
            },
            profilesSnapshotProvider: {
                [weak self] in

                guard
                    let self
                else {
                    throw HomeConfigurationSaveError
                        .editorSessionUnavailable
                }

                return try self
                    .statusPopoverProfilesSnapshot()
            },
            activeProfileSelectionHandler: {
                [weak self] profileID in

                guard
                    let self
                else {
                    throw HomeConfigurationSaveError
                        .editorSessionUnavailable
                }

                try self
                    .activateProfileFromInterface(
                        profileID
                    )
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
        _ showsMenuBarIcon:
            Bool
    ) throws {
        try appPreferencesController
            .setShowsMenuBarIcon(
                showsMenuBarIcon
            )

        applyMenuBarIconVisibility(
            showsMenuBarIcon
        )
    }

    private func applyMenuBarIconVisibility(
        _ showsMenuBarIcon:
            Bool
    ) {
        if showsMenuBarIcon {
            if statusBarController == nil {
                statusBarController =
                    makeStatusBarController()
            }

            statusBarController?
                .update(
                    for:
                        remappingController.state
                )
        } else {
            statusBarController?
                .stop()

            statusBarController =
                nil
        }

        applicationMenuController?
            .updateMenuBarIconVisibility(
                showsMenuBarIcon
            )

        mainWindowController?
            .updateMenuBarIconVisibility(
                showsMenuBarIcon
            )
    }

    private func getOrCreateMainWindowController()
        -> MainWindowController
    {
        if let mainWindowController {
            return mainWindowController
        }

        let controller =
            MainWindowController(
                remappingController:
                    remappingController,
                appPreferencesController:
                    appPreferencesController,
                globalShortcutController:
                    globalShortcutController,
                homeConfigurationEditorSession:
                    homeConfigurationEditorSession,
                saveHomeConfigurationHandler: {
                    [weak self] in

                    guard
                        let self
                    else {
                        throw HomeConfigurationSaveError
                            .editorSessionUnavailable
                    }

                    try self.saveHomeConfiguration()
                },
                profilesConfigurationProvider: {
                    [weak self] in

                    guard
                        let self
                    else {
                        throw HomeConfigurationSaveError
                            .editorSessionUnavailable
                    }

                    return try self.profilesStore
                        .loadConfiguration()
                },
                menuBarVisibilityChangeHandler: {
                    [weak self] showsMenuBarIcon in

                    guard
                        let self
                    else {
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
                openRemappingRulesForProfileHandler: {
                    [weak self] profileID in

                    self?.showRemappingRulesWindow(
                        for:
                            profileID
                    )
                },
                profileNameChangeHandler: {
                    [weak self] profile,
                    previousName in

                    self?.refreshOpenRulesWindowProfileName(
                        profile,
                        previousName:
                            previousName
                    )
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
                    InterfaceTextScalePreference
                        .currentScale
            )

        mainWindowController =
            controller

        if let homeConfigurationEditorSession {
            let profileShortcutCoordinator =
                HomeProfileShortcutSheetCoordinator(
                    mainWindowController:
                        controller,
                    remappingController:
                        remappingController,
                    globalShortcutController:
                        globalShortcutController,
                    homeConfigurationEditorSession:
                        homeConfigurationEditorSession,
                    profilesConfigurationProvider: {
                        [weak self] in

                        guard
                            let self
                        else {
                            throw HomeConfigurationSaveError
                                .editorSessionUnavailable
                        }

                        return try self.profilesStore
                            .loadConfiguration()
                    }
                )

            profileShortcutCoordinator.start()

            homeProfileShortcutSheetCoordinator =
                profileShortcutCoordinator
        }

        return controller
    }

    private func refreshOpenRulesWindowProfileName(
        _ profile:
            RemappingProfile,
        previousName:
            String
    ) {
        _ =
            previousName

        guard
            let remappingRulesWindowController,
            displayedRulesProfileID
                == profile.id
        else {
            return
        }

        let ruleEditorSession =
            ruleEditorSessionRegistry
                .session(
                    for:
                        profile.id
                )

        remappingRulesWindowController.bind(
            to:
                profile,
            ruleEditorSession:
                ruleEditorSession
        )
    }

    private func getOrCreateRemappingRulesWindowController(
        profile:
            RemappingProfile,
        ruleEditorSession:
            RemappingRuleEditorSession
    ) -> RemappingRulesWindowController {
        if let remappingRulesWindowController {
            remappingRulesWindowController.bind(
                to:
                    profile,
                ruleEditorSession:
                    ruleEditorSession
            )

            return remappingRulesWindowController
        }

        let controller =
            RemappingRulesWindowController(
                remappingController:
                    remappingController,
                appPreferencesController:
                    rulesWindowAppPreferencesController,
                globalShortcutController:
                    globalShortcutController,
                profileID:
                    profile.id,
                profileName:
                    profile.name,
                ruleEditorSession:
                    ruleEditorSession,
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
                    InterfaceTextScalePreference
                        .currentScale
            )

        remappingRulesWindowController =
            controller

        return controller
    }

    /// Connects Rules-related validation to the latest Home draft.
    ///
    /// Rules and Custom Exceptions evaluate the profile currently proposed as
    /// active against its effective draft shortcut configuration. This includes
    /// the proposed Default and the profile's optional override. Inactive draft
    /// profiles continue to see shortcuts as disabled.
    private func configureRulesWindowShortcutScope() {
        rulesWindowAppPreferencesController
            .homeProfilesConfigurationProvider = {
                [weak self] in

                self?
                    .homeConfigurationEditorSession?
                    .draft
                    .profilesConfiguration
            }

        rulesWindowAppPreferencesController
            .homeShortcutConfigurationProvider = {
                [weak self] in

                self?
                    .homeConfigurationEditorSession?
                    .draft
                    .shortcutConfiguration
            }
    }

    /// Creates the single Home editor session owned for this app run.
    ///
    /// The session starts from the persisted profiles configuration and the
    /// application preferences loaded immediately before this operation.
    /// Nothing is written while the draft is being created.
    private func initializeHomeConfigurationEditorSession() {
        do {
            let profilesConfiguration =
                try profilesStore
                    .loadConfiguration()

            let preferences =
                appPreferencesController
                    .preferences

            let editorSession =
                HomeConfigurationEditorSession(
                    snapshot:
                        HomeConfigurationSnapshot(
                            profilesConfiguration:
                                profilesConfiguration,
                            launchBehavior:
                                preferences.launchBehavior,
                            shortcutConfiguration:
                                preferences
                                    .shortcutConfiguration
                        )
                )

            editorSession
                .onActiveProfileChangeRequested = {
                    [weak self] profileID in

                    guard
                        let self
                    else {
                        throw HomeConfigurationSaveError
                            .editorSessionUnavailable
                    }

                    self
                        .pendingImmediateProfileActivationResult =
                            try self
                                .activatePersistedProfile(
                                    profileID
                                )
                }

            editorSession
                .onImmediateActiveProfileChangeCommitted = {
                    [weak self] in

                    self?
                        .publishPendingImmediateProfileActivationChanges()
                }

            homeConfigurationEditorSession =
                editorSession
        } catch {
            // The application can still launch using its existing controls.
            // A storage failure must not create a partial Home draft.
            homeConfigurationEditorSession =
                nil
        }
    }

    /// Commits profiles, the active profile, launch behavior, and shortcuts as
    /// one coordinated Home transaction.
    ///
    /// Profile metadata is merged with the latest independently saved Rules
    /// content before persistence. Runtime rules and committed-deletion cleanup
    /// happen only after every storage and shortcut-registration step succeeds.
    private func saveHomeConfiguration()
        throws
    {
        guard
            let homeConfigurationEditorSession
        else {
            throw HomeConfigurationSaveError
                .editorSessionUnavailable
        }

        let result =
            try homeConfigurationSaveTransaction
                .commit(
                    homeConfigurationEditorSession
                        .draft
                )

        let committedDeletionIDs =
            homeConfigurationEditorSession
                .markCurrentDraftAsSaved(
                    result.committedSnapshot
                )

        closeRulesWindowIfDisplayingDeletedProfile(
            committedDeletionIDs
        )

        for profileID in committedDeletionIDs {
            ruleEditorSessionRegistry
                .removeSession(
                    for:
                        profileID
                )
        }

        if result.shortcutConfigurationChanged
            || result.effectiveShortcutConfigurationChanged
        {
            NotificationCenter.default.post(
                name:
                    AppConfigurationNotification
                        .globalShortcutConfigurationDidChange,
                object:
                    nil
            )
        }

        if result.profilesChanged {
            NotificationCenter.default.post(
                name:
                    AppConfigurationNotification
                        .remappingRulesDidChange,
                object:
                    nil
            )
        }
    }

    /// Closes the reusable Rules window only when its profile was permanently
    /// removed by the successful Home Save.
    private func closeRulesWindowIfDisplayingDeletedProfile(
        _ deletedProfileIDs:
            Set<UUID>
    ) {
        guard
            let displayedRulesProfileID,
            deletedProfileIDs.contains(
                displayedRulesProfileID
            )
        else {
            return
        }

        remappingRulesWindowController?
            .close()

        self.displayedRulesProfileID =
            nil
    }

    /// Returns the editable Home profiles when a session exists.
    ///
    /// The storage fallback preserves Rules-window behavior in tests and in
    /// defensive call paths that open Rules before the normal start sequence.
    private func currentHomeProfilesConfiguration()
        throws -> RemappingProfilesConfiguration
    {
        if let homeConfigurationEditorSession {
            return homeConfigurationEditorSession
                .draft
                .profilesConfiguration
        }

        return try profilesStore
            .loadConfiguration()
    }

    /// Uses the shared Home session when available so Home and the menu-bar
    /// popover always follow the same immediate activation path.
    private func activateProfileFromInterface(
        _ profileID:
            UUID
    ) throws {
        if let homeConfigurationEditorSession {
            try homeConfigurationEditorSession
                .setActiveProfile(
                    profileID
                )
            return
        }

        let result =
            try activatePersistedProfile(
                profileID
            )

        publishImmediateProfileActivationChanges(
            result
        )
    }

    /// Activates exactly one persisted profile without saving unrelated Home
    /// draft edits.
    ///
    /// The existing Home transaction supplies validation, shortcut
    /// registration, persistence rollback, and final runtime-rule replacement.
    /// Its input is built from persisted state, so pending profile names,
    /// additions, deletions, launch behavior, and shortcut edits are untouched.
    private func activatePersistedProfile(
        _ profileID:
            UUID
    ) throws -> HomeConfigurationSaveTransactionResult {
        let persistedProfilesConfiguration =
            try profilesStore
                .loadConfiguration()

        guard
            persistedProfilesConfiguration
                .profile(
                    id:
                        profileID
                ) != nil
        else {
            throw RemappingProfileRulesAccessError
                .profileNotFound(
                    profileID
                )
        }

        guard
            persistedProfilesConfiguration
                .activeProfileID
                != profileID
        else {
            return HomeConfigurationSaveTransactionResult(
                committedSnapshot:
                    HomeConfigurationSnapshot(
                        profilesConfiguration:
                            persistedProfilesConfiguration,
                        launchBehavior:
                            appPreferencesController
                                .preferences
                                .launchBehavior,
                        shortcutConfiguration:
                            appPreferencesController
                                .preferences
                                .shortcutConfiguration
                    ),
                previousProfilesConfiguration:
                    persistedProfilesConfiguration,
                previousShortcutConfiguration:
                    appPreferencesController
                        .preferences
                        .shortcutConfiguration
            )
        }

        var proposedProfilesConfiguration =
            persistedProfilesConfiguration

        proposedProfilesConfiguration
            .activeProfileID =
                profileID

        let preferences =
            appPreferencesController
                .preferences

        return try homeConfigurationSaveTransaction
            .commit(
                HomeConfigurationSnapshot(
                    profilesConfiguration:
                        proposedProfilesConfiguration,
                    launchBehavior:
                        preferences.launchBehavior,
                    shortcutConfiguration:
                        preferences
                            .shortcutConfiguration
                )
            )
    }

    /// Completes the two-stage Home activation after the editor session has
    /// synchronized its saved baseline and draft.
    private func publishPendingImmediateProfileActivationChanges() {
        guard
            let result =
                pendingImmediateProfileActivationResult
        else {
            return
        }

        pendingImmediateProfileActivationResult =
            nil

        publishImmediateProfileActivationChanges(
            result
        )
    }

    /// Publishes changes only after the shared Home session has synchronized
    /// its active UUID, ensuring Rules and Home validation observe one state.
    private func publishImmediateProfileActivationChanges(
        _ result:
            HomeConfigurationSaveTransactionResult
    ) {
        if result.shortcutConfigurationChanged
            || result.effectiveShortcutConfigurationChanged
        {
            NotificationCenter.default.post(
                name:
                    AppConfigurationNotification
                        .globalShortcutConfigurationDidChange,
                object:
                    nil
            )
        }

        if result.profilesChanged {
            NotificationCenter.default.post(
                name:
                    AppConfigurationNotification
                        .remappingRulesDidChange,
                object:
                    nil
            )
        }

        statusBarController?
            .refreshProfiles()
    }

    /// Builds the operational popover from persisted profiles that still
    /// exist in the current Home draft.
    ///
    /// Draft-only additions are excluded because they cannot run yet. Profiles
    /// pending deletion are also hidden so the menu bar never reactivates an
    /// item the user has already removed from the visible Home draft. Persisted
    /// names remain authoritative until Home Save succeeds.
    private func statusPopoverProfilesSnapshot()
        throws -> StatusPopoverProfilesSnapshot
    {
        let persistedConfiguration =
            try profilesStore
                .loadConfiguration()

        let visiblePersistedProfileIDs:
            Set<UUID>

        if let homeConfigurationEditorSession {
            visiblePersistedProfileIDs =
                Set(
                    homeConfigurationEditorSession
                        .draft
                        .profiles
                        .map(
                            \.id
                        )
                )
        } else {
            visiblePersistedProfileIDs =
                Set(
                    persistedConfiguration
                        .profiles
                        .map(
                            \.id
                        )
                )
        }

        return StatusPopoverProfilesSnapshot(
            profiles:
                persistedConfiguration
                    .profiles
                    .filter {
                        visiblePersistedProfileIDs
                            .contains(
                                $0.id
                            )
                    }
                    .map {
                        profile in

                        StatusPopoverProfileItem(
                            id:
                                profile.id,
                            name:
                                profile.name,
                            isActivatable:
                                true
                        )
                    },
            activeProfileID:
                persistedConfiguration
                    .activeProfileID
        )
    }

    private func loadAppPreferences() {
        do {
            try appPreferencesController
                .loadPreferences()
        } catch {
            // Safe in-memory defaults remain active.
        }
    }

    private func startGlobalShortcuts() {
        do {
            try globalShortcutController
                .start()
        } catch {
            // A shortcut conflict, invalid configuration, profile-loading
            // failure, or registration failure must not prevent the application
            // from launching.
            //
            // No keyboard input or error details are logged.
        }
    }

    private func enableRemappingAtLaunchIfRequested() {
        guard
            appPreferencesController
                .preferences
                .shouldEnableRemappingAtLaunch
        else {
            return
        }

        remappingController.enable()
    }

    private func handleRemappingStateChange(
        _ state:
            RemappingState
    ) {
        guard
            !isStopping
        else {
            return
        }

        statusBarController?
            .update(
                for:
                    state
            )

        mainWindowController?
            .updateRemappingState(
                state
            )

        let isEnabled:
            Bool

        switch state {
        case .enabled:
            isEnabled =
                true

        case .disabled:
            isEnabled =
                false

        case .enabling,
             .permissionRequired,
             .failed:
            return
        }

        do {
            try appPreferencesController
                .setLastRemappingEnabled(
                    isEnabled
                )
        } catch {
            // A preference write failure must not interrupt remapping.
        }
    }

    private func increaseTextSize() {
        ensureAnApplicationWindowIsVisible()

        applyTextScaleToExistingWindows(
            InterfaceTextScalePreference
                .increase()
        )
    }

    private func decreaseTextSize() {
        ensureAnApplicationWindowIsVisible()

        applyTextScaleToExistingWindows(
            InterfaceTextScalePreference
                .decrease()
        )
    }

    private func resetTextSize() {
        ensureAnApplicationWindowIsVisible()

        applyTextScaleToExistingWindows(
            InterfaceTextScalePreference
                .reset()
        )
    }

    private func ensureAnApplicationWindowIsVisible() {
        let mainIsVisible =
            mainWindowController?
                .window?
                .isVisible
                == true

        let rulesAreVisible =
            remappingRulesWindowController?
                .window?
                .isVisible
                == true

        guard
            !mainIsVisible,
            !rulesAreVisible
        else {
            return
        }

        showMainWindow()
    }

    private func applyTextScaleToExistingWindows(
        _ scale:
            CGFloat
    ) {
        mainWindowController?
            .applyTextScale(
                scale
            )

        homeProfileShortcutSheetCoordinator?
            .applyTextScale(
                scale
            )

        remappingRulesWindowController?
            .applyTextScale(
                scale
            )
    }
}
