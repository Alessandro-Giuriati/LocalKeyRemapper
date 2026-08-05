//
//  ProfileActivationFailurePresentation.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 8/5/26.
//

import Foundation

/// Produces consistent profile-activation conflict messages for Home and the
/// menu-bar popover.
///
/// Presentation remains separate from conflict detection and persistence. The
/// message includes the target profile, exact shortcut, shortcut action, source
/// configuration, recovery choices, and the unchanged runtime state.
nonisolated enum ProfileActivationFailurePresentation {

    static func message(
        for failure:
            ProfileActivationShortcutConflict,
        displayedProfileName:
            String? = nil
    ) -> String {
        let profileName =
            displayedProfileName
                ?? failure.persistedProfileName

        let shortcutName =
            KeyCombinationDisplayName
                .name(
                    for:
                        failure
                            .conflict
                            .shortcut
                )

        switch failure.shortcutSource {
        case .defaultGlobal:
            return "“\(profileName)” wasn’t activated because one of its rules conflicts with the Default Global Shortcut “\(failure.conflict.shortcutTitle)” (\(shortcutName)). Change the default shortcut in Home or edit the conflicting rule in “\(profileName)”. The previous profile remains active."

        case .profileSpecific:
            return "“\(profileName)” wasn’t activated because one of its rules conflicts with its profile shortcut “\(failure.conflict.shortcutTitle)” (\(shortcutName)). Change the shortcut configured for “\(profileName)” or edit the conflicting rule. The previous profile remains active."
        }
    }
}
