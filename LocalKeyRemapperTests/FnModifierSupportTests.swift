//
//  FnModifierSupportTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/21/26.
//

import AppKit
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class FnModifierSupportTests:
    XCTestCase
{
    func testFnUsesAnIndependentStoredBit() {
        XCTAssertEqual(
            KeyModifiers.fn.rawValue,
            1 << 4
        )

        XCTAssertFalse(
            KeyModifiers.command.contains(
                .fn
            )
        )
    }

    func testCoreGraphicsFnFlagIsDecoded() {
        let modifiers = KeyModifiers(
            eventFlags: [
                .maskCommand,
                .maskSecondaryFn
            ]
        )

        XCTAssertEqual(
            modifiers,
            [
                .command,
                .fn
            ]
        )
    }

    func testFnIsEncodedAsCoreGraphicsFlag() {
        let modifiers:
            KeyModifiers = [
                .shift,
                .fn
            ]

        XCTAssertTrue(
            modifiers.eventFlags.contains(
                .maskShift
            )
        )

        XCTAssertTrue(
            modifiers.eventFlags.contains(
                .maskSecondaryFn
            )
        )
    }

    func testApplyingModifiersReplacesFnAndPreservesUnrelatedFlags() {
        let existingFlags:
            CGEventFlags = [
                .maskCommand,
                .maskSecondaryFn,
                .maskNumericPad
            ]

        let updatedFlags =
            KeyModifiers
                .shift
                .applying(
                    to:
                        existingFlags
                )

        XCTAssertTrue(
            updatedFlags.contains(
                .maskShift
            )
        )

        XCTAssertTrue(
            updatedFlags.contains(
                .maskNumericPad
            )
        )

        XCTAssertFalse(
            updatedFlags.contains(
                .maskCommand
            )
        )

        XCTAssertFalse(
            updatedFlags.contains(
                .maskSecondaryFn
            )
        )
    }

    func testAppKitFunctionFlagIsNotTreatedAsPhysicalFn() {
        let modifiers = KeyModifiers(
            appKitFlags: [
                .command,
                .function
            ]
        )

        XCTAssertEqual(
            modifiers,
            [
                .command
            ]
        )
    }

    func testExactRuleCanMatchFn() {
        let source = KeyCombination(
            keyCode:
                KeyCode.v,
            modifiers: [
                .fn
            ]
        )

        let destination = KeyCombination(
            keyCode:
                KeyCode.w
        )

        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    source:
                        source,
                    destination:
                        destination,
                    matchingMode:
                        .exact
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    source
            ),
            .replaceWith(
                destination
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCombination(
                        keyCode:
                            KeyCode.v
                    )
            ),
            .passThrough
        )
    }

    func testPreserveModifiersKeepsFn() {
        let engine = RemappingEngine(
            rules: [
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
                        .preserveModifiers
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCombination(
                        keyCode:
                            KeyCode.v,
                        modifiers: [
                            .command,
                            .fn
                        ]
                    )
            ),
            .replaceWith(
                KeyCombination(
                    keyCode:
                        KeyCode.w,
                    modifiers: [
                        .command,
                        .fn
                    ]
                )
            )
        )
    }

    func testDisplayNameShowsFnExplicitly() {
        XCTAssertEqual(
            KeyCombinationDisplayName.name(
                for:
                    KeyCombination(
                        keyCode:
                            KeyCode.v,
                        modifiers: [
                            .command,
                            .fn
                        ]
                    )
            ),
            "Fn ⌘V"
        )
    }
}
