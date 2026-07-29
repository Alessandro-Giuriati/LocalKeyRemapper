//
//  HomeConfigurationSnapshot.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Represents the complete configuration edited by the Home window.
///
/// The snapshot contains only application settings that participate in the
/// unified Home Save and Undo/Redo workflow. Presentation-only state such as
/// search text, sorting, row selection, and scrolling is intentionally absent.
///
/// Interface preferences that still save independently, such as menu bar
/// visibility, rule-removal confirmation, and interface text size, are also
/// intentionally outside this model.
nonisolated struct HomeConfigurationSnapshot:
    Equatable
{
    /// Every remapping profile and the profile selected for runtime use.
    var profilesConfiguration:
        RemappingProfilesConfiguration

    /// Application-wide launch behavior edited from Home.
    var launchBehavior:
        RemappingLaunchBehavior

    /// Application-wide global shortcut configuration edited from Home.
    var shortcutConfiguration:
        RemappingShortcutConfiguration

    init(
        profilesConfiguration:
            RemappingProfilesConfiguration,
        launchBehavior:
            RemappingLaunchBehavior,
        shortcutConfiguration:
            RemappingShortcutConfiguration
    ) {
        self.profilesConfiguration =
            profilesConfiguration

        self.launchBehavior =
            launchBehavior

        self.shortcutConfiguration =
            shortcutConfiguration
    }

    /// Profiles in their persistent collection order.
    var profiles:
        [RemappingProfile]
    {
        get {
            profilesConfiguration
                .profiles
        }

        set {
            profilesConfiguration
                .profiles =
                    newValue
        }
    }

    /// Stable identity of the profile proposed for runtime use after Home Save.
    var activeProfileID:
        UUID
    {
        get {
            profilesConfiguration
                .activeProfileID
        }

        set {
            profilesConfiguration
                .activeProfileID =
                    newValue
        }
    }

    /// Returns the active draft profile when the snapshot is valid.
    var activeProfile:
        RemappingProfile?
    {
        profile(
            id:
                activeProfileID
        )
    }

    /// Resolves a profile using stable UUID identity.
    func profile(
        id profileID:
            UUID
    ) -> RemappingProfile? {
        profiles.first {
            $0.id == profileID
        }
    }
}
