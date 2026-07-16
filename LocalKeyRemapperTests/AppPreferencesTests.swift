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
}
