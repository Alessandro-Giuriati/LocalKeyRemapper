//
//  HomeShortcutDraftAssessmentTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeShortcutDraftAssessmentTests:
    XCTestCase
{
    func testUseDefaultAssessesProposedDefaultAgainstActiveRules()
        throws
    {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makeExactRule(
                        source:
                            shortcut
                    )
                ],
                shortcutConfigurationOverride:
                    nil
            )

        let assessment =
            try HomeShortcutDraftAssessor
                .assessDefaultConfiguration(
                    .toggle(
                        shortcut
                    ),
                    in:
                        makeConfiguration(
                            profiles: [
                                profile
                            ],
                            activeProfileID:
                                profile.id
                        )
                )

        XCTAssertEqual(
            assessment,
            .exactConflict(
                profileName:
                    "Gaming"
            )
        )

        XCTAssertNotNil(
            assessment.blockingMessage
        )

        XCTAssertNil(
            assessment.suggestionMessage
        )
    }

    func testExplicitOffOverridePreventsDefaultFromCreatingFalseConflict()
        throws
    {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makeExactRule(
                        source:
                            shortcut
                    )
                ],
                shortcutConfigurationOverride:
                    .disabled
            )

        let assessment =
            try HomeShortcutDraftAssessor
                .assessDefaultConfiguration(
                    .toggle(
                        shortcut
                    ),
                    in:
                        makeConfiguration(
                            profiles: [
                                profile
                            ],
                            activeProfileID:
                                profile.id
                        )
                )

        XCTAssertEqual(
            assessment,
            .clear
        )
    }

    func testCustomActiveOverrideIsAssessedInsteadOfProposedDefault()
        throws
    {
        let customShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let unrelatedDefault =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makeExactRule(
                        source:
                            customShortcut
                    )
                ],
                shortcutConfigurationOverride:
                    .toggle(
                        customShortcut
                    )
            )

        let assessment =
            try HomeShortcutDraftAssessor
                .assessDefaultConfiguration(
                    unrelatedDefault,
                    in:
                        makeConfiguration(
                            profiles: [
                                profile
                            ],
                            activeProfileID:
                                profile.id
                        )
                )

        XCTAssertEqual(
            assessment,
            .exactConflict(
                profileName:
                    "Gaming"
            )
        )
    }

    func testInactiveProfileOverrideIsNotComparedWithItsRules()
        throws
    {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let activeProfile =
            RemappingProfile(
                name:
                    "Active"
            )

        let inactiveProfile =
            RemappingProfile(
                name:
                    "Inactive",
                rules: [
                    makeExactRule(
                        source:
                            shortcut
                    )
                ]
            )

        let assessment =
            try HomeShortcutDraftAssessor
                .assessProfileOverride(
                    .toggle(
                        shortcut
                    ),
                    for:
                        inactiveProfile.id,
                    defaultConfiguration:
                        .disabled,
                    in:
                        makeConfiguration(
                            profiles: [
                                activeProfile,
                                inactiveProfile
                            ],
                            activeProfileID:
                                activeProfile.id
                        )
                )

        XCTAssertEqual(
            assessment,
            .clear
        )
    }

    func testActiveProfileOverrideConflictIsBlocking()
        throws
    {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makeExactRule(
                        source:
                            shortcut
                    )
                ]
            )

        let assessment =
            try HomeShortcutDraftAssessor
                .assessProfileOverride(
                    .toggle(
                        shortcut
                    ),
                    for:
                        profile.id,
                    defaultConfiguration:
                        .disabled,
                    in:
                        makeConfiguration(
                            profiles: [
                                profile
                            ],
                            activeProfileID:
                                profile.id
                        )
                )

        XCTAssertEqual(
            assessment,
            .exactConflict(
                profileName:
                    "Gaming"
            )
        )
    }

    func testActivePreserveRuleProducesNonBlockingWarning()
        throws
    {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makePreserveRule(
                        sourceKeyCode:
                            KeyCode.r
                    )
                ]
            )

        let assessment =
            try HomeShortcutDraftAssessor
                .assessProfileOverride(
                    .toggle(
                        shortcut
                    ),
                    for:
                        profile.id,
                    defaultConfiguration:
                        .disabled,
                    in:
                        makeConfiguration(
                            profiles: [
                                profile
                            ],
                            activeProfileID:
                                profile.id
                        )
                )

        XCTAssertEqual(
            assessment,
            .preserveWarning(
                profileName:
                    "Gaming"
            )
        )

        XCTAssertNil(
            assessment.blockingMessage
        )

        XCTAssertNotNil(
            assessment.suggestionMessage
        )
    }

    func testMissingTargetProfileIsRejected() {
        let existingProfile =
            RemappingProfile(
                name:
                    "Existing"
            )

        let missingProfileID =
            fixedUUID(
                "A74921AB-2888-41EF-9E7C-A6E7BB553CE6"
            )

        let configuration =
            makeConfiguration(
                profiles: [
                    existingProfile
                ],
                activeProfileID:
                    existingProfile.id
            )

        XCTAssertThrowsError(
            try HomeShortcutDraftAssessor
                .assessProfileOverride(
                    .disabled,
                    for:
                        missingProfileID,
                    defaultConfiguration:
                        .disabled,
                    in:
                        configuration
                )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    RemappingProfileRulesAccessError,
                .profileNotFound(
                    missingProfileID
                )
            )
        }
    }

    func testMissingActiveProfileIsRejected() {
        let existingProfile =
            RemappingProfile(
                name:
                    "Existing"
            )

        let missingProfileID =
            fixedUUID(
                "3FA66D06-69AB-4359-81F5-E46370010466"
            )

        let configuration =
            makeConfiguration(
                profiles: [
                    existingProfile
                ],
                activeProfileID:
                    missingProfileID
            )

        XCTAssertThrowsError(
            try HomeShortcutDraftAssessor
                .assessDefaultConfiguration(
                    .disabled,
                    in:
                        configuration
                )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    RemappingProfilesConfigurationValidationError,
                .missingActiveProfile(
                    missingProfileID
                )
            )
        }
    }

    private func makeConfiguration(
        profiles:
            [RemappingProfile],
        activeProfileID:
            UUID
    ) -> RemappingProfilesConfiguration {
        RemappingProfilesConfiguration(
            profiles:
                profiles,
            activeProfileID:
                activeProfileID
        )
    }

    private func makeToggleConfiguration(
        keyCode:
            CGKeyCode
    ) -> RemappingShortcutConfiguration {
        .toggle(
            makeShortcut(
                keyCode:
                    keyCode
            )
        )
    }

    private func makeShortcut(
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

    private func makeExactRule(
        source:
            KeyCombination
    ) -> RemapRule {
        RemapRule(
            source:
                source,
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w,
                    modifiers:
                        source.modifiers
                ),
            matchingMode:
                .exact
        )
    }

    private func makePreserveRule(
        sourceKeyCode:
            CGKeyCode
    ) -> RemapRule {
        RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        sourceKeyCode
                ),
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w
                ),
            matchingMode:
                .preserveModifiers
        )
    }

    private func fixedUUID(
        _ value:
            String
    ) -> UUID {
        UUID(
            uuidString:
                value
        )!
    }
}
