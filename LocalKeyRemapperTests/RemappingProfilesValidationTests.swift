//
//  RemappingProfilesValidationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import XCTest

@testable import LocalKeyRemapper

@MainActor
final class RemappingProfilesValidationTests:
    XCTestCase
{
    private let validator =
        RemappingProfilesConfigurationValidator()

    func testNormalizedProfileNameTrimsSurroundingWhitespace() throws {
        let normalizedName =
            try validator.normalizedProfileName(
                "  Gaming  "
            )

        XCTAssertEqual(
            normalizedName,
            "Gaming"
        )
    }

    func testNormalizedProfileNameRejectsWhitespaceOnlyName() {
        XCTAssertThrowsError(
            try validator.normalizedProfileName(
                "     "
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfileNameValidationError,
                .empty
            )
        }
    }

    func testNormalizedProfileNameRejectsLineBreaks() {
        XCTAssertThrowsError(
            try validator.normalizedProfileName(
                "Gaming\nProfile"
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfileNameValidationError,
                .containsForbiddenCharacter
            )
        }
    }

    func testNormalizedProfileNameRejectsTabs() {
        XCTAssertThrowsError(
            try validator.normalizedProfileName(
                "Gaming\tProfile"
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfileNameValidationError,
                .containsForbiddenCharacter
            )
        }
    }

    func testConfigurationRejectsEmptyProfileCollection() {
        let configuration =
            RemappingProfilesConfiguration(
                profiles: [],
                activeProfileID:
                    UUID()
            )

        XCTAssertThrowsError(
            try validator.validate(
                configuration
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfilesConfigurationValidationError,
                .noProfiles
            )
        }
    }

    func testConfigurationRejectsDuplicateProfileIDs() {
        let duplicatedID =
            UUID(
                uuidString:
                    "09A3CF00-25BD-4E2A-8587-E705C10F3818"
            )!

        let firstProfile =
            makeProfile(
                id:
                    duplicatedID,
                name:
                    "Gaming"
            )

        let secondProfile =
            makeProfile(
                id:
                    duplicatedID,
                name:
                    "Work"
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    firstProfile,
                    secondProfile
                ],
                activeProfileID:
                    duplicatedID
            )

        XCTAssertThrowsError(
            try validator.validate(
                configuration
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfilesConfigurationValidationError,
                .duplicateProfileID(
                    duplicatedID
                )
            )
        }
    }

    func testConfigurationRejectsMissingActiveProfile() {
        let profileID =
            UUID(
                uuidString:
                    "20C88EA0-A567-463F-A39B-1868838A93D7"
            )!

        let missingActiveProfileID =
            UUID(
                uuidString:
                    "65545997-F46E-440A-BC3E-E3BBDAF4ECF3"
            )!

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            profileID,
                        name:
                            "Gaming"
                    )
                ],
                activeProfileID:
                    missingActiveProfileID
            )

        XCTAssertThrowsError(
            try validator.validate(
                configuration
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfilesConfigurationValidationError,
                .missingActiveProfile(
                    missingActiveProfileID
                )
            )
        }
    }

    func testConfigurationRejectsInvalidProfileName() {
        let profileID =
            UUID(
                uuidString:
                    "F48D0768-3A42-4BF8-9968-A7EB686D550E"
            )!

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            profileID,
                        name:
                            "Gaming\nProfile"
                    )
                ],
                activeProfileID:
                    profileID
            )

        XCTAssertThrowsError(
            try validator.validate(
                configuration
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfilesConfigurationValidationError,
                .invalidProfileName(
                    profileID:
                        profileID,
                    reason:
                        .containsForbiddenCharacter
                )
            )
        }
    }

    func testConfigurationRejectsDuplicateNormalizedNames() {
        let firstProfile =
            makeProfile(
                id:
                    UUID(
                        uuidString:
                            "FE64080A-EBD4-419A-971D-6AF0917DC213"
                    )!,
                name:
                    "Gaming"
            )

        let secondProfile =
            makeProfile(
                id:
                    UUID(
                        uuidString:
                            "DA86638B-86AA-49C2-B2E8-551499FBAA4B"
                    )!,
                name:
                    "  Gaming  "
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    firstProfile,
                    secondProfile
                ],
                activeProfileID:
                    firstProfile.id
            )

        XCTAssertThrowsError(
            try validator.validate(
                configuration
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfilesConfigurationValidationError,
                .duplicateProfileName(
                    "Gaming"
                )
            )
        }
    }

    func testConfigurationAllowsNamesThatDifferOnlyByLetterCase() throws {
        let firstProfile =
            makeProfile(
                id:
                    UUID(
                        uuidString:
                            "C8F65789-0711-41D6-A0A0-C1581BFD4874"
                    )!,
                name:
                    "Ale"
            )

        let secondProfile =
            makeProfile(
                id:
                    UUID(
                        uuidString:
                            "5E485EE2-B03C-456B-8DD9-B43FA4AD82CD"
                    )!,
                name:
                    "ale"
            )

        let thirdProfile =
            makeProfile(
                id:
                    UUID(
                        uuidString:
                            "90A2B610-3137-469C-A116-433E536669E6"
                    )!,
                name:
                    "ALE"
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    firstProfile,
                    secondProfile,
                    thirdProfile
                ],
                activeProfileID:
                    firstProfile.id
            )

        XCTAssertNoThrow(
            try validator.validate(
                configuration
            )
        )
    }

    func testNormalizedConfigurationReturnsTrimmedNames() throws {
        let profileID =
            UUID(
                uuidString:
                    "047EBC3D-8D1D-4D93-A8CB-490E6A1F761B"
            )!

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            profileID,
                        name:
                            "  Gaming  "
                    )
                ],
                activeProfileID:
                    profileID
            )

        let normalizedConfiguration =
            try validator.normalizedConfiguration(
                configuration
            )

        XCTAssertEqual(
            normalizedConfiguration.profiles[0].name,
            "Gaming"
        )

        XCTAssertEqual(
            configuration.profiles[0].name,
            "  Gaming  "
        )
    }

    private func makeProfile(
        id: UUID,
        name: String
    ) -> RemappingProfile {
        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        return RemappingProfile(
            id:
                id,
            name:
                name,
            createdAt:
                timestamp,
            updatedAt:
                timestamp
        )
    }
}
