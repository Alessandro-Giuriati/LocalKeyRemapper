//
//  HomeProfilesConfigurationMerger.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import Foundation

/// Combines profile metadata, shortcut overrides, and remembered custom
/// shortcuts edited in Home with the latest rules persisted by the independent
/// Rules windows.
///
/// Home owns profile creation, deletion, ordering, names, shortcut overrides,
/// shortcut memory, and the active UUID. Rules windows own each existing
/// profile's persisted rule collection. Keeping those responsibilities separate
/// prevents a Home Save from overwriting a newer Rules Save performed while
/// Home remained open.
nonisolated enum HomeProfilesConfigurationMerger {

    /// Returns the configuration that should participate in a Home Save.
    ///
    /// Existing profile UUIDs keep the latest persisted rules and original
    /// creation date. Home metadata, shortcut overrides, and shortcut memory
    /// remain authoritative. Profiles created only in the Home draft keep their
    /// complete draft data, while profiles deleted from the Home draft remain
    /// absent.
    static func merging(
        homeDraft:
            RemappingProfilesConfiguration,
        persisted:
            RemappingProfilesConfiguration
    ) -> RemappingProfilesConfiguration {
        let persistedProfilesByID =
            Dictionary(
                uniqueKeysWithValues:
                    persisted.profiles.map {
                        ($0.id, $0)
                    }
            )

        let mergedProfiles =
            homeDraft.profiles.map {
                draftProfile -> RemappingProfile in

                guard
                    let persistedProfile =
                        persistedProfilesByID[
                            draftProfile.id
                        ]
                else {
                    return draftProfile
                }

                return RemappingProfile(
                    id:
                        draftProfile.id,
                    name:
                        draftProfile.name,
                    createdAt:
                        persistedProfile.createdAt,
                    updatedAt:
                        max(
                            draftProfile.updatedAt,
                            persistedProfile.updatedAt
                        ),
                    rules:
                        persistedProfile.rules,
                    shortcutConfigurationOverride:
                        draftProfile
                            .shortcutConfigurationOverride,
                    shortcutMemory:
                        draftProfile
                            .shortcutMemory
                )
            }

        return RemappingProfilesConfiguration(
            profiles:
                mergedProfiles,
            activeProfileID:
                homeDraft.activeProfileID
        )
    }
}
