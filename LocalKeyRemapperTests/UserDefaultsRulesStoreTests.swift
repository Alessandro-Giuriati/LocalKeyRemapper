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
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let defaultRules = [
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            )
        ]

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: defaultRules
        )

        XCTAssertEqual(
            try store.loadRules(),
            defaultRules
        )
    }

    func testAdvancedRulesCanBeSavedAndLoaded()
        throws
    {
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let expectedRules = [
            RemapRule(
                source: KeyCombination(
                    keyCode: KeyCode.v
                ),
                destination: KeyCombination(
                    keyCode: KeyCode.w
                ),
                matchingMode: .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source: KeyCombination(
                            keyCode: KeyCode.v,
                            modifiers: [.command]
                        ),
                        action: .passThrough
                    )
                ]
            ),
            RemapRule(
                source: KeyCombination(
                    keyCode: KeyCode.n,
                    modifiers: [
                        .control,
                        .option
                    ]
                ),
                destination: KeyCombination(
                    keyCode: KeyCode.j,
                    modifiers: [
                        .control,
                        .command
                    ]
                )
            )
        ]

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: []
        )

        try store.saveRules(expectedRules)

        XCTAssertEqual(
            try store.loadRules(),
            expectedRules
        )
    }

    func testDisabledOverrideCanBeSavedAndLoaded()
        throws
    {
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let expectedRule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.v,
                        modifiers: [.command]
                    ),
                    action: .passThrough,
                    isEnabled: false
                )
            ]
        )

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: []
        )

        try store.saveRules([expectedRule])

        let loadedRule = try XCTUnwrap(
            store.loadRules().first
        )

        XCTAssertEqual(
            loadedRule,
            expectedRule
        )
        XCTAssertFalse(
            loadedRule.overrides[0].isEnabled
        )
    }

    func testExactRuleWithStoredOverridesCanBeSavedAndLoaded()
        throws
    {
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let expectedRule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .exact,
            overrides: [
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.v,
                        modifiers: [.command]
                    ),
                    action: .replaceWith(
                        KeyCombination(
                            keyCode: KeyCode.j,
                            modifiers: [.option]
                        )
                    ),
                    isEnabled: true
                )
            ]
        )

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: []
        )

        try store.saveRules([expectedRule])

        XCTAssertEqual(
            try store.loadRules(),
            [expectedRule]
        )
    }

    func testLegacyStoredRulesAreMigratedToExactRules()
        throws
    {
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let legacyRules = [
            LegacyRemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            )
        ]

        let data = try JSONEncoder()
            .encode(legacyRules)

        context.userDefaults.set(
            data,
            forKey: "remappingRules.v1"
        )

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: []
        )

        XCTAssertEqual(
            try store.loadRules(),
            [
                RemapRule(
                    sourceKeyCode: KeyCode.v,
                    destinationKeyCode: KeyCode.w
                )
            ]
        )
    }

    func testStoredOverrideWithoutEnabledFieldLoadsAsEnabled()
        throws
    {
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let legacyOverride = LegacyStoredOverride(
            source: KeyCombination(
                keyCode: KeyCode.v,
                modifiers: [.command]
            ),
            action: .passThrough
        )

        let legacyRule = LegacyAdvancedRemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [legacyOverride]
        )

        let data = try JSONEncoder()
            .encode([legacyRule])

        context.userDefaults.set(
            data,
            forKey: "remappingRules.v1"
        )

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: []
        )

        let loadedOverride = try XCTUnwrap(
            store.loadRules().first?.overrides.first
        )

        XCTAssertTrue(
            loadedOverride.isEnabled
        )
        XCTAssertEqual(
            loadedOverride.source,
            legacyOverride.source
        )
        XCTAssertEqual(
            loadedOverride.action,
            legacyOverride.action
        )
    }

    func testOverrideSourceDestinationActionAndOrderArePreserved()
        throws
    {
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let firstOverride = RemapOverride(
            source: KeyCombination(
                keyCode: KeyCode.v,
                modifiers: [.shift]
            ),
            action: .replaceWith(
                KeyCombination(
                    keyCode: KeyCode.b,
                    modifiers: [.control]
                )
            ),
            isEnabled: false
        )

        let secondOverride = RemapOverride(
            source: KeyCombination(
                keyCode: KeyCode.v,
                modifiers: [.command]
            ),
            action: .passThrough,
            isEnabled: true
        )

        let expectedRule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                firstOverride,
                secondOverride
            ]
        )

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: []
        )

        try store.saveRules([expectedRule])

        let loadedRule = try XCTUnwrap(
            store.loadRules().first
        )

        XCTAssertEqual(
            loadedRule.source,
            expectedRule.source
        )
        XCTAssertEqual(
            loadedRule.destination,
            expectedRule.destination
        )
        XCTAssertEqual(
            loadedRule.overrides,
            [
                firstOverride,
                secondOverride
            ]
        )
    }

    func testEmptyRuleCollectionIsPersisted()
        throws
    {
        let context = try makeContext()

        defer {
            context.cleanUp()
        }

        let store = UserDefaultsRulesStore(
            userDefaults: context.userDefaults,
            defaultRules: [
                RemapRule(
                    sourceKeyCode: KeyCode.v,
                    destinationKeyCode: KeyCode.w
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
            "UserDefaultsRulesStoreTests."
            + UUID().uuidString

        let userDefaults = try XCTUnwrap(
            UserDefaults(
                suiteName: suiteName
            )
        )

        return TestUserDefaultsContext(
            suiteName: suiteName,
            userDefaults: userDefaults
        )
    }
}

private nonisolated struct LegacyRemapRule:
    Codable
{
    let sourceKeyCode: CGKeyCode
    let destinationKeyCode: CGKeyCode
}

private nonisolated struct LegacyStoredOverride:
    Codable
{
    let source: KeyCombination
    let action: RemapAction
}

private nonisolated struct LegacyAdvancedRemapRule:
    Codable
{
    let source: KeyCombination
    let destination: KeyCombination
    let matchingMode: RemapMatchingMode
    let overrides: [LegacyStoredOverride]
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
