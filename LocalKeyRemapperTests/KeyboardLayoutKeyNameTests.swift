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
}
