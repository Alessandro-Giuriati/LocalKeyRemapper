//
//  ProfileRuleEditorSessionRegistry.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Retains one independent Rules editor session for each remapping profile.
///
/// Sessions are identified exclusively by the profile UUID. Closing or
/// rebinding the reusable Rules window therefore does not destroy a profile's
/// in-memory Undo/Redo history.
///
/// The registry stores editor state only in memory. It does not persist
/// keyboard input, editing history, or captured key presses.
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

    /// Returns the existing session for a profile or creates it lazily.
    ///
    /// Repeated requests using the same UUID return the same object, preserving
    /// that profile's draft, saved baseline, Undo stack, and Redo stack.
    func session(
        for profileID: UUID
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

    /// Removes the session belonging to one profile.
    ///
    /// This must be called only when profile deletion becomes committed.
    /// Removing a profile from an unsaved Home draft must not discard its
    /// Rules history prematurely.
    func removeSession(
        for profileID: UUID
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
