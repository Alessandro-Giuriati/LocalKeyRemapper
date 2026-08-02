//
//  EffectiveRemappingShortcutConfigurationResolver.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation

/// Resolves the shortcut configuration that is effective for one profile.
///
/// Profile-specific configuration remains distinct from the application-wide
/// default:
///
/// - `nil` uses the default configuration;
/// - `.disabled` explicitly disables shortcuts for the profile;
/// - `.toggle` and `.separate` use the profile-specific configuration.
///
/// The resolver performs no persistence, registration, keyboard capture,
/// logging, networking, or event-time work.
nonisolated enum EffectiveRemappingShortcutConfigurationResolver {

    /// Resolves the effective configuration for one known profile.
    static func resolve(
        profile:
            RemappingProfile,
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) -> RemappingShortcutConfiguration {
        profile.shortcutConfigurationOverride
            ?? defaultConfiguration
    }

    /// Resolves the effective configuration for the active profile.
    ///
    /// An invalid active-profile UUID is surfaced instead of silently falling
    /// back to the application-wide default.
    static func resolveActiveProfile(
        in profilesConfiguration:
            RemappingProfilesConfiguration,
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) throws -> RemappingShortcutConfiguration {
        guard
            let activeProfile =
                profilesConfiguration.activeProfile
        else {
            throw RemappingProfilesConfigurationValidationError
                .missingActiveProfile(
                    profilesConfiguration.activeProfileID
                )
        }

        return resolve(
            profile:
                activeProfile,
            defaultConfiguration:
                defaultConfiguration
        )
    }
}
