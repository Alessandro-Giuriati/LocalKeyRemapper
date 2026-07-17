//
//  RemappingRulesValidatorTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import XCTest
@testable import LocalKeyRemapper

final class RemappingRulesValidatorTests:
    XCTestCase
{
    func testEmptyRuleCollectionIsValid()
        throws
    {
        try RemappingRulesValidator()
            .validate([])
    }

    func testLegacyStyleExactRulesAreAccepted()
        throws
    {
        try RemappingRulesValidator()
            .validate(
                [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    ),
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.w,
                        destinationKeyCode:
                            KeyCode.v
                    )
                ]
            )
    }

    func testModifierPreservingRuleWithOverridesIsAccepted()
        throws
    {
        let rule = RemapRule(
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
                        KeyCombination(
                            keyCode:
                                KeyCode.v,
                            modifiers:
                                [.command]
                        ),
                    action:
                        .passThrough
                ),
                RemapOverride(
                    source:
                        KeyCombination(
                            keyCode:
                                KeyCode.v,
                            modifiers:
                                [
                                    .control,
                                    .option
                                ]
                        ),
                    action:
                        .replaceWith(
                            KeyCombination(
                                keyCode:
                                    KeyCode.j,
                                modifiers:
                                    [
                                        .control,
                                        .command
                                    ]
                            )
                        )
                )
            ]
        )

        try RemappingRulesValidator()
            .validate([rule])
    }

    func testDuplicateLegacySourceKeyIsRejected() {
        let rules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            ),
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.b
            )
        ]

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(rules)
        ) { error in
            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                .duplicateSourceKey(
                    KeyCode.v
                )
            )
        }
    }

    func testDuplicateExactCombinationIsRejected() {
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

        let rules = [
            RemapRule(
                source:
                    source,
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.b
                    )
            ),
            RemapRule(
                source:
                    source,
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.j
                    )
            )
        ]

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(rules)
        ) { error in
            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                .duplicateSourceCombination(
                    source
                )
            )
        }
    }

    func testDuplicatePreservingSourceKeyIsRejected() {
        let rules = [
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
            ),
            RemapRule(
                source:
                    KeyCombination(
                        keyCode:
                            KeyCode.v
                    ),
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.b
                    ),
                matchingMode:
                    .preserveModifiers
            )
        ]

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(rules)
        ) { error in
            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                .duplicatePreservingSourceKey(
                    KeyCode.v
                )
            )
        }
    }

    func testIdenticalLegacyRuleIsRejected() {
        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(
                    [
                        RemapRule(
                            sourceKeyCode:
                                KeyCode.v,
                            destinationKeyCode:
                                KeyCode.v
                        )
                    ]
                )
        ) { error in
            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                .identicalSourceAndDestination(
                    KeyCode.v
                )
            )
        }
    }

    func testIdenticalModifiedCombinationIsRejected() {
        let combination =
            KeyCombination(
                keyCode:
                    KeyCode.n,
                modifiers:
                    [
                        .control,
                        .option
                    ]
            )

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(
                    [
                        RemapRule(
                            source:
                                combination,
                            destination:
                                combination
                        )
                    ]
                )
        ) { error in
            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                .identicalSourceAndDestinationCombination(
                    combination
                )
            )
        }
    }

    func testPreservingRuleRejectsModifiedEndpoints() {
        let rule = RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        KeyCode.v,
                    modifiers:
                        [.command]
                ),
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w
                ),
            matchingMode:
                .preserveModifiers
        )

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate([rule])
        ) { error in
            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                .invalidModifierPreservingEndpoints
            )
        }
    }

    func testOverrideMustUseParentSourceKey() {
        let rule = RemapRule(
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
                        KeyCombination(
                            keyCode:
                                KeyCode.n,
                            modifiers:
                                [.command]
                        ),
                    action:
                        .passThrough
                )
            ]
        )

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate([rule])
        ) { error in
            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                .overrideSourceKeyMismatch(
                    expected:
                        KeyCode.v,
                    actual:
                        KeyCode.n
                )
            )
        }
    }
}
