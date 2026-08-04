//
//  RevisionBoundValueCacheTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/4/26.
//

import XCTest
@testable import LocalKeyRemapper

final class RevisionBoundValueCacheTests:
    XCTestCase
{
    func testReturnsStoredValueForMatchingRevisions() {
        var cache =
            RevisionBoundValueCache<String>()

        cache.store(
            "assessment",
            contentRevision:
                4,
            dependencyRevision:
                2
        )

        XCTAssertEqual(
            cache.cachedValue(
                contentRevision:
                    4,
                dependencyRevision:
                    2
            ),
            "assessment"
        )
    }

    func testContentRevisionChangeInvalidatesLookup() {
        var cache =
            RevisionBoundValueCache<Int>()

        cache.store(
            12,
            contentRevision:
                7
        )

        XCTAssertNil(
            cache.cachedValue(
                contentRevision:
                    8
            )
        )
    }

    func testDependencyRevisionChangeInvalidatesLookup() {
        var cache =
            RevisionBoundValueCache<Int>()

        cache.store(
            12,
            contentRevision:
                7,
            dependencyRevision:
                3
        )

        XCTAssertNil(
            cache.cachedValue(
                contentRevision:
                    7,
                dependencyRevision:
                    4
            )
        )
    }

    func testInvalidateReleasesMatchingEntry() {
        var cache =
            RevisionBoundValueCache<[Int]>()

        cache.store(
            [
                1,
                2,
                3
            ],
            contentRevision:
                1
        )

        cache.invalidate()

        XCTAssertNil(
            cache.cachedValue(
                contentRevision:
                    1
            )
        )
    }

    func testStoreReplacesPreviousRevisionsAndValue() {
        var cache =
            RevisionBoundValueCache<String>()

        cache.store(
            "old",
            contentRevision:
                1,
            dependencyRevision:
                1
        )

        cache.store(
            "new",
            contentRevision:
                2,
            dependencyRevision:
                3
        )

        XCTAssertNil(
            cache.cachedValue(
                contentRevision:
                    1,
                dependencyRevision:
                    1
            )
        )

        XCTAssertEqual(
            cache.cachedValue(
                contentRevision:
                    2,
                dependencyRevision:
                    3
            ),
            "new"
        )
    }
}
