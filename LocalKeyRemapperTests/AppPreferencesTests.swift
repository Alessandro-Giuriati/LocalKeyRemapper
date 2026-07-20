//
//  AppPreferencesTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import XCTest
@testable import LocalKeyRemapper

final class AppPreferencesTests:
    XCTestCase
{
    func testAlwaysOffNeverEnablesAtLaunch() {
        let preferences = AppPreferences(
            launchBehavior: .alwaysOff,
            lastRemappingEnabled: true
        )

        XCTAssertFalse(
            preferences.shouldEnableRemappingAtLaunch
        )
    }

    func testRestoreLastStateUsesStoredEnabledState() {
        let enabledPreferences = AppPreferences(
            launchBehavior: .restoreLastState,
            lastRemappingEnabled: true
        )

        let disabledPreferences = AppPreferences(
            launchBehavior: .restoreLastState,
            lastRemappingEnabled: false
        )

        XCTAssertTrue(
            enabledPreferences
                .shouldEnableRemappingAtLaunch
        )

        XCTAssertFalse(
            disabledPreferences
                .shouldEnableRemappingAtLaunch
        )
    }

    func testAlwaysOnAlwaysEnablesAtLaunch() {
        let preferences = AppPreferences(
            launchBehavior: .alwaysOn,
            lastRemappingEnabled: false
        )

        XCTAssertTrue(
            preferences.shouldEnableRemappingAtLaunch
        )
    }

    func testStandardPreferencesDoNotConfirmRuleRemoval() {
        XCTAssertFalse(
            AppPreferences
                .standard
                .confirmsRuleRemoval
        )
    }

    func testConfiguredRuleRemovalConfirmationIsStoredInModel() {
        let preferences = AppPreferences(
            launchBehavior: .alwaysOff,
            lastRemappingEnabled: false,
            confirmsRuleRemoval: true
        )

        XCTAssertTrue(
            preferences.confirmsRuleRemoval
        )
    }

    func testLegacyPreferencesDefaultRuleRemovalConfirmationToFalse()
        throws
    {
        let legacyJSON = """
        {
            "launchBehavior": "alwaysOff",
            "lastRemappingEnabled": false,
            "showsMenuBarIcon": true
        }
        """

        let data = try XCTUnwrap(
            legacyJSON.data(
                using: .utf8
            )
        )

        let preferences = try JSONDecoder().decode(
            AppPreferences.self,
            from: data
        )

        XCTAssertFalse(
            preferences.confirmsRuleRemoval
        )
    }

    func testEncodingAndDecodingPreservesRuleRemovalConfirmation()
        throws
    {
        let originalPreferences = AppPreferences(
            launchBehavior: .restoreLastState,
            lastRemappingEnabled: true,
            showsMenuBarIcon: false,
            confirmsRuleRemoval: true
        )

        let data = try JSONEncoder().encode(
            originalPreferences
        )

        let decodedPreferences = try JSONDecoder().decode(
            AppPreferences.self,
            from: data
        )

        XCTAssertEqual(
            decodedPreferences,
            originalPreferences
        )

        XCTAssertTrue(
            decodedPreferences.confirmsRuleRemoval
        )
    }
}
