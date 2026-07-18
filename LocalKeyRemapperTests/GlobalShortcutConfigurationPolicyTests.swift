//
//  GlobalShortcutConfigurationPolicyTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import XCTest
@testable import LocalKeyRemapper

final class GlobalShortcutConfigurationPolicyTests:
    XCTestCase
{
    func testOneModifierConfigurationIsValid()
        throws
    {
        let configuration =
            RemappingShortcutConfiguration
                .toggle(
                    KeyCombination(
                        keyCode:
                            KeyCode.r,
                        modifiers: [
                            .command
                        ]
                    )
                )

        XCTAssertNoThrow(
            try GlobalShortcutConfigurationPolicy
                .validate(
                    configuration
                )
        )
    }

    func testConfigurationWithoutModifiersIsRejected() {
        let configuration =
            RemappingShortcutConfiguration
                .toggle(
                    KeyCombination(
                        keyCode:
                            KeyCode.r
                    )
                )

        XCTAssertThrowsError(
            try GlobalShortcutConfigurationPolicy
                .validate(
                    configuration
                )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    GlobalShortcutConfigurationError,
                .insufficientModifiers(
                    .toggle
                )
            )
        }
    }

    func testOneModifierProducesSuggestion() {
        let configuration =
            RemappingShortcutConfiguration
                .toggle(
                    KeyCombination(
                        keyCode:
                            KeyCode.r,
                        modifiers: [
                            .command
                        ]
                    )
                )

        XCTAssertEqual(
            GlobalShortcutConfigurationPolicy
                .suggestion(
                    for:
                        configuration
                ),
            .useAdditionalModifier
        )
    }

    func testTwoModifiersDoNotProduceSuggestion() {
        let configuration =
            RemappingShortcutConfiguration
                .toggle(
                    KeyCombination(
                        keyCode:
                            KeyCode.r,
                        modifiers: [
                            .control,
                            .command
                        ]
                    )
                )

        XCTAssertNil(
            GlobalShortcutConfigurationPolicy
                .suggestion(
                    for:
                        configuration
                )
        )
    }

    func testSeparateConfigurationProducesSuggestionWhenEitherShortcutUsesOneModifier() {
        let configuration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        KeyCombination(
                            keyCode:
                                KeyCode.e,
                            modifiers: [
                                .command
                            ]
                        ),
                    disable:
                        KeyCombination(
                            keyCode:
                                KeyCode.d,
                            modifiers: [
                                .control,
                                .command
                            ]
                        )
                )

        XCTAssertEqual(
            GlobalShortcutConfigurationPolicy
                .suggestion(
                    for:
                        configuration
                ),
            .useAdditionalModifier
        )
    }

    func testIdenticalSeparateShortcutsAreRejected() {
        let sharedShortcut =
            KeyCombination(
                keyCode:
                    KeyCode.r,
                modifiers: [
                    .command
                ]
            )

        let configuration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        sharedShortcut,
                    disable:
                        sharedShortcut
                )

        XCTAssertThrowsError(
            try GlobalShortcutConfigurationPolicy
                .validate(
                    configuration
                )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    GlobalShortcutConfigurationError,
                .duplicateShortcut
            )
        }
    }
}
