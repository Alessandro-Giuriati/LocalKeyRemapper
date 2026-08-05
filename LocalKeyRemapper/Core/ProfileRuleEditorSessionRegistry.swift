//
//  ProfileRuleEditorSessionRegistry.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Retains independent Rules editor sessions only while they contain state
/// that must survive profile switching.
///
/// A session is always retained while it belongs to the currently displayed
/// profile or contains unsaved changes. Clean inactive sessions may keep their
/// session-only Undo/Redo history while the global estimated-history budget
/// allows it. When that budget is exceeded, the least recently used clean
/// inactive sessions are released first and can later be recreated from the
/// persisted profile configuration.
///
/// Releasing a clean session can discard only its session-only Undo/Redo
/// history. It never discards unsaved Rules or changes persisted configuration.
///
/// The registry stores editor state only in memory. It does not persist, log,
/// or transmit keyboard input, editing history, or captured key presses.
@MainActor
final class ProfileRuleEditorSessionRegistry {

    /// Four sessions may each reach the existing per-session history limit
    /// before clean inactive histories begin to be evicted.
    ///
    /// `RuleEditorHistory` exposes a deterministic payload estimate rather than
    /// claiming exact Swift heap usage. The global limit deliberately uses the
    /// same unit so its behavior remains stable and testable.
    nonisolated static let defaultMaximumRetainedEstimatedHistoryPayloadSize =
        RuleEditorHistory.defaultMaximumEstimatedPayloadSize * 4

    private var sessionsByProfileID:
        [UUID: RemappingRuleEditorSession] = [:]

    /// Monotonic access stamps used only for in-memory LRU ordering.
    private var lastAccessSequenceByProfileID:
        [UUID: UInt64] = [:]

    private var nextAccessSequence:
        UInt64 = 0

    private let maximumRetainedEstimatedHistoryPayloadSize:
        Int

    private let sessionFactory:
        () -> RemappingRuleEditorSession

    init(
        maximumRetainedEstimatedHistoryPayloadSize:
            Int =
                ProfileRuleEditorSessionRegistry
                    .defaultMaximumRetainedEstimatedHistoryPayloadSize,
        sessionFactory:
            @escaping () -> RemappingRuleEditorSession = {
                RemappingRuleEditorSession()
            }
    ) {
        self.maximumRetainedEstimatedHistoryPayloadSize =
            max(
                maximumRetainedEstimatedHistoryPayloadSize,
                0
            )

        self.sessionFactory =
            sessionFactory
    }

    /// IDs belonging to initialized sessions that currently contain unsaved
    /// Rules changes.
    ///
    /// Reading this value never creates a new session and does not change LRU
    /// ordering.
    var profileIDsWithUnsavedChanges:
        Set<UUID>
    {
        var profileIDs:
            Set<UUID> = []

        for (
            profileID,
            session
        ) in sessionsByProfileID {
            guard
                session.isInitialized,
                session.hasUnsavedChanges
            else {
                continue
            }

            profileIDs.insert(
                profileID
            )
        }

        return profileIDs
    }

    /// Total deterministic history estimate currently retained across every
    /// Rules session, including protected and unsaved sessions.
    var totalEstimatedHistoryPayloadSize:
        Int
    {
        sessionsByProfileID
            .values
            .reduce(
                into: 0
            ) {
                total,
                session in

                total +=
                    session
                        .estimatedHistoryPayloadSize
            }
    }

    /// Exposes the configured limit for diagnostics and regression tests.
    var maximumRetainedEstimatedHistoryPayloadSizeLimit:
        Int
    {
        maximumRetainedEstimatedHistoryPayloadSize
    }

    /// Returns whether a session is already retained without creating it or
    /// changing LRU ordering.
    func containsSession(
        for profileID:
            UUID
    ) -> Bool {
        sessionsByProfileID[
            profileID
        ] != nil
    }

    /// Returns the existing session for a profile or creates it lazily.
    ///
    /// Repeated requests using the same UUID return the same object while that
    /// session remains retained. Every request marks the profile as most
    /// recently used for future clean-session eviction.
    func session(
        for profileID:
            UUID
    ) -> RemappingRuleEditorSession {
        if let existingSession =
            sessionsByProfileID[
                profileID
            ]
        {
            recordAccess(
                to:
                    profileID
            )

            return existingSession
        }

        let newSession =
            sessionFactory()

        sessionsByProfileID[
            profileID
        ] =
            newSession

        recordAccess(
            to:
                profileID
        )

        return newSession
    }

    /// Releases inactive sessions that contain no irreplaceable user state.
    ///
    /// Cleanup happens in two stages:
    /// 1. clean inactive sessions without Undo/Redo history are always removed;
    /// 2. if retained history still exceeds the global budget, clean inactive
    ///    sessions with history are removed in least-recently-used order.
    ///
    /// A session is never removed when it:
    /// - belongs to the protected profile;
    /// - contains unsaved Rules changes.
    ///
    /// If protected or unsaved sessions alone exceed the budget, cleanup stops
    /// without discarding their data.
    @discardableResult
    func removeDiscardableSessions(
        excluding protectedProfileID:
            UUID? = nil
    ) -> Set<UUID> {
        var removedProfileIDs =
            removeCleanSessionsWithoutHistory(
                excluding:
                    protectedProfileID
            )

        removedProfileIDs.formUnion(
            removeLeastRecentlyUsedCleanSessionsExceedingBudget(
                excluding:
                    protectedProfileID
            )
        )

        return removedProfileIDs
    }

    /// Removes the session belonging to one permanently deleted profile.
    ///
    /// This must be called only when profile deletion becomes committed.
    func removeSession(
        for profileID:
            UUID
    ) {
        removeRetainedSession(
            for:
                profileID
        )
    }

    /// Releases every retained session during application termination.
    func removeAllSessions() {
        sessionsByProfileID
            .removeAll()

        lastAccessSequenceByProfileID
            .removeAll()

        nextAccessSequence =
            0
    }

    private func removeCleanSessionsWithoutHistory(
        excluding protectedProfileID:
            UUID?
    ) -> Set<UUID> {
        var removableProfileIDs:
            Set<UUID> = []

        for (
            profileID,
            session
        ) in sessionsByProfileID {
            guard
                profileID
                    != protectedProfileID,
                !session.hasUnsavedChanges,
                session.historyEntryCount
                    == 0
            else {
                continue
            }

            removableProfileIDs.insert(
                profileID
            )
        }

        for profileID in
            removableProfileIDs
        {
            removeRetainedSession(
                for:
                    profileID
            )
        }

        return removableProfileIDs
    }

    private func removeLeastRecentlyUsedCleanSessionsExceedingBudget(
        excluding protectedProfileID:
            UUID?
    ) -> Set<UUID> {
        var retainedPayloadSize =
            totalEstimatedHistoryPayloadSize

        guard
            retainedPayloadSize
                > maximumRetainedEstimatedHistoryPayloadSize
        else {
            return []
        }

        let candidates =
            sessionsByProfileID
                .compactMap {
                    profileID,
                    session
                        -> (
                            profileID: UUID,
                            lastAccessSequence: UInt64,
                            estimatedHistoryPayloadSize: Int
                        )? in

                    guard
                        profileID
                            != protectedProfileID,
                        !session.hasUnsavedChanges,
                        session.historyEntryCount
                            > 0
                    else {
                        return nil
                    }

                    return (
                        profileID:
                            profileID,
                        lastAccessSequence:
                            lastAccessSequenceByProfileID[
                                profileID
                            ] ?? 0,
                        estimatedHistoryPayloadSize:
                            session
                                .estimatedHistoryPayloadSize
                    )
                }
                .sorted {
                    first,
                    second in

                    if first.lastAccessSequence
                        != second.lastAccessSequence
                    {
                        return first.lastAccessSequence
                            < second.lastAccessSequence
                    }

                    return first
                        .profileID
                        .uuidString
                        < second
                            .profileID
                            .uuidString
                }

        var removedProfileIDs:
            Set<UUID> = []

        for candidate in candidates {
            guard
                retainedPayloadSize
                    > maximumRetainedEstimatedHistoryPayloadSize
            else {
                break
            }

            removeRetainedSession(
                for:
                    candidate.profileID
            )

            retainedPayloadSize =
                max(
                    retainedPayloadSize
                        - candidate
                            .estimatedHistoryPayloadSize,
                    0
                )

            removedProfileIDs.insert(
                candidate.profileID
            )
        }

        return removedProfileIDs
    }

    private func removeRetainedSession(
        for profileID:
            UUID
    ) {
        sessionsByProfileID
            .removeValue(
                forKey:
                    profileID
            )

        lastAccessSequenceByProfileID
            .removeValue(
                forKey:
                    profileID
            )
    }

    private func recordAccess(
        to profileID:
            UUID
    ) {
        if nextAccessSequence
            == UInt64.max
        {
            compactAccessSequences()
        }

        lastAccessSequenceByProfileID[
            profileID
        ] =
            nextAccessSequence

        nextAccessSequence &+=
            1
    }

    /// Preserves relative LRU order if the monotonic counter ever reaches its
    /// maximum value during an exceptionally long-running process.
    private func compactAccessSequences() {
        let orderedProfileIDs =
            lastAccessSequenceByProfileID
                .sorted {
                    first,
                    second in

                    if first.value
                        != second.value
                    {
                        return first.value
                            < second.value
                    }

                    return first
                        .key
                        .uuidString
                        < second
                            .key
                            .uuidString
                }
                .map(
                    \.key
                )

        lastAccessSequenceByProfileID
            .removeAll(
                keepingCapacity:
                    true
            )

        for (
            index,
            profileID
        ) in orderedProfileIDs.enumerated() {
            lastAccessSequenceByProfileID[
                profileID
            ] =
                UInt64(
                    index
                )
        }

        nextAccessSequence =
            UInt64(
                orderedProfileIDs
                    .count
            )
    }
}
