//
//  HomeConfigurationHistory.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Represents a failure to preserve a recoverable profile snapshot inside the
/// bounded, session-only Home Undo/Redo history.
nonisolated enum HomeConfigurationHistoryPreparationError:
    Error,
    Equatable
{
    /// No remaining Undo or Redo path can restore the specified profile.
    case missingRecoveryPath(UUID)

    /// Refreshing recoverable profile snapshots would exceed the configured
    /// in-memory history payload limit.
    case payloadLimitExceeded(
        required: Int,
        maximum: Int
    )
}

/// Stores session-only Undo and Redo entries for the Home editor.
///
/// The history is never encoded, persisted, logged, or written to disk.
nonisolated final class HomeConfigurationHistory {
    static let defaultMaximumEntryCount =
        5_000

    static let defaultMaximumEstimatedPayloadSize =
        1_500_000

    private struct Entry:
        Equatable
    {
        let sequenceNumber:
            UInt64

        let action:
            HomeConfigurationAction

        var estimatedPayloadSize:
            Int
        {
            action.estimatedPayloadSize
        }
    }

    private let maximumEntryCount:
        Int

    private let maximumEstimatedPayloadSize:
        Int

    private var undoEntries:
        [Entry] = []

    private var redoEntries:
        [Entry] = []

    private var nextSequenceNumber:
        UInt64 = 0

    private(set) var totalEstimatedPayloadSize =
        0

    init(
        maximumEntryCount:
            Int =
                HomeConfigurationHistory
                    .defaultMaximumEntryCount,
        maximumEstimatedPayloadSize:
            Int =
                HomeConfigurationHistory
                    .defaultMaximumEstimatedPayloadSize
    ) {
        self.maximumEntryCount =
            max(
                maximumEntryCount,
                0
            )

        self.maximumEstimatedPayloadSize =
            max(
                maximumEstimatedPayloadSize,
                0
            )
    }

    var canUndo:
        Bool
    {
        !undoEntries.isEmpty
    }

    var canRedo:
        Bool
    {
        !redoEntries.isEmpty
    }

    var undoEntryCount:
        Int
    {
        undoEntries.count
    }

    var redoEntryCount:
        Int
    {
        redoEntries.count
    }

    var totalEntryCount:
        Int
    {
        undoEntries.count
            + redoEntries.count
    }

    var maximumEstimatedPayloadSizeLimit:
        Int
    {
        maximumEstimatedPayloadSize
    }

    /// Returns the next Undo action without mutating either history stack.
    var nextUndoAction:
        HomeConfigurationAction?
    {
        undoEntries
            .last?
            .action
    }

    /// Returns whether one new action can remain available after normal
    /// oldest-entry trimming.
    ///
    /// This check is used before destructive profile removal so the profile is
    /// never removed from the draft when its own recovery action cannot fit.
    func canRetainNewEntry(
        _ action:
            HomeConfigurationAction
    ) -> Bool {
        maximumEntryCount > 0
            && action.estimatedPayloadSize
                <= maximumEstimatedPayloadSize
    }

    /// Records a new user edit and invalidates the previous Redo branch.
    func record(
        _ action:
            HomeConfigurationAction
    ) {
        removeAllRedoEntries()

        let entry =
            Entry(
                sequenceNumber:
                    nextSequenceNumber,
                action:
                    action
            )

        nextSequenceNumber &+=
            1

        undoEntries.append(
            entry
        )

        totalEstimatedPayloadSize +=
            entry.estimatedPayloadSize

        trimOldestEntriesIfNeeded()
    }

    /// Moves the newest Undo entry to Redo and returns its action.
    func takeUndoAction()
        -> HomeConfigurationAction?
    {
        guard
            let entry =
                undoEntries
                    .popLast()
        else {
            return nil
        }

        redoEntries.append(
            entry
        )

        return entry.action
    }

    /// Moves the newest Redo entry back to Undo and returns its action.
    func takeRedoAction()
        -> HomeConfigurationAction?
    {
        guard
            let entry =
                redoEntries
                    .popLast()
        else {
            return nil
        }

        undoEntries.append(
            entry
        )

        return entry.action
    }

    func clear() {
        undoEntries.removeAll()
        redoEntries.removeAll()

        totalEstimatedPayloadSize =
            0

        nextSequenceNumber =
            0
    }

    /// Refreshes recoverable profile snapshots with the latest independently
    /// persisted Rules before a Home Save commits their deletion.
    ///
    /// Only Rules and the Rules-derived update timestamp are refreshed. Home
    /// metadata stored by each historical action remains historically accurate.
    /// Candidate entries are validated first and installed atomically only when
    /// they remain inside the configured RAM limit and every deleted profile
    /// still has an Undo or Redo path back into the draft.
    func refreshRecoverableProfiles(
        for profileIDs:
            Set<UUID>,
        using persistedConfiguration:
            RemappingProfilesConfiguration,
        from currentSnapshot:
            HomeConfigurationSnapshot
    ) throws {
        guard
            !profileIDs.isEmpty
        else {
            return
        }

        let persistedProfilesByID =
            Dictionary(
                uniqueKeysWithValues:
                    persistedConfiguration
                        .profiles
                        .map {
                            (
                                $0.id,
                                $0
                            )
                        }
            )

        let candidateUndoEntries =
            undoEntries
                .map {
                    entry in

                    Entry(
                        sequenceNumber:
                            entry.sequenceNumber,
                        action:
                            Self.refreshingRecoverableProfiles(
                                in:
                                    entry.action,
                                profileIDs:
                                    profileIDs,
                                persistedProfilesByID:
                                    persistedProfilesByID
                            )
                    )
                }

        let candidateRedoEntries =
            redoEntries
                .map {
                    entry in

                    Entry(
                        sequenceNumber:
                            entry.sequenceNumber,
                        action:
                            Self.refreshingRecoverableProfiles(
                                in:
                                    entry.action,
                                profileIDs:
                                    profileIDs,
                                persistedProfilesByID:
                                    persistedProfilesByID
                            )
                    )
                }

        let candidatePayloadSize =
            Self.totalEstimatedPayloadSize(
                undoEntries:
                    candidateUndoEntries,
                redoEntries:
                    candidateRedoEntries
            )

        guard
            candidatePayloadSize
                <= maximumEstimatedPayloadSize
        else {
            throw HomeConfigurationHistoryPreparationError
                .payloadLimitExceeded(
                    required:
                        candidatePayloadSize,
                    maximum:
                        maximumEstimatedPayloadSize
                )
        }

        for profileID in profileIDs {
            guard
                Self.canRestoreProfile(
                    profileID,
                    from:
                        currentSnapshot,
                    undoEntries:
                        candidateUndoEntries,
                    redoEntries:
                        candidateRedoEntries
                )
            else {
                throw HomeConfigurationHistoryPreparationError
                    .missingRecoveryPath(
                        profileID
                    )
            }
        }

        undoEntries =
            candidateUndoEntries

        redoEntries =
            candidateRedoEntries

        totalEstimatedPayloadSize =
            candidatePayloadSize
    }

    private static func refreshingRecoverableProfiles(
        in action:
            HomeConfigurationAction,
        profileIDs:
            Set<UUID>,
        persistedProfilesByID:
            [UUID: RemappingProfile]
    ) -> HomeConfigurationAction {
        switch action {
        case .addProfile(
            let profile,
            let index
        ):
            return .addProfile(
                profile:
                    refreshingRecoverableProfile(
                        profile,
                        profileIDs:
                            profileIDs,
                        persistedProfilesByID:
                            persistedProfilesByID
                    ),
                index:
                    index
            )

        case .removeProfile(
            let profile,
            let index
        ):
            return .removeProfile(
                profile:
                    refreshingRecoverableProfile(
                        profile,
                        profileIDs:
                            profileIDs,
                        persistedProfilesByID:
                            persistedProfilesByID
                    ),
                index:
                    index
            )

        case .replaceAll(
            let before,
            let after
        ):
            return .replaceAll(
                before:
                    refreshingRecoverableProfiles(
                        in:
                            before,
                        profileIDs:
                            profileIDs,
                        persistedProfilesByID:
                            persistedProfilesByID
                    ),
                after:
                    refreshingRecoverableProfiles(
                        in:
                            after,
                        profileIDs:
                            profileIDs,
                        persistedProfilesByID:
                            persistedProfilesByID
                    )
            )

        default:
            return action
        }
    }

    private static func refreshingRecoverableProfiles(
        in snapshot:
            HomeConfigurationSnapshot,
        profileIDs:
            Set<UUID>,
        persistedProfilesByID:
            [UUID: RemappingProfile]
    ) -> HomeConfigurationSnapshot {
        var refreshedSnapshot =
            snapshot

        refreshedSnapshot.profiles =
            snapshot
                .profiles
                .map {
                    refreshingRecoverableProfile(
                        $0,
                        profileIDs:
                            profileIDs,
                        persistedProfilesByID:
                            persistedProfilesByID
                    )
                }

        return refreshedSnapshot
    }

    private static func refreshingRecoverableProfile(
        _ profile:
            RemappingProfile,
        profileIDs:
            Set<UUID>,
        persistedProfilesByID:
            [UUID: RemappingProfile]
    ) -> RemappingProfile {
        guard
            profileIDs.contains(
                profile.id
            ),
            let persistedProfile =
                persistedProfilesByID[
                    profile.id
                ]
        else {
            return profile
        }

        var refreshedProfile =
            profile

        refreshedProfile.rules =
            persistedProfile.rules

        refreshedProfile.updatedAt =
            persistedProfile.updatedAt

        return refreshedProfile
    }

    /// Returns whether repeated Undo or repeated Redo from the current draft can
    /// bring one removed profile back. No stack is mutated during this preview.
    private static func canRestoreProfile(
        _ profileID:
            UUID,
        from currentSnapshot:
            HomeConfigurationSnapshot,
        undoEntries:
            [Entry],
        redoEntries:
            [Entry]
    ) -> Bool {
        if currentSnapshot.profile(
            id:
                profileID
        ) != nil
        {
            return true
        }

        var undoSnapshot =
            currentSnapshot

        for entry in undoEntries.reversed() {
            undoSnapshot =
                entry.action
                    .applyingUndo(
                        to:
                            undoSnapshot
                    )

            if undoSnapshot.profile(
                id:
                    profileID
            ) != nil
            {
                return true
            }
        }

        var redoSnapshot =
            currentSnapshot

        for entry in redoEntries.reversed() {
            redoSnapshot =
                entry.action
                    .applyingRedo(
                        to:
                            redoSnapshot
                    )

            if redoSnapshot.profile(
                id:
                    profileID
            ) != nil
            {
                return true
            }
        }

        return false
    }

    private static func totalEstimatedPayloadSize(
        undoEntries:
            [Entry],
        redoEntries:
            [Entry]
    ) -> Int {
        undoEntries
            .reduce(
                0
            ) {
                $0
                    + $1.estimatedPayloadSize
            }
        + redoEntries
            .reduce(
                0
            ) {
                $0
                    + $1.estimatedPayloadSize
            }
    }

    private func removeAllRedoEntries() {
        for entry in redoEntries {
            totalEstimatedPayloadSize -=
                entry.estimatedPayloadSize
        }

        redoEntries.removeAll()
    }

    private func trimOldestEntriesIfNeeded() {
        while
            totalEntryCount
                > maximumEntryCount
                || totalEstimatedPayloadSize
                    > maximumEstimatedPayloadSize
        {
            guard
                removeOldestEntry()
            else {
                break
            }
        }
    }

    @discardableResult
    private func removeOldestEntry()
        -> Bool
    {
        let oldestUndoIndex =
            undoEntries.indices.min {
                undoEntries[$0]
                    .sequenceNumber
                    < undoEntries[$1]
                        .sequenceNumber
            }

        let oldestRedoIndex =
            redoEntries.indices.min {
                redoEntries[$0]
                    .sequenceNumber
                    < redoEntries[$1]
                        .sequenceNumber
            }

        switch (
            oldestUndoIndex,
            oldestRedoIndex
        ) {
        case (
            .none,
            .none
        ):
            return false

        case (
            .some(
                let undoIndex
            ),
            .none
        ):
            removeUndoEntry(
                at:
                    undoIndex
            )

        case (
            .none,
            .some(
                let redoIndex
            )
        ):
            removeRedoEntry(
                at:
                    redoIndex
            )

        case (
            .some(
                let undoIndex
            ),
            .some(
                let redoIndex
            )
        ):
            if undoEntries[
                undoIndex
            ]
                .sequenceNumber
                <= redoEntries[
                    redoIndex
                ]
                    .sequenceNumber
            {
                removeUndoEntry(
                    at:
                        undoIndex
                )
            } else {
                removeRedoEntry(
                    at:
                        redoIndex
                )
            }
        }

        return true
    }

    private func removeUndoEntry(
        at index:
            Int
    ) {
        let removedEntry =
            undoEntries.remove(
                at:
                    index
            )

        totalEstimatedPayloadSize -=
            removedEntry.estimatedPayloadSize
    }

    private func removeRedoEntry(
        at index:
            Int
    ) {
        let removedEntry =
            redoEntries.remove(
                at:
                    index
            )

        totalEstimatedPayloadSize -=
            removedEntry.estimatedPayloadSize
    }
}
