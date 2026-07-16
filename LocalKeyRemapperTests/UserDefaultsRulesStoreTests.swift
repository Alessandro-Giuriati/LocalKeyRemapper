//
//  UserDefaultsRulesStoreTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/16/26.
//

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
        let suiteName =
            "UserDefaultsRulesStoreTests." +
            UUID().uuidString

        let userDefaults = try XCTUnwrap(
            UserDefaults(
                suiteName: suiteName
            )
        )

        defer {
            userDefaults.removePersistentDomain(
                forName: suiteName
            )
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
                    userDefaults,
                defaultRules:
                    defaultRules
            )

        let loadedRules =
            try store.loadRules()

        XCTAssertEqual(
            loadedRules,
            defaultRules
        )
    }

    func testSavedRulesCanBeLoadedByAnotherStore()
        throws
    {
        let suiteName =
            "UserDefaultsRulesStoreTests." +
            UUID().uuidString

        let userDefaults = try XCTUnwrap(
            UserDefaults(
                suiteName: suiteName
            )
        )

        defer {
            userDefaults.removePersistentDomain(
                forName: suiteName
            )
        }

        let expectedRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            ),
            RemapRule(
                sourceKeyCode:
                    KeyCode.w,
                destinationKeyCode:
                    KeyCode.v
            )
        ]

        let savingStore =
            UserDefaultsRulesStore(
                userDefaults:
                    userDefaults,
                defaultRules: []
            )

        try savingStore.saveRules(
            expectedRules
        )

        let loadingStore =
            UserDefaultsRulesStore(
                userDefaults:
                    userDefaults,
                defaultRules: []
            )

        let loadedRules =
            try loadingStore.loadRules()

        XCTAssertEqual(
            loadedRules,
            expectedRules
        )
    }

    func testEmptyRuleCollectionIsPersisted()
        throws
    {
        let suiteName =
            "UserDefaultsRulesStoreTests." +
            UUID().uuidString

        let userDefaults = try XCTUnwrap(
            UserDefaults(
                suiteName: suiteName
            )
        )

        defer {
            userDefaults.removePersistentDomain(
                forName: suiteName
            )
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
                    userDefaults,
                defaultRules:
                    defaultRules
            )

        try store.saveRules([])

        let loadedRules =
            try store.loadRules()

        XCTAssertEqual(
            loadedRules,
            []
        )
    }
}
