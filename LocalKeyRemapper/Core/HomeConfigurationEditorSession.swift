//
//  HomeConfigurationEditorSession.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Represents an invalid Home editing operation.
nonisolated enum HomeConfigurationEditorSessionError:
    Error,
    Equatable
{
    /// No draft profile uses the requested UUID.
    case profileNotFound(UUID)

    /// The requested UUID is already owned by another draft profile.
    case duplicateProfileID(UUID)

    /// A valid Home configuration must retain at least one profile.
    case cannotRemoveLastProfile

    /// The active profile must be changed before that profile can be removed.
    case cannotRemoveActiveProfile(UUID)

    /// The proposed active UUID does not identify a draft profile.
    case invalidActiveProfile(UUID)
}

/// Owns the editable Home draft, saved baseline, and session-only history.
///
/// This session is intentionally independent from every profile-specific Rules
/// session. It stores configuration edits only and never stores key presses,
/// captured input history, analytics, or telemetry.
@MainActor
final class HomeConfigurationEditorSession {
    var onChange:
        (() -> Void)?

    private let history:
        HomeConfigurationHistory

    /// Every profile UUID that has existed in the Home draft since the most
    /// recent successful Home Save.
    ///
    /// The coordinator can use the IDs returned by `markCurrentDraftAsSaved`
    /// to remove Rules sessions only after deletion has become committed.
    private var knownProfileIDs:
        Set<UUID>

    private(set) var savedSnapshot:
        HomeConfigurationSnapshot

    private(set) var draft:
        HomeConfigurationSnapshot

    init(
        snapshot:
            HomeConfigurationSnapshot,
        history:
            HomeConfigurationHistory =
                HomeConfigurationHistory()
    ) {
        savedSnapshot =
            snapshot

        draft =
            snapshot

        self.history =
            history

        knownProfileIDs =
            Set(
                snapshot
                    .profiles
                    .map(
                        \.id
                    )
            )
    }

    var canUndo:
        Bool
    {
        history.canUndo
    }

    var canRedo:
        Bool
    {
        history.canRedo
    }

    var historyEntryCount:
        Int
    {
        history.totalEntryCount
    }

    var estimatedHistoryPayloadSize:
        Int
    {
        history.totalEstimatedPayloadSize
    }

    /// Indicates whether the Home draft differs from the last successful save.
    var hasUnsavedChanges:
        Bool
    {
        draft != savedSnapshot
    }

    /// Returns the first available exact `Profile N` name.
    var nextAvailableProfileName:
        String
    {
        Self.nextAvailableNumberedName(
            prefix:
                "Profile",
            existingNames:
                Set(
                    draft
                        .profiles
                        .map(
                            \.name
                        )
                )
        )
    }

    /// Changes Remapping at Launch as one Home Undo/Redo action.
    func setLaunchBehavior(
        _ launchBehavior:
            RemappingLaunchBehavior
    ) {
        let previousBehavior =
            draft.launchBehavior

        guard
            previousBehavior
                != launchBehavior
        else {
            return
        }

        applyNewAction(
            .setLaunchBehavior(
                before:
                    previousBehavior,
                after:
                    launchBehavior
            )
        )
    }

    /// Changes the application-wide default shortcut configuration.
    ///
    /// Profiles whose override is `nil` resolve to this configuration.
    func setShortcutConfiguration(
        _ shortcutConfiguration:
            RemappingShortcutConfiguration
    ) {
        let previousConfiguration =
            draft.shortcutConfiguration

        guard
            previousConfiguration
                != shortcutConfiguration
        else {
            return
        }

        applyNewAction(
            .setShortcutConfiguration(
                before:
                    previousConfiguration,
                after:
                    shortcutConfiguration
            )
        )
    }

    /// Changes one profile's optional shortcut override as one reversible
    /// Home action.
    ///
    /// Passing `nil` selects Use Default. Passing `.disabled` selects an
    /// explicit Off state. An override equal to the current default remains
    /// explicit and is not converted to `nil`.
    ///
    /// Custom Toggle and Separate values are also copied into the profile's
    /// persistent shortcut memory. Use Default and Off preserve every
    /// previously remembered custom value.
    func setShortcutConfigurationOverride(
        _ shortcutConfigurationOverride:
            RemappingShortcutConfiguration?,
        for profileID:
            UUID,
        timestamp:
            Date = Date()
    ) throws {
        guard
            let profile =
                draft.profile(
                    id:
                        profileID
                )
        else {
            throw HomeConfigurationEditorSessionError
                .profileNotFound(
                    profileID
                )
        }

        let previousOverride =
            profile
                .shortcutConfigurationOverride

        let previousMemory =
            profile
                .shortcutMemory

        let updatedMemory =
            previousMemory.remembering(
                shortcutConfigurationOverride
            )

        guard
            previousOverride
                != shortcutConfigurationOverride
            || previousMemory
                != updatedMemory
        else {
            return
        }

        applyNewAction(
            .setProfileShortcutConfigurationOverride(
                profileID:
                    profileID,
                before:
                    previousOverride,
                after:
                    shortcutConfigurationOverride,
                beforeMemory:
                    previousMemory,
                afterMemory:
                    updatedMemory,
                beforeUpdatedAt:
                    profile.updatedAt,
                afterUpdatedAt:
                    timestamp
            )
        )
    }

    /// Adds one empty profile using the first available exact `Profile N` name.
    ///
    /// The existing active profile remains active. Row selection is
    /// presentation-only and is therefore not stored by this session.
    @discardableResult
    func addProfile(
        id profileID:
            UUID = UUID(),
        timestamp:
            Date = Date()
    ) throws -> RemappingProfile {
        guard
            draft.profile(
                id:
                    profileID
            ) == nil
        else {
            throw HomeConfigurationEditorSessionError
                .duplicateProfileID(
                    profileID
                )
        }

        let profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    nextAvailableProfileName,
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                rules:
                    [],
                shortcutConfigurationOverride:
                    nil,
                shortcutMemory:
                    .empty
            )

        applyNewAction(
            .addProfile(
                profile:
                    profile,
                index:
                    draft
                        .profiles
                        .count
            )
        )

        return profile
    }

    /// Duplicates a complete profile as one Home Undo/Redo action.
    ///
    /// The duplicate receives a new UUID and new dates while preserving the
    /// complete rule collection, shortcut override, and remembered custom
    /// shortcuts. It is inserted immediately after its source profile and does
    /// not become active automatically.
    @discardableResult
    func duplicateProfile(
        id sourceProfileID:
            UUID,
        newProfileID:
            UUID = UUID(),
        timestamp:
            Date = Date()
    ) throws -> RemappingProfile {
        guard
            let sourceIndex =
                draft
                    .profiles
                    .firstIndex(
                        where: {
                            $0.id
                                == sourceProfileID
                        }
                    )
        else {
            throw HomeConfigurationEditorSessionError
                .profileNotFound(
                    sourceProfileID
                )
        }

        guard
            draft.profile(
                id:
                    newProfileID
            ) == nil
        else {
            throw HomeConfigurationEditorSessionError
                .duplicateProfileID(
                    newProfileID
                )
        }

        let sourceProfile =
            draft
                .profiles[
                    sourceIndex
                ]

        let duplicateName =
            Self.nextAvailableDuplicateName(
                for:
                    sourceProfile.name,
                existingNames:
                    Set(
                        draft
                            .profiles
                            .map(
                                \.name
                            )
                    )
            )

        let duplicate =
            RemappingProfile(
                id:
                    newProfileID,
                name:
                    duplicateName,
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                rules:
                    sourceProfile.rules,
                shortcutConfigurationOverride:
                    sourceProfile
                        .shortcutConfigurationOverride,
                shortcutMemory:
                    sourceProfile
                        .shortcutMemory
            )

        applyNewAction(
            .addProfile(
                profile:
                    duplicate,
                index:
                    sourceIndex + 1
            )
        )

        return duplicate
    }

    /// Renames one profile while preserving its UUID, creation date, rules,
    /// shortcut override, and remembered shortcut values.
    ///
    /// Name normalization and uniqueness validation intentionally happen before
    /// persistence, not inside the history layer. This allows the UI to keep an
    /// invalid draft visible and editable without persisting it.
    func renameProfile(
        id profileID:
            UUID,
        to name:
            String,
        timestamp:
            Date = Date()
    ) throws {
        guard
            let profile =
                draft.profile(
                    id:
                        profileID
                )
        else {
            throw HomeConfigurationEditorSessionError
                .profileNotFound(
                    profileID
                )
        }

        guard
            profile.name
                != name
        else {
            return
        }

        applyNewAction(
            .renameProfile(
                profileID:
                    profileID,
                beforeName:
                    profile.name,
                afterName:
                    name,
                beforeUpdatedAt:
                    profile.updatedAt,
                afterUpdatedAt:
                    timestamp
            )
        )
    }

    /// Removes one inactive profile as one reversible action.
    ///
    /// The complete profile and its original position remain in Home history.
    /// The Rules session registry must not remove the profile session until a
    /// later Home Save succeeds.
    func removeProfile(
        id profileID:
            UUID
    ) throws {
        guard
            draft
                .profiles
                .count > 1
        else {
            throw HomeConfigurationEditorSessionError
                .cannotRemoveLastProfile
        }

        guard
            draft.activeProfileID
                != profileID
        else {
            throw HomeConfigurationEditorSessionError
                .cannotRemoveActiveProfile(
                    profileID
                )
        }

        guard
            let profileIndex =
                draft
                    .profiles
                    .firstIndex(
                        where: {
                            $0.id == profileID
                        }
                    )
        else {
            throw HomeConfigurationEditorSessionError
                .profileNotFound(
                    profileID
                )
        }

        applyNewAction(
            .removeProfile(
                profile:
                    draft
                        .profiles[
                            profileIndex
                        ],
                index:
                    profileIndex
            )
        )
    }

    /// Selects the profile proposed for runtime use after successful Home Save.
    ///
    /// This updates the Home draft only. It does not immediately replace engine
    /// rules or recreate an event tap.
    func setActiveProfile(
        _ profileID:
            UUID
    ) throws {
        guard
            draft.profile(
                id:
                    profileID
            ) != nil
        else {
            throw HomeConfigurationEditorSessionError
                .invalidActiveProfile(
                    profileID
                )
        }

        let previousProfileID =
            draft.activeProfileID

        guard
            previousProfileID
                != profileID
        else {
            return
        }

        applyNewAction(
            .setActiveProfile(
                before:
                    previousProfileID,
                after:
                    profileID
            )
        )
    }

    /// Restores the saved Home baseline as one reversible action.
    func restoreSavedSnapshot() {
        guard
            hasUnsavedChanges
        else {
            return
        }

        applyNewAction(
            .replaceAll(
                before:
                    draft,
                after:
                    savedSnapshot
            )
        )
    }

    /// Updates the saved baseline without clearing Undo or Redo.
    ///
    /// Pass the normalized snapshot actually committed by the save transaction
    /// when persistence trims profile names or otherwise canonicalizes data.
    /// The returned IDs identify every profile that existed since the previous
    /// successful save but is absent from the newly committed configuration.
    /// Those Rules sessions may now be removed permanently.
    @discardableResult
    func markCurrentDraftAsSaved(
        _ committedSnapshot:
            HomeConfigurationSnapshot? = nil
    ) -> Set<UUID> {
        let snapshot =
            committedSnapshot
                ?? draft

        let committedProfileIDs =
            Set(
                snapshot
                    .profiles
                    .map(
                        \.id
                    )
            )

        let committedDeletionIDs =
            knownProfileIDs
                .subtracting(
                    committedProfileIDs
                )

        savedSnapshot =
            snapshot

        draft =
            snapshot

        knownProfileIDs =
            committedProfileIDs

        onChange?()

        return committedDeletionIDs
    }

    func undo() {
        guard
            let action =
                history
                    .takeUndoAction()
        else {
            return
        }

        draft =
            action.applyingUndo(
                to:
                    draft
            )

        recordKnownDraftProfileIDs()
        onChange?()
    }

    func redo() {
        guard
            let action =
                history
                    .takeRedoAction()
        else {
            return
        }

        draft =
            action.applyingRedo(
                to:
                    draft
            )

        recordKnownDraftProfileIDs()
        onChange?()
    }

    private func applyNewAction(
        _ action:
            HomeConfigurationAction
    ) {
        history.record(
            action
        )

        draft =
            action.applyingRedo(
                to:
                    draft
            )

        recordKnownDraftProfileIDs()
        onChange?()
    }

    private func recordKnownDraftProfileIDs() {
        knownProfileIDs.formUnion(
            draft
                .profiles
                .map(
                    \.id
                )
        )
    }

    private static func nextAvailableNumberedName(
        prefix:
            String,
        existingNames:
            Set<String>
    ) -> String {
        var number =
            1

        while
            existingNames.contains(
                "\(prefix) \(number)"
            )
        {
            number +=
                1
        }

        return "\(prefix) \(number)"
    }

    private static func nextAvailableDuplicateName(
        for sourceName:
            String,
        existingNames:
            Set<String>
    ) -> String {
        let firstCandidate =
            "\(sourceName) Copy"

        guard
            existingNames.contains(
                firstCandidate
            )
        else {
            return firstCandidate
        }

        var copyNumber =
            2

        while
            existingNames.contains(
                "\(sourceName) Copy \(copyNumber)"
            )
        {
            copyNumber +=
                1
        }

        return "\(sourceName) Copy \(copyNumber)"
    }
}
