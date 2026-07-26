//
//  BidirectionalRemappingPersistenceTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/26/26.
//

import CoreGraphics
import Foundation
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class BidirectionalRemappingPersistenceTests:
    XCTestCase
{
    func testSavingAndLoadingPreservesMixedBidirectionalStates()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let expectedRules = [
            makeRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isBidirectional:
                    true
            ),
            makeRule(
                source:
                    KeyCode.b,
                destination:
                    KeyCode.j,
                isBidirectional:
                    false
            ),
            makeRule(
                source:
                    KeyCode.n,
                destination:
                    KeyCode.r,
                isBidirectional:
                    true
            )
        ]

        let store =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        try store.saveRules(
            expectedRules
        )

        let loadedRules =
            try store.loadRules()

        XCTAssertEqual(
            loadedRules,
            expectedRules
        )

        XCTAssertEqual(
            loadedRules.map(
                \.isBidirectional
            ),
            [
                true,
                false,
                true
            ]
        )
    }

    func testNewStoreInstanceLoadsPreviouslySavedBidirectionalState()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let expectedRule =
            makeRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                matchingMode:
                    .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source:
                            KeyCombination(
                                keyCode:
                                    KeyCode.v,
                                modifiers:
                                    [.command]
                            ),
                        action:
                            .passThrough
                    )
                ],
                isBidirectional:
                    true
            )

        let firstStore =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        try firstStore.saveRules(
            [
                expectedRule
            ]
        )

        let reopenedStore =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        let reopenedRule =
            try XCTUnwrap(
                reopenedStore
                    .loadRules()
                    .first
            )

        XCTAssertEqual(
            reopenedRule,
            expectedRule
        )

        XCTAssertTrue(
            reopenedRule.isBidirectional
        )

        XCTAssertEqual(
            reopenedRule.overrides,
            expectedRule.overrides
        )
    }

    func testSavingReverseOffAfterReverseOnReplacesPersistedState()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let store =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        try store.saveRules(
            [
                makeRule(
                    source:
                        KeyCode.v,
                    destination:
                        KeyCode.w,
                    isBidirectional:
                        true
                )
            ]
        )

        XCTAssertTrue(
            try XCTUnwrap(
                store
                    .loadRules()
                    .first
            )
            .isBidirectional
        )

        try store.saveRules(
            [
                makeRule(
                    source:
                        KeyCode.v,
                    destination:
                        KeyCode.w,
                    isBidirectional:
                        false
                )
            ]
        )

        let reopenedStore =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        XCTAssertFalse(
            try XCTUnwrap(
                reopenedStore
                    .loadRules()
                    .first
            )
            .isBidirectional
        )
    }

    func testStoredAdvancedRuleWithoutBidirectionalFieldLoadsWithReverseOff()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let legacyRule =
            LegacyAdvancedRuleWithoutBidirectionalState(
                source:
                    KeyCombination(
                        keyCode:
                            KeyCode.v
                    ),
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.w
                    ),
                matchingMode:
                    .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source:
                            KeyCombination(
                                keyCode:
                                    KeyCode.v,
                                modifiers:
                                    [.command]
                            ),
                        action:
                            .passThrough,
                        isEnabled:
                            true
                    )
                ]
            )

        let legacyData =
            try JSONEncoder()
                .encode(
                    [
                        legacyRule
                    ]
                )

        context.userDefaults.set(
            legacyData,
            forKey:
                "remappingRules.v1"
        )

        let store =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        let loadedRule =
            try XCTUnwrap(
                store
                    .loadRules()
                    .first
            )

        XCTAssertFalse(
            loadedRule.isBidirectional
        )

        XCTAssertEqual(
            loadedRule.source,
            legacyRule.source
        )

        XCTAssertEqual(
            loadedRule.destination,
            legacyRule.destination
        )

        XCTAssertEqual(
            loadedRule.matchingMode,
            legacyRule.matchingMode
        )

        XCTAssertEqual(
            loadedRule.overrides,
            legacyRule.overrides
        )
    }

    private func makeRule(
        source: CGKeyCode,
        destination: CGKeyCode,
        matchingMode:
            RemapMatchingMode = .exact,
        overrides:
            [RemapOverride] = [],
        isBidirectional: Bool
    ) -> RemapRule {
        RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        source
                ),
            destination:
                KeyCombination(
                    keyCode:
                        destination
                ),
            matchingMode:
                matchingMode,
            overrides:
                overrides,
            isBidirectional:
                isBidirectional
        )
    }

    private func makeContext()
        throws -> BidirectionalPersistenceTestContext
    {
        let suiteName =
            "BidirectionalRemappingPersistenceTests."
            + UUID().uuidString

        let userDefaults =
            try XCTUnwrap(
                UserDefaults(
                    suiteName:
                        suiteName
                )
            )

        return BidirectionalPersistenceTestContext(
            suiteName:
                suiteName,
            userDefaults:
                userDefaults
        )
    }
}

private nonisolated struct LegacyAdvancedRuleWithoutBidirectionalState:
    Codable
{
    let source: KeyCombination
    let destination: KeyCombination
    let matchingMode: RemapMatchingMode
    let overrides: [RemapOverride]
}

private struct BidirectionalPersistenceTestContext {
    let suiteName: String
    let userDefaults: UserDefaults

    func cleanUp() {
        userDefaults.removePersistentDomain(
            forName:
                suiteName
        )
    }
}
