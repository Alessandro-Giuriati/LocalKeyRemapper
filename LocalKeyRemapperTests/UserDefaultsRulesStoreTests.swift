//
//  UserDefaultsRulesStoreTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import CoreGraphics
import Foundation
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class UserDefaultsRulesStoreTests:
    XCTestCase
{
    func testLoadReturnsDefaultRulesWhenNothingIsStored()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let defaultRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let store =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules:
                    defaultRules
            )

        XCTAssertEqual(
            try store.loadRules(),
            defaultRules
        )
    }

    func testAdvancedRulesCanBeSavedAndLoaded()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let expectedRules = [
            RemapRule(
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
                            .passThrough
                    )
                ]
            ),
            RemapRule(
                source:
                    KeyCombination(
                        keyCode:
                            KeyCode.n,
                        modifiers:
                            [
                                .control,
                                .option
                            ]
                    ),
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.j,
                        modifiers:
                            [
                                .control,
                                .command
                            ]
                    )
            )
        ]

        let savingStore =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        try savingStore.saveRules(
            expectedRules
        )

        let loadingStore =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        XCTAssertEqual(
            try loadingStore.loadRules(),
            expectedRules
        )
    }

    func testLegacyStoredRulesAreMigratedToExactRules()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let legacyRules = [
            LegacyRemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let data = try JSONEncoder()
            .encode(legacyRules)

        context.userDefaults.set(
            data,
            forKey:
                "remappingRules.v1"
        )

        let store =
            UserDefaultsRulesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules: []
            )

        XCTAssertEqual(
            try store.loadRules(),
            [
                RemapRule(
                    sourceKeyCode:
                        KeyCode.v,
                    destinationKeyCode:
                        KeyCode.w
                )
            ]
        )
    }

    func testEmptyRuleCollectionIsPersisted()
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
                defaultRules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ]
            )

        try store.saveRules([])

        XCTAssertEqual(
            try store.loadRules(),
            []
        )
    }

    private func makeContext()
        throws -> TestUserDefaultsContext
    {
        let suiteName =
            "UserDefaultsRulesStoreTests." +
            UUID().uuidString

        let userDefaults =
            try XCTUnwrap(
                UserDefaults(
                    suiteName:
                        suiteName
                )
            )

        return TestUserDefaultsContext(
            suiteName:
                suiteName,
            userDefaults:
                userDefaults
        )
    }
}

private nonisolated struct LegacyRemapRule:
    Codable
{
    let sourceKeyCode:
        CGKeyCode

    let destinationKeyCode:
        CGKeyCode
}

private struct TestUserDefaultsContext {
    let suiteName: String
    let userDefaults: UserDefaults

    func cleanUp() {
        userDefaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
