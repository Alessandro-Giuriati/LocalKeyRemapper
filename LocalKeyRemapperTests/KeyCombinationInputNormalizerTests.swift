//
//  KeyCombinationInputNormalizerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/21/26.
//

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class KeyCombinationInputNormalizerTests:
    XCTestCase
{
    func testOrdinaryLeftArrowDoesNotAcquireFnFromFunctionMetadata() {
        let combination =
            normalizedCombination(
                keyCode:
                    kVK_LeftArrow,
                modifiers: [
                    .command,
                    .fn
                ],
                physicalFnIsPressed:
                    false
            )

        XCTAssertEqual(
            combination,
            KeyCombination(
                keyCode:
                    CGKeyCode(
                        kVK_LeftArrow
                    ),
                modifiers: [
                    .command
                ]
            )
        )
    }

    func testOrdinaryFunctionKeyDoesNotAcquireFnFromFunctionMetadata() {
        let combination =
            normalizedCombination(
                keyCode:
                    kVK_F6,
                modifiers: [
                    .fn
                ],
                physicalFnIsPressed:
                    false
            )

        XCTAssertEqual(
            combination,
            KeyCombination(
                keyCode:
                    CGKeyCode(
                        kVK_F6
                    )
            )
        )
    }

    func testPhysicalFnHomeIsNormalizedToFnLeftArrow() {
        assertFnNavigationNormalization(
            delivered:
                kVK_Home,
            expectedPhysical:
                kVK_LeftArrow
        )
    }

    func testPhysicalFnEndIsNormalizedToFnRightArrow() {
        assertFnNavigationNormalization(
            delivered:
                kVK_End,
            expectedPhysical:
                kVK_RightArrow
        )
    }

    func testPhysicalFnPageUpIsNormalizedToFnUpArrow() {
        assertFnNavigationNormalization(
            delivered:
                kVK_PageUp,
            expectedPhysical:
                kVK_UpArrow
        )
    }

    func testPhysicalFnPageDownIsNormalizedToFnDownArrow() {
        assertFnNavigationNormalization(
            delivered:
                kVK_PageDown,
            expectedPhysical:
                kVK_DownArrow
        )
    }

    func testPhysicalFnForwardDeleteIsNormalizedToFnDelete() {
        assertFnNavigationNormalization(
            delivered:
                kVK_ForwardDelete,
            expectedPhysical:
                kVK_Delete
        )
    }

    func testPhysicalFnFunctionKeyKeepsItsFunctionKeyCode() {
        let combination =
            normalizedCombination(
                keyCode:
                    kVK_F6,
                modifiers: [],
                physicalFnIsPressed:
                    true
            )

        XCTAssertEqual(
            combination,
            KeyCombination(
                keyCode:
                    CGKeyCode(
                        kVK_F6
                    ),
                modifiers: [
                    .fn
                ]
            )
        )
    }

    private func assertFnNavigationNormalization(
        delivered:
            Int,
        expectedPhysical:
            Int,
        file:
            StaticString = #filePath,
        line:
            UInt = #line
    ) {
        let combination =
            normalizedCombination(
                keyCode:
                    delivered,
                modifiers: [
                    .fn
                ],
                physicalFnIsPressed:
                    true
            )

        XCTAssertEqual(
            combination,
            KeyCombination(
                keyCode:
                    CGKeyCode(
                        expectedPhysical
                    ),
                modifiers: [
                    .fn
                ]
            ),
            file:
                file,
            line:
                line
        )
    }

    private func normalizedCombination(
        keyCode:
            Int,
        modifiers:
            KeyModifiers,
        physicalFnIsPressed:
            Bool
    ) -> KeyCombination {
        KeyCombinationInputNormalizer
            .combination(
                deliveredKeyCode:
                    CGKeyCode(
                        keyCode
                    ),
                modifiers:
                    modifiers,
                physicalFnIsPressed:
                    physicalFnIsPressed
            )
    }
}
