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

/// Describes unsaved or unfinished editing work found before normal Quit.
///
/// The value contains no key input and is never persisted or logged. It is
/// assembled only when macOS asks whether the application may terminate.
nonisolated struct ApplicationUnsavedChangesSummary:
    Equatable
{
    let hasHomeChanges:
        Bool

    let unsavedRuleProfileNames:
        [String]

    let hasOpenExceptionsEditor:
        Bool

    var hasChanges:
        Bool
    {
        hasHomeChanges
            || !unsavedRuleProfileNames
                .isEmpty
            || hasOpenExceptionsEditor
    }

    var informativeText:
        String
    {
        var components:
            [String] = []

        if hasHomeChanges {
            components.append(
                "unsaved Home changes"
            )
        }

        if unsavedRuleProfileNames.count == 1,
           let profileName =
                unsavedRuleProfileNames
                    .first
        {
            components.append(
                "unsaved remapping rules in “\(profileName)”"
            )
        } else if
            !unsavedRuleProfileNames
                .isEmpty
        {
            components.append(
                "unsaved remapping rules in \(unsavedRuleProfileNames.count) profiles"
            )
        }

        if hasOpenExceptionsEditor {
            components.append(
                "an unfinished Custom Exceptions editor"
            )
        }

        let workDescription =
            Self.joinedDescription(
                components
            )

        return "LocalKeyRemapper has \(workDescription). Quitting without saving will discard this work and clear the session-only Undo and Redo history."
    }

    private static func joinedDescription(
        _ components:
            [String]
    ) -> String {
        switch components.count {
        case 0:
            return "no unsaved changes"

        case 1:
            return components[0]

        case 2:
            return components[0]
                + " and "
                + components[1]

        default:
            return components
                .dropLast()
                .joined(
                    separator:
                        ", "
                )
                + ", and "
                + (
                    components
                        .last
                    ?? ""
                )
        }
    }
}

/// Creates and connects the main application components.
@MainActor
final class AppCoordinator:
    NSObject,
    ApplicationLifecycleCoordinating
{
    private struct PendingRuleSave {
        let profileID:
            UUID

        let profileName:
            String

        let rules:
            [RemapRule]

        let wasPersistedBeforeQuit:
            Bool

        let session:
            RemappingRuleEditorSession
    }

    private struct ApplicationTerminationSaveIssue:
        Error
    {
        enum Destination {
            case home
            case rules(UUID)
        }

        let destination:
            Destination

        let message:
            String
    }

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

    /// Lightweight sorting and filtering state retained independently from the
    /// Rules window so the complete AppKit hierarchy can be released on close.
    private let remappingRulesPresentationModel =
        RemappingRulesPresentationModel()

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

        // The reusable Rules window has detached from the previous profile's
        // session. Any inactive session without unsaved changes or Undo/Redo
        // history can now be released and recreated lazily when needed again.
        ruleEditorSessionRegistry
            .removeDiscardableSessions(
                excluding:
                    profileID
            )

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

    /// Handles every normal macOS termination request in one place.
    ///
    /// Both the native application menu and the optional menu-bar popover call
    /// `NSApplication.terminate(_:)`, so they reach this method through
    /// `AppDelegate.applicationShouldTerminate(_:)` just like Command-Q and
    /// Quit from the Dock.
    func applicationShouldTerminate()
        -> NSApplication.TerminateReply
    {
        mainWindowController?
            .endActiveCapture()

        remappingRulesWindowController?
            .endActiveCapture()

        let summary =
            applicationUnsavedChangesSummary()

        guard
            summary.hasChanges
        else {
            return .terminateNow
        }

        NSApplication.shared
            .activate(
                ignoringOtherApps:
                    true
            )

        let alert =
            NSAlert()

        alert.messageText =
            "Save changes before quitting?"

        alert.informativeText =
            summary.informativeText

        alert.alertStyle =
            .warning

        alert.addButton(
            withTitle:
                "Save All"
        )

        alert.addButton(
            withTitle:
                "Quit Without Saving"
        )

        alert.addButton(
            withTitle:
                "Cancel"
        )

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveAllChangesBeforeTermination()
                ? .terminateNow
                : .terminateCancel

        case .alertSecondButtonReturn:
            return .terminateNow

        default:
            return .terminateCancel
        }
    }

    private func applicationUnsavedChangesSummary()
        -> ApplicationUnsavedChangesSummary
    {
        let hasHomeChanges =
            mainWindowController?
                .hasUnsavedChangesForApplicationTermination
            ?? homeConfigurationEditorSession?
                .hasUnsavedChanges
            ?? false

        let unsavedProfileIDs =
            unsavedRuleProfileIDs()

        let draftConfiguration =
            homeConfigurationEditorSession?
                .draft
                .profilesConfiguration

        let persistedConfiguration =
            try? profilesStore
                .loadConfiguration()

        let profileNames =
            unsavedProfileIDs
                .map {
                    profileID in

                    draftConfiguration?
                        .profile(
                            id:
                                profileID
                        )?
                        .name
                    ?? persistedConfiguration?
                        .profile(
                            id:
                                profileID
                        )?
                        .name
                    ?? "Unavailable Profile"
                }
                .sorted()

        return ApplicationUnsavedChangesSummary(
            hasHomeChanges:
                hasHomeChanges,
            unsavedRuleProfileNames:
                profileNames,
            hasOpenExceptionsEditor:
                remappingRulesWindowController?
                    .hasOpenExceptionsEditorForApplicationTermination
                == true
        )
    }

    private func unsavedRuleProfileIDs()
        -> [UUID]
    {
        ruleEditorSessionRegistry
            .profileIDsWithUnsavedChanges
            .sorted {
                first,
                second in

                first.uuidString
                    < second.uuidString
            }
    }

    /// Saves every safe, complete Home and Rules draft before termination.
    ///
    /// Existing profiles save Rules first so Home validation sees their newest
    /// mappings. Draft-only profiles save Home first so their UUID exists in
    /// storage, then save Rules. All drafts are preflighted before the first
    /// write. If a later storage operation fails, Quit is cancelled and every
    /// still-unsaved draft remains open in memory.
    private func saveAllChangesBeforeTermination()
        -> Bool
    {
        let mainController =
            getOrCreateMainWindowController()

        if let blockingMessage =
            mainController
                .applicationTerminationSaveBlockingMessage
        {
            mainController
                .showApplicationTerminationIssue(
                    blockingMessage
                )

            return false
        }

        if remappingRulesWindowController?
            .hasOpenExceptionsEditorForApplicationTermination
            == true
        {
            remappingRulesWindowController?
                .showApplicationTerminationIssue(
                    "Save Exceptions or choose Cancel in the open Custom Exceptions editor before using Save All."
                )

            return false
        }

        do {
            let draftConfiguration =
                try currentHomeProfilesConfiguration()

            let persistedConfiguration =
                try profilesStore
                    .loadConfiguration()

            let pendingRuleSaves =
                try preflightPendingRuleSaves(
                    draftConfiguration:
                        draftConfiguration,
                    persistedConfiguration:
                        persistedConfiguration
                )

            for pendingSave in
                pendingRuleSaves
                    .filter({
                        $0.wasPersistedBeforeQuit
                    })
            {
                guard
                    persistRuleChangesBeforeTermination(
                        pendingSave
                    )
                else {
                    return false
                }
            }

            if mainController
                .hasUnsavedChangesForApplicationTermination,
               !mainController
                    .saveChangesForApplicationTermination()
            {
                return false
            }

            for pendingSave in
                pendingRuleSaves
                    .filter({
                        !$0.wasPersistedBeforeQuit
                    })
            {
                guard
                    persistRuleChangesBeforeTermination(
                        pendingSave
                    )
                else {
                    return false
                }
            }

            return true
        } catch let issue
            as ApplicationTerminationSaveIssue
        {
            presentApplicationTerminationSaveIssue(
                issue
            )

            return false
        } catch {
            mainController
                .showApplicationTerminationIssue(
                    "Save All could not be completed. No unsaved draft was discarded, and LocalKeyRemapper will remain open."
                )

            return false
        }
    }

    private func preflightPendingRuleSaves(
        draftConfiguration:
            RemappingProfilesConfiguration,
        persistedConfiguration:
            RemappingProfilesConfiguration
    ) throws -> [PendingRuleSave] {
        let persistedProfileIDs =
            Set(
                persistedConfiguration
                    .profiles
                    .map(
                        \.id
                    )
            )

        let defaultShortcutConfiguration =
            homeConfigurationEditorSession?
                .draft
                .shortcutConfiguration
            ?? appPreferencesController
                .preferences
                .shortcutConfiguration

        return try unsavedRuleProfileIDs()
            .map {
                profileID in

                let session =
                    ruleEditorSessionRegistry
                        .session(
                            for:
                                profileID
                        )

                guard
                    let draftProfile =
                        draftConfiguration
                            .profile(
                                id:
                                    profileID
                            )
                else {
                    let persistedName =
                        persistedConfiguration
                            .profile(
                                id:
                                    profileID
                            )?
                            .name
                        ?? "this profile"

                    throw ApplicationTerminationSaveIssue(
                        destination:
                            .home,
                        message:
                            "“\(persistedName)” is pending deletion in Home but also has unsaved Rules. Restore the profile or discard its Rules changes before using Save All."
                    )
                }

                guard
                    let rules =
                        session
                            .completeRules
                else {
                    throw ApplicationTerminationSaveIssue(
                        destination:
                            .rules(
                                profileID
                            ),
                        message:
                            "Complete every highlighted rule in “\(draftProfile.name)” before using Save All."
                    )
                }

                do {
                    try rulesValidator
                        .validate(
                            rules
                        )
                } catch {
                    throw ApplicationTerminationSaveIssue(
                        destination:
                            .rules(
                                profileID
                            ),
                        message:
                            "Correct the highlighted rule validation issue in “\(draftProfile.name)” before using Save All."
                    )
                }

                if draftConfiguration
                    .activeProfileID
                    == profileID
                {
                    let effectiveShortcutConfiguration =
                        EffectiveRemappingShortcutConfigurationResolver
                            .resolve(
                                profile:
                                    draftProfile,
                                defaultConfiguration:
                                    defaultShortcutConfiguration
                            )

                    do {
                        try RemappingShortcutRuleConflictPolicy
                            .validate(
                                rules:
                                    rules,
                                shortcutConfiguration:
                                    effectiveShortcutConfiguration
                            )
                    } catch let conflict
                        as RemappingShortcutRuleConflict
                    {
                        throw ApplicationTerminationSaveIssue(
                            destination:
                                .rules(
                                    profileID
                                ),
                            message:
                                conflict.message
                        )
                    }
                }

                return PendingRuleSave(
                    profileID:
                        profileID,
                    profileName:
                        draftProfile.name,
                    rules:
                        rules,
                    wasPersistedBeforeQuit:
                        persistedProfileIDs
                            .contains(
                                profileID
                            ),
                    session:
                        session
                )
            }
    }

    private func persistRuleChangesBeforeTermination(
        _ pendingSave:
            PendingRuleSave
    ) -> Bool {
        do {
            try remappingController
                .replaceConfiguredRules(
                    pendingSave.rules,
                    for:
                        pendingSave.profileID
                )

            pendingSave.session
                .markCurrentRulesAsSaved(
                    pendingSave.rules
                )

            NotificationCenter.default.post(
                name:
                    AppConfigurationNotification
                        .remappingRulesDidChange,
                object:
                    nil
            )

            return true
        } catch let conflict
            as RemappingShortcutRuleConflict
        {
            showRemappingRulesWindow(
                for:
                    pendingSave.profileID
            )

            remappingRulesWindowController?
                .showApplicationTerminationIssue(
                    conflict.message
                )

            return false
        } catch {
            showRemappingRulesWindow(
                for:
                    pendingSave.profileID
            )

            remappingRulesWindowController?
                .showApplicationTerminationIssue(
                    "The Rules in “\(pendingSave.profileName)” could not be saved. LocalKeyRemapper will remain open and the draft was preserved."
                )

            return false
        }
    }

    private func presentApplicationTerminationSaveIssue(
        _ issue:
            ApplicationTerminationSaveIssue
    ) {
        switch issue.destination {
        case .home:
            getOrCreateMainWindowController()
                .showApplicationTerminationIssue(
                    issue.message
                )

        case .rules(
            let profileID
        ):
            showRemappingRulesWindow(
                for:
                    profileID
            )

            remappingRulesWindowController?
                .showApplicationTerminationIssue(
                    issue.message
                )
        }
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
            .onClose =
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

        controller.onClose = {
            [weak self] closedController in

            self?.handleMainWindowClosed(
                closedController
            )
        }

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

    /// Releases the complete Home controller and shortcut-sheet presentation
    /// wiring after the window delegate confirms a normal close.
    ///
    /// `homeConfigurationEditorSession` intentionally remains owned by the
    /// coordinator so the draft and bounded Undo/Redo history survive until the
    /// application terminates.
    private func handleMainWindowClosed(
        _ closedController:
            MainWindowController
    ) {
        guard
            mainWindowController
                === closedController
        else {
            return
        }

        homeProfileShortcutSheetCoordinator?
            .stop()

        homeProfileShortcutSheetCoordinator =
            nil

        mainWindowController =
            nil

        // The controller finishes its deferred AppKit teardown without being
        // retained here. A later Home request creates a fresh hierarchy and
        // reconnects it to the same editor session.
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
                presentationModel:
                    remappingRulesPresentationModel,
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

        controller.onClose = {
            [weak self] closedController in

            self?.handleRulesWindowClosed(
                closedController
            )
        }

        return controller
    }

    /// Releases the complete Rules controller and AppKit view hierarchy after
    /// the window delegate confirms that the user has closed it. Only
    /// recoverable editor data and the lightweight presentation model may
    /// remain in memory.
    private func handleRulesWindowClosed(
        _ closedController:
            RemappingRulesWindowController
    ) {
        guard
            remappingRulesWindowController
                === closedController
        else {
            return
        }

        remappingRulesWindowController =
            nil

        displayedRulesProfileID =
            nil

        rulesWindowAppPreferencesController.profileID =
            nil

        // The controller performs its window teardown synchronously after this
        // callback returns. Do not enqueue a closure that captures the closed
        // controller, because that would extend the lifetime of the complete UI.

        // A clean session with no Undo/Redo state is no longer needed once its
        // UI has closed. Sessions containing recoverable work remain retained.
        ruleEditorSessionRegistry
            .removeDiscardableSessions()
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
            let profile =
                persistedProfilesConfiguration
                    .profile(
                        id:
                            profileID
                    )
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

        do {
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
        } catch let conflict
            as RemappingShortcutRuleConflict
        {
            throw ProfileActivationShortcutConflict(
                profile:
                    profile,
                conflict:
                    conflict
            )
        }
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
