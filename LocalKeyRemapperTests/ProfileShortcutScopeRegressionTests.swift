//
//  ProfileShortcutScopeRegressionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import CoreGraphics
import Foundation
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class ProfileShortcutScopeRegressionTests:
    XCTestCase
{
    func testRulesWindowSeesShortcutsOnlyForActiveProfile() {
        let activeProfile =
            makeProfile(
                name:
                    "Active"
            )

        let inactiveProfile =
            makeProfile(
                name:
                    "Inactive"
            )

        let profilesStore =
            ControllerMockRulesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            activeProfile,
                            inactiveProfile
                        ],
                        activeProfileID:
                            activeProfile.id
                    )
            )

        let defaultShortcut =
            RemappingShortcutConfiguration
                .toggle(
                    shortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        let initialPreferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    defaultShortcut
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    ShortcutScopePreferencesStore(
                        preferences:
                            initialPreferences
                    ),
                initialPreferences:
                    initialPreferences
            )

        let scopedController =
            RulesWindowAppPreferencesController(
                baseController:
                    preferencesController,
                profilesStore:
                    profilesStore
            )

        scopedController.profileID =
            inactiveProfile.id

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            .disabled
        )

        scopedController.profileID =
            activeProfile.id

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            defaultShortcut
        )
    }

    func testRulesWindowUsesProposedHomeActiveProfileAndShortcut() {
        let persistedActiveProfile =
            makeProfile(
                name:
                    "Persisted Active"
            )

        let proposedActiveProfile =
            makeProfile(
                name:
                    "Proposed Active"
            )

        let profilesStore =
            ControllerMockRulesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            persistedActiveProfile,
                            proposedActiveProfile
                        ],
                        activeProfileID:
                            persistedActiveProfile.id
                    )
            )

        let initialPreferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    .disabled
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    ShortcutScopePreferencesStore(
                        preferences:
                            initialPreferences
                    ),
                initialPreferences:
                    initialPreferences
            )

        let proposedShortcut =
            RemappingShortcutConfiguration
                .toggle(
                    shortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        let proposedConfiguration =
            RemappingProfilesConfiguration(
                profiles: [
                    persistedActiveProfile,
                    proposedActiveProfile
                ],
                activeProfileID:
                    proposedActiveProfile.id
            )

        let scopedController =
            RulesWindowAppPreferencesController(
                baseController:
                    preferencesController,
                profilesStore:
                    profilesStore
            )

        scopedController
            .homeProfilesConfigurationProvider = {
                proposedConfiguration
            }

        scopedController
            .homeShortcutConfigurationProvider = {
                proposedShortcut
            }

        scopedController.profileID =
            proposedActiveProfile.id

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            proposedShortcut
        )
    }

    func testRulesWindowIgnoresProposedShortcutForInactiveHomeDraftProfile() {
        let activeProfile =
            makeProfile(
                name:
                    "Active"
            )

        let inactiveProfile =
            makeProfile(
                name:
                    "Inactive"
            )

        let profilesStore =
            ControllerMockRulesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            activeProfile,
                            inactiveProfile
                        ],
                        activeProfileID:
                            activeProfile.id
                    )
            )

        let initialPreferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    .disabled
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    ShortcutScopePreferencesStore(
                        preferences:
                            initialPreferences
                    ),
                initialPreferences:
                    initialPreferences
            )

        let scopedController =
            RulesWindowAppPreferencesController(
                baseController:
                    preferencesController,
                profilesStore:
                    profilesStore
            )

        scopedController
            .homeProfilesConfigurationProvider = {
                RemappingProfilesConfiguration(
                    profiles: [
                        activeProfile,
                        inactiveProfile
                    ],
                    activeProfileID:
                        activeProfile.id
                )
            }

        scopedController
            .homeShortcutConfigurationProvider = {
                .toggle(
                    self.shortcut(
                        keyCode:
                            KeyCode.r
                    )
                )
            }

        scopedController.profileID =
            inactiveProfile.id

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            .disabled
        )
    }

    func testRulesWindowReadsUpdatedHomeDraftWithoutBeingRecreated() {
        let profile =
            makeProfile(
                name:
                    "Profile"
            )

        let profilesStore =
            ControllerMockRulesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        let initialPreferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    .disabled
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    ShortcutScopePreferencesStore(
                        preferences:
                            initialPreferences
                    ),
                initialPreferences:
                    initialPreferences
            )

        let scopedController =
            RulesWindowAppPreferencesController(
                baseController:
                    preferencesController,
                profilesStore:
                    profilesStore
            )

        let draftProfiles =
            RemappingProfilesConfiguration(
                profiles: [
                    profile
                ],
                activeProfileID:
                    profile.id
            )

        var draftShortcut:
            RemappingShortcutConfiguration =
                .disabled

        scopedController
            .homeProfilesConfigurationProvider = {
                draftProfiles
            }

        scopedController
            .homeShortcutConfigurationProvider = {
                draftShortcut
            }

        scopedController.profileID =
            profile.id

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            .disabled
        )

        let updatedShortcut =
            RemappingShortcutConfiguration
                .toggle(
                    shortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        draftShortcut =
            updatedShortcut

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            updatedShortcut
        )
    }

    func testSavingInactiveProfileAllowsExactShortcutOverlap()
        throws
    {
        let activeProfile =
            makeProfile(
                name:
                    "Active",
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ]
            )

        let inactiveProfile =
            makeProfile(
                name:
                    "Inactive"
            )

        let profilesStore =
            ControllerMockRulesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            activeProfile,
                            inactiveProfile
                        ],
                        activeProfileID:
                            activeProfile.id
                    )
            )

        let reservedShortcut =
            shortcut(
                keyCode:
                    KeyCode.r
            )

        let controller =
            makeController(
                profilesStore:
                    profilesStore,
                shortcutConfiguration:
                    .toggle(
                        reservedShortcut
                    )
            )

        let overlappingRules = [
            RemapRule(
                source:
                    reservedShortcut,
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.j
                    )
            )
        ]

        try controller.replaceConfiguredRules(
            overlappingRules,
            for:
                inactiveProfile.id
        )

        XCTAssertEqual(
            profilesStore
                .savedConfiguration?
                .profile(
                    id:
                        inactiveProfile.id
                )?
                .rules,
            overlappingRules
        )
    }

    func testSavingActiveProfileStillRejectsExactShortcutOverlap() {
        let activeProfile =
            makeProfile(
                name:
                    "Active"
            )

        let profilesStore =
            ControllerMockRulesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            activeProfile
                        ],
                        activeProfileID:
                            activeProfile.id
                    )
            )

        let reservedShortcut =
            shortcut(
                keyCode:
                    KeyCode.r
            )

        let controller =
            makeController(
                profilesStore:
                    profilesStore,
                shortcutConfiguration:
                    .toggle(
                        reservedShortcut
                    )
            )

        let overlappingRules = [
            RemapRule(
                source:
                    reservedShortcut,
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.j
                    )
            )
        ]

        XCTAssertThrowsError(
            try controller.replaceConfiguredRules(
                overlappingRules,
                for:
                    activeProfile.id
            )
        ) {
            error in

            XCTAssertNotNil(
                error as? RemappingShortcutRuleConflict
            )
        }

        XCTAssertNil(
            profilesStore.savedConfiguration
        )
    }

    private func makeController(
        profilesStore:
            ControllerMockRulesStore,
        shortcutConfiguration:
            RemappingShortcutConfiguration
    ) -> RemappingController {
        RemappingController(
            permissionService:
                ControllerMockPermissionService(
                    isGranted:
                        true
                ),
            profilesStore:
                profilesStore,
            rulesValidator:
                RemappingRulesValidator(),
            remappingEngine:
                RemappingEngine(),
            eventTapManager:
                ControllerMockEventTapManager(),
            shortcutConfigurationProvider: {
                shortcutConfiguration
            }
        )
    }

    private func makeProfile(
        name:
            String,
        rules:
            [RemapRule] = []
    ) -> RemappingProfile {
        RemappingProfile(
            id:
                UUID(),
            name:
                name,
            createdAt:
                Date(
                    timeIntervalSince1970:
                        1_700_000_000
                ),
            rules:
                rules
        )
    }

    private func shortcut(
        keyCode:
            CGKeyCode
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
}

@MainActor
private final class ShortcutScopePreferencesStore:
    AppPreferencesStore
{
    private var preferences:
        AppPreferences

    init(
        preferences:
            AppPreferences
    ) {
        self.preferences =
            preferences
    }

    func loadPreferences()
        throws -> AppPreferences
    {
        preferences
    }

    func savePreferences(
        _ preferences:
            AppPreferences
    ) throws {
        self.preferences =
            preferences
    }
}
