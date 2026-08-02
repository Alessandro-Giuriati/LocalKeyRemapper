//
//  HomeProfilesPresentationModelTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import Foundation
import XCTest
@testable import LocalKeyRemapper

final class HomeProfilesPresentationModelTests:
    XCTestCase
{
    func testSearchUsesCaseInsensitiveContainment() {
        var model =
            HomeProfilesPresentationModel()
        model.searchText =
            "ale"

        let profiles = [
            makeProfile(
                name:
                    "Ale"
            ),
            makeProfile(
                name:
                    "ale"
            ),
            makeProfile(
                name:
                    "ALE"
            ),
            makeProfile(
                name:
                    "alE"
            ),
            makeProfile(
                name:
                    "Gaming"
            )
        ]

        XCTAssertEqual(
            Set(
                model.visibleProfiles(
                    from:
                        profiles
                )
                .map(
                    \.name
                )
            ),
            Set(
                [
                    "Ale",
                    "ale",
                    "ALE",
                    "alE"
                ]
            )
        )
    }

    func testNameSortingIsDeterministicForCaseVariants() {
        var model =
            HomeProfilesPresentationModel()
        model.sortKey =
            .name
        model.sortDirection =
            .ascending

        let profiles = [
            makeProfile(
                id:
                    fixedUUID(
                        "00000000-0000-0000-0000-000000000004"
                    ),
                name:
                    "alE"
            ),
            makeProfile(
                id:
                    fixedUUID(
                        "00000000-0000-0000-0000-000000000002"
                    ),
                name:
                    "ale"
            ),
            makeProfile(
                id:
                    fixedUUID(
                        "00000000-0000-0000-0000-000000000003"
                    ),
                name:
                    "ALE"
            ),
            makeProfile(
                id:
                    fixedUUID(
                        "00000000-0000-0000-0000-000000000001"
                    ),
                name:
                    "Ale"
            )
        ]

        let firstResult =
            model.visibleProfiles(
                from:
                    profiles
            )
            .map(
                \.id
            )

        let secondResult =
            model.visibleProfiles(
                from:
                    Array(
                        profiles.reversed()
                    )
            )
            .map(
                \.id
            )

        XCTAssertEqual(
            firstResult,
            secondResult
        )
    }

    func testCreationDateSortingSupportsBothDirections() {
        let oldest =
            makeProfile(
                name:
                    "Oldest",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            100
                    )
            )
        let middle =
            makeProfile(
                name:
                    "Middle",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            200
                    )
            )
        let newest =
            makeProfile(
                name:
                    "Newest",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            300
                    )
            )

        var model =
            HomeProfilesPresentationModel(
                sortKey:
                    .creationDate,
                sortDirection:
                    .ascending
            )

        XCTAssertEqual(
            model.visibleProfiles(
                from:
                    [
                        middle,
                        newest,
                        oldest
                    ]
            )
            .map(
                \.name
            ),
            [
                "Oldest",
                "Middle",
                "Newest"
            ]
        )

        model.toggleSort(
            .creationDate
        )

        XCTAssertEqual(
            model.visibleProfiles(
                from:
                    [
                        middle,
                        newest,
                        oldest
                    ]
            )
            .map(
                \.name
            ),
            [
                "Newest",
                "Middle",
                "Oldest"
            ]
        )
    }

    private func makeProfile(
        id:
            UUID = UUID(),
        name:
            String,
        createdAt:
            Date = Date()
    ) -> RemappingProfile {
        RemappingProfile(
            id:
                id,
            name:
                name,
            createdAt:
                createdAt
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
