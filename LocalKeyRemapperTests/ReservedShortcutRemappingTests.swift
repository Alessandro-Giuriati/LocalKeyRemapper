//
//  ReservedShortcutRemappingTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import XCTest
@testable import LocalKeyRemapper

final class ReservedShortcutRemappingTests:
    XCTestCase
{
    func testExactRuleCannotProduceReservedCombination() {
        let source =
            KeyCombination(
                keyCode:
                    KeyCode.v,
                modifiers: [
                    .control,
                    .option
                ]
            )

        let reservedDestination =
            KeyCombination(
                keyCode:
                    KeyCode.r,
                modifiers: [
                    .control,
                    .option,
                    .command
                ]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            source,
                        destination:
                            reservedDestination
                    )
                ]
            )

        engine.replaceReservedCombinations(
            Set(
                [
                    reservedDestination
                ]
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    source
            ),
            .passThrough
        )
    }

    func testModifierPreservingRuleCannotProduceReservedCombination() {
        let source =
            KeyCombination(
                keyCode:
                    KeyCode.v
            )

        let destination =
            KeyCombination(
                keyCode:
                    KeyCode.r
            )

        let incomingCombination =
            KeyCombination(
                keyCode:
                    KeyCode.v,
                modifiers: [
                    .control,
                    .option,
                    .command
                ]
            )

        let reservedDestination =
            KeyCombination(
                keyCode:
                    KeyCode.r,
                modifiers: [
                    .control,
                    .option,
                    .command
                ]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            source,
                        destination:
                            destination,
                        matchingMode:
                            .preserveModifiers
                    )
                ]
            )

        engine.replaceReservedCombinations(
            Set(
                [
                    reservedDestination
                ]
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    incomingCombination
            ),
            .passThrough
        )
    }
}
