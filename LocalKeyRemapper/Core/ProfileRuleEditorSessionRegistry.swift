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
/// A session is retained when it belongs to the currently displayed profile,
/// contains unsaved changes, or still owns Undo/Redo history. Clean inactive
/// sessions with no history can be released and recreated lazily from the
/// profile configuration when needed again.
///
/// The registry stores editor state only in memory. It does not persist,
/// log, or transmit keyboard input, editing history, or captured key presses.
@MainActor
final class ProfileRuleEditorSessionRegistry {

    private var sessionsByProfileID:
        [UUID: RemappingRuleEditorSession] = [:]

    private let sessionFactory:
        () -> RemappingRuleEditorSession

    init(
        sessionFactory:
            @escaping () -> RemappingRuleEditorSession = {
                RemappingRuleEditorSession()
            }
    ) {
        self.sessionFactory =
            sessionFactory
    }

    /// IDs belonging to initialized sessions that currently contain unsaved
    /// Rules changes.
    ///
    /// Reading this value never creates a new session.
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

    /// Returns the existing session for a profile or creates it lazily.
    ///
    /// Repeated requests using the same UUID return the same object while that
    /// session remains retained.
    func session(
        for profileID:
            UUID
    ) -> RemappingRuleEditorSession {
        if let existingSession =
            sessionsByProfileID[
                profileID
            ]
        {
            return existingSession
        }

        let newSession =
            sessionFactory()

        sessionsByProfileID[
            profileID
        ] =
            newSession

        return newSession
    }

    /// Releases inactive sessions that contain no user state worth preserving.
    ///
    /// A session is discardable only when:
    /// - it does not belong to the protected profile;
    /// - it contains no unsaved Rules changes;
    /// - it contains no Undo or Redo entries.
    ///
    /// The profile's persisted Rules remain available through the profiles
    /// configuration and will initialize a new session when needed again.
    @discardableResult
    func removeDiscardableSessions(
        excluding protectedProfileID:
            UUID? = nil
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
            sessionsByProfileID
                .removeValue(
                    forKey:
                        profileID
                )
        }

        return removableProfileIDs
    }

    /// Removes the session belonging to one permanently deleted profile.
    ///
    /// This must be called only when profile deletion becomes committed.
    func removeSession(
        for profileID:
            UUID
    ) {
        sessionsByProfileID
            .removeValue(
                forKey:
                    profileID
            )
    }

    /// Releases every retained session during application termination.
    func removeAllSessions() {
        sessionsByProfileID
            .removeAll()
    }
}
