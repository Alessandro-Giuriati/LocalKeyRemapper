//
//  RemappingEngineTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import XCTest
@testable import LocalKeyRemapper

final class RemappingEngineTests:
    XCTestCase
{
    func testMappedKeyReturnsReplacement() {
        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    sourceKeyCode:
                        KeyCode.v,
                    destinationKeyCode:
                        KeyCode.w
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )
    }

    func testExactRuleDoesNotMatchAdditionalModifiers() {
        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    sourceKeyCode:
                        KeyCode.v,
                    destinationKeyCode:
                        KeyCode.w
                )
            ]
        )

        let decision =
            engine.decision(
                for: KeyCombination(
                    keyCode:
                        KeyCode.v,
                    modifiers:
                        [.command]
                )
            )

        XCTAssertEqual(
            decision,
            .passThrough
        )
    }

    func testModifierPreservingRuleKeepsIncomingModifiers() {
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

        let decision =
            engine.decision(
                for: KeyCombination(
                    keyCode:
                        KeyCode.v,
                    modifiers:
                        [
                            .command,
                            .shift
                        ]
                )
            )

        XCTAssertEqual(
            decision,
            .replaceWith(
                KeyCombination(
                    keyCode:
                        KeyCode.w,
                    modifiers:
                        [
                            .command,
                            .shift
                        ]
                )
            )
        )
    }

    func testPassThroughOverrideWinsOverPreservingRule() {
        let commandV =
            KeyCombination(
                keyCode:
                    KeyCode.v,
                modifiers:
                    [.command]
            )

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
                        .preserveModifiers,
                    overrides: [
                        RemapOverride(
                            source:
                                commandV,
                            action:
                                .passThrough
                        )
                    ]
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for: commandV
            ),
            .passThrough
        )
    }

    func testCustomOverrideCanReplaceKeyAndModifiers() {
        let source =
            KeyCombination(
                keyCode:
                    KeyCode.v,
                modifiers:
                    [
                        .control,
                        .option
                    ]
            )

        let destination =
            KeyCombination(
                keyCode:
                    KeyCode.j,
                modifiers:
                    [
                        .control,
                        .command
                    ]
            )

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
                        .preserveModifiers,
                    overrides: [
                        RemapOverride(
                            source:
                                source,
                            action:
                                .replaceWith(
                                    destination
                                )
                        )
                    ]
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for: source
            ),
            .replaceWith(
                destination
            )
        )
    }

    func testStandaloneExactCombinationCanRemoveModifiers() {
        let source =
            KeyCombination(
                keyCode:
                    KeyCode.n,
                modifiers:
                    [
                        .control,
                        .option
                    ]
            )

        let destination =
            KeyCombination(
                keyCode:
                    KeyCode.b
            )

        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    source:
                        source,
                    destination:
                        destination
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for: source
            ),
            .replaceWith(
                destination
            )
        )
    }

    func testStandaloneExactCombinationCanReplaceModifiers() {
        let source =
            KeyCombination(
                keyCode:
                    KeyCode.n,
                modifiers:
                    [
                        .control,
                        .option
                    ]
            )

        let destination =
            KeyCombination(
                keyCode:
                    KeyCode.j,
                modifiers:
                    [
                        .control,
                        .command
                    ]
            )

        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    source:
                        source,
                    destination:
                        destination
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for: source
            ),
            .replaceWith(
                destination
            )
        )
    }

    func testUnmappedKeyPassesThrough() {
        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    sourceKeyCode:
                        KeyCode.v,
                    destinationKeyCode:
                        KeyCode.w
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.w
            ),
            .passThrough
        )
    }

    func testReplacingRulesUpdatesTheEngine() {
        let engine =
            RemappingEngine()

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .passThrough
        )

        engine.replaceRules(
            [
                RemapRule(
                    sourceKeyCode:
                        KeyCode.v,
                    destinationKeyCode:
                        KeyCode.w
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )
    }
}
