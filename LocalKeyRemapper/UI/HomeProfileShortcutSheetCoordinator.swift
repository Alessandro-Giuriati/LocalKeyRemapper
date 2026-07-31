//
//  HomeProfileShortcutSheetCoordinator.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import AppKit

/// Represents a profile-shortcut editing operation that can no longer reach
/// the shared Home editor session.
nonisolated enum HomeProfileShortcutSheetCoordinatorError:
    Error,
    Equatable
{
    case editorUnavailable
}

/// Connects the Profiles table and Default Global Shortcuts editor to the
/// profile-specific shortcut sheet.
///
/// The coordinator owns presentation wiring only. Profile changes are recorded
/// exclusively through `HomeConfigurationEditorSession`, while Carbon
/// registration and remapping suspension remain delegated to the existing
/// runtime controllers.
///
/// This component stores no keyboard input, performs no polling, and creates no
/// network, analytics, telemetry, or cloud-crash-reporting activity.
@MainActor
final class HomeProfileShortcutSheetCoordinator:
    NSObject
{
    private weak var mainWindowController:
        MainWindowController?

    private let remappingController:
        RemappingSettingsControlling

    private let globalShortcutController:
        GlobalShortcutController

    private let homeConfigurationEditorSession:
        HomeConfigurationEditorSession

    private let profilesConfigurationProvider:
        () throws -> RemappingProfilesConfiguration

    private weak var profilesSectionView:
        HomeProfilesSectionView?

    private weak var defaultShortcutSettingsView:
        GlobalShortcutSettingsView?

    private var profileShortcutSheetController:
        ProfileShortcutConfigurationSheetController?

    private(set) var presentedProfileID:
        UUID?

    private var isStarted =
        false

    init(
        mainWindowController:
            MainWindowController,
        remappingController:
            RemappingSettingsControlling,
        globalShortcutController:
            GlobalShortcutController,
        homeConfigurationEditorSession:
            HomeConfigurationEditorSession,
        profilesConfigurationProvider:
            @escaping () throws -> RemappingProfilesConfiguration
    ) {
        self.mainWindowController =
            mainWindowController

        self.remappingController =
            remappingController

        self.globalShortcutController =
            globalShortcutController

        self.homeConfigurationEditorSession =
            homeConfigurationEditorSession

        self.profilesConfigurationProvider =
            profilesConfigurationProvider

        super.init()
    }

    /// Installs the profile editor callback and replaces Default shortcut
    /// assessment with effective-active-profile assessment.
    func start() {
        guard
            !isStarted,
            let contentView =
                mainWindowController?
                    .window?
                    .contentView,
            let profilesSectionView:
                HomeProfilesSectionView =
                    descendant(
                        of:
                            HomeProfilesSectionView.self,
                        in:
                            contentView
                    ),
            let defaultShortcutSettingsView:
                GlobalShortcutSettingsView =
                    descendant(
                        of:
                            GlobalShortcutSettingsView.self,
                        in:
                            contentView
                    )
        else {
            return
        }

        isStarted =
            true

        self.profilesSectionView =
            profilesSectionView

        self.defaultShortcutSettingsView =
            defaultShortcutSettingsView

        defaultShortcutSettingsView
            .applyDefaultGlobalShortcutPresentation()

        profilesSectionView.onEditShortcut = {
            [weak self] profileID in

            self?.presentProfileShortcutEditor(
                for:
                    profileID
            )
        }

        defaultShortcutSettingsView
            .onAdditionalValidationRequested = {
                [weak self] proposedDefaultConfiguration in

                self?
                    .defaultValidationMessage(
                        for:
                            proposedDefaultConfiguration
                    )
            }

        defaultShortcutSettingsView
            .onAdditionalSuggestionRequested = {
                [weak self] proposedDefaultConfiguration in

                self?
                    .defaultSuggestionMessage(
                        for:
                            proposedDefaultConfiguration
                    )
            }

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

        defaultShortcutSettingsView
            .refreshValidationState()
    }

    /// Removes callbacks, observers, and any attached profile shortcut sheet.
    func stop() {
        guard
            isStarted
        else {
            return
        }

        isStarted =
            false

        NotificationCenter.default.removeObserver(
            self,
            name:
                AppConfigurationNotification
                    .remappingRulesDidChange,
            object:
                nil
        )

        profilesSectionView?
            .onEditShortcut =
                nil

        profileShortcutSheetController?
            .prepareForApplicationTermination()

        profileShortcutSheetController =
            nil

        presentedProfileID =
            nil

        profilesSectionView =
            nil

        defaultShortcutSettingsView =
            nil
    }

    func applyTextScale(
        _ scale:
            CGFloat
    ) {
        profileShortcutSheetController?
            .applyTextScale(
                scale
            )
    }

    // MARK: - Test support

    var presentedSheetControllerForTesting:
        ProfileShortcutConfigurationSheetController?
    {
        profileShortcutSheetController
    }

    func presentProfileShortcutEditorForTesting(
        for profileID:
            UUID
    ) {
        presentProfileShortcutEditor(
            for:
                profileID
        )
    }

    private func presentProfileShortcutEditor(
        for profileID:
            UUID
    ) {
        guard
            profileShortcutSheetController == nil,
            let parentWindow =
                mainWindowController?
                    .window,
            let profile =
                homeConfigurationEditorSession
                    .draft
                    .profile(
                        id:
                            profileID
                    )
        else {
            return
        }

        mainWindowController?
            .endActiveCapture()

        let sheetController =
            ProfileShortcutConfigurationSheetController(
                profileName:
                    profile.name,
                shortcutConfigurationOverride:
                    profile
                        .shortcutConfigurationOverride,
                shortcutMemory:
                    profile
                        .shortcutMemory,
                defaultConfiguration:
                    homeConfigurationEditorSession
                        .draft
                        .shortcutConfiguration,
                remappingController:
                    remappingController,
                globalShortcutController:
                    globalShortcutController,
                additionalValidationHandler: {
                    [weak self] effectiveConfiguration in

                    self?
                        .profileValidationMessage(
                            for:
                                effectiveConfiguration,
                            profileID:
                                profileID
                        )
                },
                additionalSuggestionHandler: {
                    [weak self] effectiveConfiguration in

                    self?
                        .profileSuggestionMessage(
                            for:
                                effectiveConfiguration,
                            profileID:
                                profileID
                        )
                },
                applyHandler: {
                    [weak self] proposedOverride in

                    guard
                        let self
                    else {
                        throw HomeProfileShortcutSheetCoordinatorError
                            .editorUnavailable
                    }

                    try self
                        .homeConfigurationEditorSession
                        .setShortcutConfigurationOverride(
                            proposedOverride,
                            for:
                                profileID
                        )

                    let updatedProfileName =
                        self
                            .homeConfigurationEditorSession
                            .draft
                            .profile(
                                id:
                                    profileID
                            )?
                            .name
                        ?? profile.name

                    self.profilesSectionView?
                        .onStatusChange?(
                            "The shortcut configuration for “\(updatedProfileName)” was added to the Home draft.",
                            false
                        )
                },
                dismissalHandler: {
                    [weak self] in

                    self?
                        .profileShortcutSheetController =
                            nil

                    self?
                        .presentedProfileID =
                            nil
                },
                textScale:
                    InterfaceTextScalePreference
                        .currentScale
            )

        profileShortcutSheetController =
            sheetController

        presentedProfileID =
            profileID

        sheetController.present(
            attachedTo:
                parentWindow
        )
    }

    /// Returns the configuration that Home Save would validate now.
    ///
    /// Profile metadata and shortcut overrides come from the Home draft, while
    /// independently saved Rules are merged from persistence.
    private func profilesConfigurationForValidation()
        throws -> RemappingProfilesConfiguration
    {
        let persistedConfiguration =
            try profilesConfigurationProvider()

        return HomeProfilesConfigurationMerger
            .merging(
                homeDraft:
                    homeConfigurationEditorSession
                        .draft
                        .profilesConfiguration,
                persisted:
                    persistedConfiguration
            )
    }

    private func defaultAssessment(
        for proposedDefaultConfiguration:
            RemappingShortcutConfiguration
    ) throws -> HomeShortcutDraftAssessment {
        try HomeShortcutDraftAssessor
            .assessDefaultConfiguration(
                proposedDefaultConfiguration,
                in:
                    profilesConfigurationForValidation()
            )
    }

    private func defaultValidationMessage(
        for proposedDefaultConfiguration:
            RemappingShortcutConfiguration
    ) -> String? {
        do {
            return try defaultAssessment(
                for:
                    proposedDefaultConfiguration
            )
            .blockingMessage
        } catch {
            return "The remapping profiles could not be loaded for shortcut validation."
        }
    }

    private func defaultSuggestionMessage(
        for proposedDefaultConfiguration:
            RemappingShortcutConfiguration
    ) -> String? {
        try? defaultAssessment(
            for:
                proposedDefaultConfiguration
        )
        .suggestionMessage
    }

    /// Assesses the already resolved effective configuration represented by the
    /// profile sheet.
    ///
    /// Passing it as an explicit override is intentional: conflict and warning
    /// behavior depends only on the effective combination. Whether the user
    /// stores `nil` or an equal explicit override remains preserved separately
    /// by the sheet proposal and Home editor session.
    private func profileAssessment(
        for effectiveConfiguration:
            RemappingShortcutConfiguration,
        profileID:
            UUID
    ) throws -> HomeShortcutDraftAssessment {
        try HomeShortcutDraftAssessor
            .assessProfileOverride(
                effectiveConfiguration,
                for:
                    profileID,
                defaultConfiguration:
                    .disabled,
                in:
                    profilesConfigurationForValidation()
            )
    }

    private func profileValidationMessage(
        for effectiveConfiguration:
            RemappingShortcutConfiguration,
        profileID:
            UUID
    ) -> String? {
        do {
            return try profileAssessment(
                for:
                    effectiveConfiguration,
                profileID:
                    profileID
            )
            .blockingMessage
        } catch {
            return "The selected remapping profile could not be loaded for shortcut validation."
        }
    }

    private func profileSuggestionMessage(
        for effectiveConfiguration:
            RemappingShortcutConfiguration,
        profileID:
            UUID
    ) -> String? {
        try? profileAssessment(
            for:
                effectiveConfiguration,
            profileID:
                profileID
        )
        .suggestionMessage
    }

    @objc
    private func remappingRulesDidChange(
        _ notification:
            Notification
    ) {
        defaultShortcutSettingsView?
            .refreshValidationState()

        profileShortcutSheetController?
            .refreshValidationState()
    }

    private func descendant<T: NSView>(
        of type:
            T.Type,
        in rootView:
            NSView
    ) -> T? {
        if let matchingView =
            rootView as? T
        {
            return matchingView
        }

        for subview in rootView.subviews {
            if let matchingView:
                T =
                    descendant(
                        of:
                            type,
                        in:
                            subview
                    )
            {
                return matchingView
            }
        }

        return nil
    }
}
