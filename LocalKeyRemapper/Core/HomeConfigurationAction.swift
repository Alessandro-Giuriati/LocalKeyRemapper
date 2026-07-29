//
//  HomeConfigurationAction.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Represents one reversible change made through the Home window.
///
/// Profile actions use stable UUID identity and store only the data required to
/// reverse that specific edit. Rule-editor changes are deliberately excluded:
/// every profile keeps its own independent Rules Undo/Redo history.
nonisolated enum HomeConfigurationAction:
    Equatable
{
    case setLaunchBehavior(
        before: RemappingLaunchBehavior,
        after: RemappingLaunchBehavior
    )

    case setShortcutConfiguration(
        before: RemappingShortcutConfiguration,
        after: RemappingShortcutConfiguration
    )

    case addProfile(
        profile: RemappingProfile,
        index: Int
    )

    case removeProfile(
        profile: RemappingProfile,
        index: Int
    )

    case renameProfile(
        profileID: UUID,
        beforeName: String,
        afterName: String,
        beforeUpdatedAt: Date,
        afterUpdatedAt: Date
    )

    case setActiveProfile(
        before: UUID,
        after: UUID
    )

    /// Restores or reapplies a complete Home snapshot as one reversible action.
    ///
    /// Normal edits should use the narrower cases above. This case is reserved
    /// for operations such as restoring the saved Home baseline.
    case replaceAll(
        before: HomeConfigurationSnapshot,
        after: HomeConfigurationSnapshot
    )

    /// Deterministic estimate used to bound session-only history memory.
    ///
    /// The value intentionally estimates logical payload rather than claiming
    /// to represent Swift's exact heap allocation.
    var estimatedPayloadSize:
        Int
    {
        let actionOverhead =
            32

        switch self {
        case .setLaunchBehavior:
            return actionOverhead
                + 2 * MemoryLayout<Int>.size

        case .setShortcutConfiguration(
            let before,
            let after
        ):
            return actionOverhead
                + Self.estimatedSize(
                    of:
                        before
                )
                + Self.estimatedSize(
                    of:
                        after
                )

        case .addProfile(
            let profile,
            _
        ),
        .removeProfile(
            let profile,
            _
        ):
            return actionOverhead
                + Self.estimatedSize(
                    of:
                        profile
                )
                + MemoryLayout<Int>.size

        case .renameProfile(
            _,
            let beforeName,
            let afterName,
            _,
            _
        ):
            return actionOverhead
                + MemoryLayout<UUID>.size
                + beforeName.utf8.count
                + afterName.utf8.count
                + 2 * MemoryLayout<Date>.size

        case .setActiveProfile:
            return actionOverhead
                + 2 * MemoryLayout<UUID>.size

        case .replaceAll(
            let before,
            let after
        ):
            return actionOverhead
                + Self.estimatedSize(
                    of:
                        before
                )
                + Self.estimatedSize(
                    of:
                        after
                )
        }
    }

    func applyingUndo(
        to currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        switch self {
        case .setLaunchBehavior(
            let before,
            _
        ):
            return Self.settingLaunchBehavior(
                before,
                in:
                    currentSnapshot
            )

        case .setShortcutConfiguration(
            let before,
            _
        ):
            return Self.settingShortcutConfiguration(
                before,
                in:
                    currentSnapshot
            )

        case .addProfile(
            let profile,
            _
        ):
            return Self.removingProfile(
                id:
                    profile.id,
                from:
                    currentSnapshot
            )

        case .removeProfile(
            let profile,
            let index
        ):
            return Self.insertingProfile(
                profile,
                at:
                    index,
                into:
                    currentSnapshot
            )

        case .renameProfile(
            let profileID,
            let beforeName,
            _,
            let beforeUpdatedAt,
            _
        ):
            return Self.renamingProfile(
                id:
                    profileID,
                to:
                    beforeName,
                updatedAt:
                    beforeUpdatedAt,
                in:
                    currentSnapshot
            )

        case .setActiveProfile(
            let before,
            _
        ):
            return Self.settingActiveProfile(
                before,
                in:
                    currentSnapshot
            )

        case .replaceAll(
            let before,
            _
        ):
            return before
        }
    }

    func applyingRedo(
        to currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        switch self {
        case .setLaunchBehavior(
            _,
            let after
        ):
            return Self.settingLaunchBehavior(
                after,
                in:
                    currentSnapshot
            )

        case .setShortcutConfiguration(
            _,
            let after
        ):
            return Self.settingShortcutConfiguration(
                after,
                in:
                    currentSnapshot
            )

        case .addProfile(
            let profile,
            let index
        ):
            return Self.insertingProfile(
                profile,
                at:
                    index,
                into:
                    currentSnapshot
            )

        case .removeProfile(
            let profile,
            _
        ):
            return Self.removingProfile(
                id:
                    profile.id,
                from:
                    currentSnapshot
            )

        case .renameProfile(
            let profileID,
            _,
            let afterName,
            _,
            let afterUpdatedAt
        ):
            return Self.renamingProfile(
                id:
                    profileID,
                to:
                    afterName,
                updatedAt:
                    afterUpdatedAt,
                in:
                    currentSnapshot
            )

        case .setActiveProfile(
            _,
            let after
        ):
            return Self.settingActiveProfile(
                after,
                in:
                    currentSnapshot
            )

        case .replaceAll(
            _,
            let after
        ):
            return after
        }
    }

    private static func settingLaunchBehavior(
        _ launchBehavior:
            RemappingLaunchBehavior,
        in currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        var updatedSnapshot =
            currentSnapshot

        updatedSnapshot.launchBehavior =
            launchBehavior

        return updatedSnapshot
    }

    private static func settingShortcutConfiguration(
        _ shortcutConfiguration:
            RemappingShortcutConfiguration,
        in currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        var updatedSnapshot =
            currentSnapshot

        updatedSnapshot.shortcutConfiguration =
            shortcutConfiguration

        return updatedSnapshot
    }

    private static func insertingProfile(
        _ profile:
            RemappingProfile,
        at requestedIndex:
            Int,
        into currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        var updatedSnapshot =
            currentSnapshot

        if let existingIndex =
            updatedSnapshot
                .profiles
                .firstIndex(
                    where: {
                        $0.id == profile.id
                    }
                )
        {
            updatedSnapshot
                .profiles
                .remove(
                    at:
                        existingIndex
                )
        }

        let safeIndex =
            min(
                max(
                    requestedIndex,
                    0
                ),
                updatedSnapshot
                    .profiles
                    .count
            )

        updatedSnapshot
            .profiles
            .insert(
                profile,
                at:
                    safeIndex
            )

        return updatedSnapshot
    }

    private static func removingProfile(
        id profileID:
            UUID,
        from currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        var updatedSnapshot =
            currentSnapshot

        updatedSnapshot.profiles =
            updatedSnapshot
                .profiles
                .filter {
                    $0.id != profileID
                }

        return updatedSnapshot
    }

    private static func renamingProfile(
        id profileID:
            UUID,
        to name:
            String,
        updatedAt:
            Date,
        in currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        var updatedSnapshot =
            currentSnapshot

        guard
            let profileIndex =
                updatedSnapshot
                    .profiles
                    .firstIndex(
                        where: {
                            $0.id == profileID
                        }
                    )
        else {
            return currentSnapshot
        }

        updatedSnapshot
            .profiles[
                profileIndex
            ]
            .name =
                name

        updatedSnapshot
            .profiles[
                profileIndex
            ]
            .updatedAt =
                updatedAt

        return updatedSnapshot
    }

    private static func settingActiveProfile(
        _ profileID:
            UUID,
        in currentSnapshot:
            HomeConfigurationSnapshot
    ) -> HomeConfigurationSnapshot {
        var updatedSnapshot =
            currentSnapshot

        updatedSnapshot.activeProfileID =
            profileID

        return updatedSnapshot
    }

    private static func estimatedSize(
        of snapshot:
            HomeConfigurationSnapshot
    ) -> Int {
        let snapshotOverhead =
            64

        return snapshotOverhead
            + snapshot.profiles.reduce(
                0
            ) {
                partialResult,
                profile in

                partialResult
                    + estimatedSize(
                        of:
                            profile
                    )
            }
            + estimatedSize(
                of:
                    snapshot.shortcutConfiguration
            )
    }

    private static func estimatedSize(
        of profile:
            RemappingProfile
    ) -> Int {
        let profileOverhead =
            96

        return profileOverhead
            + profile.name.utf8.count
            + profile.rules.reduce(
                0
            ) {
                partialResult,
                rule in

                partialResult
                    + estimatedSize(
                        of:
                            rule
                    )
            }
    }

    private static func estimatedSize(
        of rule:
            RemapRule
    ) -> Int {
        let ruleOverhead =
            96

        let overrideEstimate =
            48

        return ruleOverhead
            + rule.overrides.count
                * overrideEstimate
    }

    private static func estimatedSize(
        of shortcutConfiguration:
            RemappingShortcutConfiguration
    ) -> Int {
        let configurationOverhead =
            24

        let shortcutEstimate =
            16

        switch shortcutConfiguration {
        case .disabled:
            return configurationOverhead

        case .toggle:
            return configurationOverhead
                + shortcutEstimate

        case .separate:
            return configurationOverhead
                + 2 * shortcutEstimate
        }
    }
}
