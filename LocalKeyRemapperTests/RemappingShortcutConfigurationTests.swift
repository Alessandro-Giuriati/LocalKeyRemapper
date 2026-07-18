//
//  RemappingShortcutConfigurationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import Foundation
import XCTest
@testable import LocalKeyRemapper

final class RemappingShortcutConfigurationTests:
    XCTestCase
{
    func testDisabledConfigurationCanBeEncodedAndDecoded()
        throws
    {
        try assertRoundTrip(
            .disabled
        )
    }

    func testToggleConfigurationCanBeEncodedAndDecoded()
        throws
    {
        try assertRoundTrip(
            .toggle(
                makeToggleShortcut()
            )
        )
    }

    func testSeparateConfigurationCanBeEncodedAndDecoded()
        throws
    {
        let configuration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        makeEnableShortcut(),
                    disable:
                        makeDisableShortcut()
                )

        try assertRoundTrip(
            configuration
        )
    }

    func testToggleConfigurationCreatesOneRegistration() {
        let shortcut =
            makeToggleShortcut()

        let configuration =
            RemappingShortcutConfiguration
                .toggle(
                    shortcut
                )

        XCTAssertEqual(
            configuration.registrations,
            [
                GlobalShortcutRegistration(
                    action:
                        .toggle,
                    shortcut:
                        shortcut
                )
            ]
        )

        XCTAssertEqual(
            configuration.reservedCombinations,
            Set(
                [
                    shortcut
                ]
            )
        )
    }

    func testSeparateConfigurationCreatesTwoRegistrations() {
        let enableShortcut =
            makeEnableShortcut()

        let disableShortcut =
            makeDisableShortcut()

        let configuration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        enableShortcut,
                    disable:
                        disableShortcut
                )

        XCTAssertEqual(
            configuration.registrations,
            [
                GlobalShortcutRegistration(
                    action:
                        .enable,
                    shortcut:
                        enableShortcut
                ),
                GlobalShortcutRegistration(
                    action:
                        .disable,
                    shortcut:
                        disableShortcut
                )
            ]
        )

        XCTAssertEqual(
            configuration.reservedCombinations,
            Set(
                [
                    enableShortcut,
                    disableShortcut
                ]
            )
        )
    }

    func testLegacyToggleShortcutMigratesToToggleConfiguration()
        throws
    {
        let shortcut =
            makeToggleShortcut()

        let legacyPreferences =
            LegacyAppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    shortcut
            )

        let data =
            try JSONEncoder()
                .encode(
                    legacyPreferences
                )

        let decodedPreferences =
            try JSONDecoder()
                .decode(
                    AppPreferences.self,
                    from:
                        data
                )

        XCTAssertEqual(
            decodedPreferences
                .shortcutConfiguration,
            .toggle(
                shortcut
            )
        )
    }

    func testLegacyNilShortcutMigratesToDisabledConfiguration()
        throws
    {
        let legacyPreferences =
            LegacyAppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    nil
            )

        let data =
            try JSONEncoder()
                .encode(
                    legacyPreferences
                )

        let decodedPreferences =
            try JSONDecoder()
                .decode(
                    AppPreferences.self,
                    from:
                        data
                )

        XCTAssertEqual(
            decodedPreferences
                .shortcutConfiguration,
            .disabled
        )
    }

    private func assertRoundTrip(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        let data =
            try JSONEncoder()
                .encode(
                    configuration
                )

        let decodedConfiguration =
            try JSONDecoder()
                .decode(
                    RemappingShortcutConfiguration.self,
                    from:
                        data
                )

        XCTAssertEqual(
            decodedConfiguration,
            configuration
        )
    }

    private func makeToggleShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.r,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }

    private func makeEnableShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.e,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }

    private func makeDisableShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.d,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
}

private nonisolated struct LegacyAppPreferences:
    Encodable
{
    let launchBehavior:
        RemappingLaunchBehavior

    let lastRemappingEnabled:
        Bool

    let toggleShortcut:
        KeyCombination?

    private enum CodingKeys:
        String,
        CodingKey
    {
        case launchBehavior
        case lastRemappingEnabled
        case toggleShortcut
    }

    func encode(to encoder: Encoder)
        throws
    {
        var container =
            encoder.container(
                keyedBy:
                    CodingKeys.self
            )

        try container.encode(
            launchBehavior,
            forKey:
                .launchBehavior
        )

        try container.encode(
            lastRemappingEnabled,
            forKey:
                .lastRemappingEnabled
        )

        if let toggleShortcut {
            try container.encode(
                toggleShortcut,
                forKey:
                    .toggleShortcut
            )
        } else {
            try container.encodeNil(
                forKey:
                    .toggleShortcut
            )
        }
    }
}

