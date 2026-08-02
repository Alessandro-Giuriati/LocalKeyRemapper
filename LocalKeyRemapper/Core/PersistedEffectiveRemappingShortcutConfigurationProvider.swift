//
//  PersistedEffectiveRemappingShortcutConfigurationProvider.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation

/// Resolves the shortcut configuration currently persisted for the active
/// remapping profile.
///
/// The provider loads the profiles configuration on every resolution and reads
/// the current application-wide default through its injected closure. It
/// therefore never caches a stale active profile, override, or default.
///
/// This component performs no keyboard capture, Carbon registration, event
/// processing, logging, networking, analytics, or telemetry.
@MainActor
final class PersistedEffectiveRemappingShortcutConfigurationProvider {

    private let profilesStore:
        RemappingProfilesStore

    private let defaultConfigurationProvider:
        () -> RemappingShortcutConfiguration

    init(
        profilesStore:
            RemappingProfilesStore,
        defaultConfigurationProvider:
            @escaping () -> RemappingShortcutConfiguration
    ) {
        self.profilesStore =
            profilesStore

        self.defaultConfigurationProvider =
            defaultConfigurationProvider
    }

    /// Returns the effective shortcut configuration for the active persisted
    /// profile.
    ///
    /// A missing active profile is surfaced rather than silently falling back
    /// to the application-wide default.
    func configuration()
        throws -> RemappingShortcutConfiguration
    {
        let profilesConfiguration =
            try profilesStore
                .loadConfiguration()

        return try EffectiveRemappingShortcutConfigurationResolver
            .resolveActiveProfile(
                in:
                    profilesConfiguration,
                defaultConfiguration:
                    defaultConfigurationProvider()
            )
    }
}
