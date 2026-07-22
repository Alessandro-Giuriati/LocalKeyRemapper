//
//  KeyboardLayoutKeyNameTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class KeyboardLayoutKeyNameTests:
    XCTestCase
{
    func testPrintableItalianLayoutCharacterIsDisplayed() {
        XCTAssertEqual(
            KeyboardLayoutKeyName
                .displayName(
                    for:
                        CGKeyCode(
                            24
                        ),
                    translatedCharacters:
                        "ì"
                ),
            "ì"
        )
    }

    func testAsciiLetterIsDisplayedInUppercase() {
        XCTAssertEqual(
            KeyboardLayoutKeyName
                .displayName(
                    for:
                        CGKeyCode(
                            kVK_ANSI_A
                        ),
                    translatedCharacters:
                        "a"
                ),
            "A"
        )
    }

    func testSpecialKeyUsesStableReadableName() {
        XCTAssertEqual(
            KeyboardLayoutKeyName
                .displayName(
                    for:
                        CGKeyCode(
                            kVK_Return
                        ),
                    translatedCharacters:
                        "\r"
                ),
            "Return"
        )
    }

    func testKnownCatalogKeyIsUsedWhenTranslationIsUnavailable() {
        XCTAssertEqual(
            KeyboardLayoutKeyName
                .displayName(
                    for:
                        CGKeyCode(
                            kVK_ANSI_R
                        ),
                    translatedCharacters:
                        nil
                ),
            "R"
        )
    }

    func testUnknownKeyFallsBackToNumericName() {
        XCTAssertEqual(
            KeyboardLayoutKeyName
                .displayName(
                    for:
                        CGKeyCode(
                            250
                        ),
                    translatedCharacters:
                        nil
                ),
            "Key 250"
        )
    }

    func testMainKeyboardDigitKeepsPlainName() {
        XCTAssertEqual(
            KeyboardLayoutKeyName
                .displayName(
                    for:
                        CGKeyCode(
                            kVK_ANSI_4
                        ),
                    translatedCharacters:
                        "4"
                ),
            "4"
        )
    }

    func testNumericKeypadDigitUsesDistinctPhysicalName() {
        XCTAssertEqual(
            KeyboardLayoutKeyName
                .displayName(
                    for:
                        CGKeyCode(
                            kVK_ANSI_Keypad4
                        ),
                    translatedCharacters:
                        "4"
                ),
            "Keypad 4"
        )
    }

    func testAllNumericKeypadKeysUseDistinctPhysicalNames() {
        let expectedNames:
            [Int: String] =
        [
            kVK_ANSI_Keypad0:
                "Keypad 0",
            kVK_ANSI_Keypad1:
                "Keypad 1",
            kVK_ANSI_Keypad2:
                "Keypad 2",
            kVK_ANSI_Keypad3:
                "Keypad 3",
            kVK_ANSI_Keypad4:
                "Keypad 4",
            kVK_ANSI_Keypad5:
                "Keypad 5",
            kVK_ANSI_Keypad6:
                "Keypad 6",
            kVK_ANSI_Keypad7:
                "Keypad 7",
            kVK_ANSI_Keypad8:
                "Keypad 8",
            kVK_ANSI_Keypad9:
                "Keypad 9",
            kVK_ANSI_KeypadDecimal:
                "Keypad Decimal",
            kVK_ANSI_KeypadMultiply:
                "Keypad Multiply",
            kVK_ANSI_KeypadPlus:
                "Keypad Plus",
            kVK_ANSI_KeypadClear:
                "Keypad Clear",
            kVK_ANSI_KeypadDivide:
                "Keypad Divide",
            kVK_ANSI_KeypadEnter:
                "Keypad Enter",
            kVK_ANSI_KeypadMinus:
                "Keypad Minus",
            kVK_ANSI_KeypadEquals:
                "Keypad Equals"
        ]

        for (
            keyCode,
            expectedName
        ) in expectedNames {
            XCTAssertEqual(
                KeyboardLayoutKeyName
                    .displayName(
                        for:
                            CGKeyCode(
                                keyCode
                            ),
                        translatedCharacters:
                            "translated"
                    ),
                expectedName
            )
        }
    }

    func testNumericKeypadCatalogContainsDistinctNames() {
        let expectedNames:
            [Int: String] =
        [
            kVK_ANSI_Keypad0:
                "Keypad 0",
            kVK_ANSI_Keypad4:
                "Keypad 4",
            kVK_ANSI_Keypad9:
                "Keypad 9",
            kVK_ANSI_KeypadDecimal:
                "Keypad Decimal",
            kVK_ANSI_KeypadEnter:
                "Keypad Enter"
        ]

        for (
            keyCode,
            expectedName
        ) in expectedNames {
            XCTAssertEqual(
                KeyboardKeyCatalog
                    .key(
                        for:
                            CGKeyCode(
                                keyCode
                            )
                    )?
                    .displayName,
                expectedName
            )
        }
    }
}
