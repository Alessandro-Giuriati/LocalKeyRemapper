//
//  BidirectionalRemappingEngineTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/26/26.
//

import XCTest
@testable import LocalKeyRemapper

final class BidirectionalRemappingEngineTests:
    XCTestCase
{
    func testExactRuleWithReverseDisabledMapsOnlyForwardDirection() {
        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .exact,
                        isBidirectional:
                            false
                    )
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .passThrough
        )
    }

    func testExactBidirectionalRuleMapsBothDirections() {
        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .exact,
                        isBidirectional:
                            true
                    )
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .replaceKeyCode(
                KeyCode.v
            )
        )
    }

    func testExactBidirectionalRuleSwapsCompleteCombinationsIncludingModifiers() {
        let source =
            combination(
                KeyCode.v,
                modifiers: [
                    .command,
                    .shift
                ]
            )

        let destination =
            combination(
                KeyCode.w,
                modifiers: [
                    .control,
                    .option
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
                            .exact,
                        isBidirectional:
                            true
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
                    destination
            ),
            .replaceWith(
                source
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    combination(
                        KeyCode.w,
                        modifiers: [.command]
                    )
            ),
            .passThrough
        )
    }

    func testPreserveModifiersBidirectionalRuleKeepsIncomingModifiersInBothDirections() {
        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .preserveModifiers,
                        isBidirectional:
                            true
                    )
                ]
            )

        let forwardSource =
            combination(
                KeyCode.v,
                modifiers: [
                    .command,
                    .shift
                ]
            )

        let reverseSource =
            combination(
                KeyCode.w,
                modifiers: [
                    .control,
                    .option
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    forwardSource
            ),
            .replaceWith(
                combination(
                    KeyCode.w,
                    modifiers: [
                        .command,
                        .shift
                    ]
                )
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    reverseSource
            ),
            .replaceWith(
                combination(
                    KeyCode.v,
                    modifiers: [
                        .control,
                        .option
                    ]
                )
            )
        )
    }

    func testPassThroughExceptionIsMirroredToReverseSource() {
        let commandV =
            combination(
                KeyCode.v,
                modifiers: [.command]
            )

        let commandW =
            combination(
                KeyCode.w,
                modifiers: [.command]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
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
                        ],
                        isBidirectional:
                            true
                    )
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    commandV
            ),
            .passThrough
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    commandW
            ),
            .passThrough
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    combination(
                        KeyCode.w,
                        modifiers: [.shift]
                    )
            ),
            .replaceWith(
                combination(
                    KeyCode.v,
                    modifiers: [.shift]
                )
            )
        )
    }

    func testCustomReplacementExceptionIsMirroredWithoutChangingItsAction() {
        let forwardExceptionSource =
            combination(
                KeyCode.v,
                modifiers: [
                    .control,
                    .option
                ]
            )

        let reverseExceptionSource =
            combination(
                KeyCode.w,
                modifiers: [
                    .control,
                    .option
                ]
            )

        let customDestination =
            combination(
                KeyCode.j,
                modifiers: [
                    .command,
                    .shift
                ]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .preserveModifiers,
                        overrides: [
                            RemapOverride(
                                source:
                                    forwardExceptionSource,
                                action:
                                    .replaceWith(
                                        customDestination
                                    )
                            )
                        ],
                        isBidirectional:
                            true
                    )
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    forwardExceptionSource
            ),
            .replaceWith(
                customDestination
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    reverseExceptionSource
            ),
            .replaceWith(
                customDestination
            )
        )
    }

    func testDisabledExceptionIsIgnoredInBothDirections() {
        let commandV =
            combination(
                KeyCode.v,
                modifiers: [.command]
            )

        let commandW =
            combination(
                KeyCode.w,
                modifiers: [.command]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .preserveModifiers,
                        overrides: [
                            RemapOverride(
                                source:
                                    commandV,
                                action:
                                    .passThrough,
                                isEnabled:
                                    false
                            )
                        ],
                        isBidirectional:
                            true
                    )
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    commandV
            ),
            .replaceWith(
                combination(
                    KeyCode.w,
                    modifiers: [.command]
                )
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    commandW
            ),
            .replaceWith(
                combination(
                    KeyCode.v,
                    modifiers: [.command]
                )
            )
        )
    }

    func testReplacingRulesCanEnableAndDisableReverseDirectionAtRuntime() {
        let forwardOnlyRule =
            RemapRule(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .exact,
                isBidirectional:
                    false
            )

        let bidirectionalRule =
            RemapRule(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .exact,
                isBidirectional:
                    true
            )

        let engine =
            RemappingEngine(
                rules: [
                    forwardOnlyRule
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .passThrough
        )

        engine.replaceRules(
            [
                bidirectionalRule
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .replaceKeyCode(
                KeyCode.v
            )
        )

        engine.replaceRules(
            [
                forwardOnlyRule
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .passThrough
        )
    }

    func testDisabledExactBidirectionalRulePassesThroughBothDirections() {
        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .exact,
                        isEnabled:
                            false,
                        isBidirectional:
                            true
                    )
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .passThrough
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .passThrough
        )
    }

    func testDisabledPreserveRuleSkipsForwardReverseAndExceptions() {
        let commandV =
            combination(
                KeyCode.v,
                modifiers:
                    [.command]
            )

        let commandW =
            combination(
                KeyCode.w,
                modifiers:
                    [.command]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .preserveModifiers,
                        overrides: [
                            RemapOverride(
                                source:
                                    commandV,
                                action:
                                    .replaceWith(
                                        combination(
                                            KeyCode.j,
                                            modifiers:
                                                [.option]
                                        )
                                    )
                            )
                        ],
                        isEnabled:
                            false,
                        isBidirectional:
                            true
                    )
                ]
            )

        for source in [
            commandV,
            commandW,
            combination(
                KeyCode.v,
                modifiers:
                    [.shift]
            ),
            combination(
                KeyCode.w,
                modifiers:
                    [.shift]
            )
        ] {
            XCTAssertEqual(
                engine.decision(
                    for:
                        source
                ),
                .passThrough
            )
        }
    }

    func testReplacingRulesCanEnableAndDisableEntireBidirectionalRule() {
        let disabledRule =
            RemapRule(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .exact,
                isEnabled:
                    false,
                isBidirectional:
                    true
            )

        let enabledRule =
            RemapRule(
                source:
                    disabledRule.source,
                destination:
                    disabledRule.destination,
                matchingMode:
                    disabledRule.matchingMode,
                overrides:
                    disabledRule.overrides,
                isEnabled:
                    true,
                isBidirectional:
                    disabledRule.isBidirectional
            )

        let engine =
            RemappingEngine(
                rules: [
                    disabledRule
                ]
            )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .passThrough
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .passThrough
        )

        engine.replaceRules(
            [
                enabledRule
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .replaceKeyCode(
                KeyCode.v
            )
        )

        engine.replaceRules(
            [
                disabledRule
            ]
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .passThrough
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.w
            ),
            .passThrough
        )
    }

    private func combination(
        _ keyCode: CGKeyCode,
        modifiers: KeyModifiers = []
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers:
                modifiers
        )
    }
}
