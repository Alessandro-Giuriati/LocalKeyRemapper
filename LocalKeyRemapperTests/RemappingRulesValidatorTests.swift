//
//  RemappingRulesValidatorTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import CoreGraphics
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
                        sourceKeyCode: KeyCode.v,
                        destinationKeyCode: KeyCode.w
                    ),
                    RemapRule(
                        sourceKeyCode: KeyCode.w,
                        destinationKeyCode: KeyCode.v
                    )
                ]
            )
    }

    func testModifierPreservingRuleWithOverridesIsAccepted()
        throws
    {
        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.v,
                        modifiers: [.command]
                    ),
                    action: .passThrough
                ),
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.v,
                        modifiers: [
                            .control,
                            .option
                        ]
                    ),
                    action: .replaceWith(
                        KeyCombination(
                            keyCode: KeyCode.j,
                            modifiers: [
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

    func testExactRuleWithStoredOverridesIsAccepted()
        throws
    {
        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .exact,
            overrides: [
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.v,
                        modifiers: [.command]
                    ),
                    action: .passThrough
                )
            ]
        )

        try RemappingRulesValidator()
            .validate([rule])
    }

    func testDisabledOverrideDoesNotSuppressCrossModeConflict() {
        let conflictingSource = KeyCombination(
            keyCode: KeyCode.v,
            modifiers: [.command]
        )

        let rules = [
            RemapRule(
                source: conflictingSource,
                destination: KeyCombination(
                    keyCode: KeyCode.b
                )
            ),
            RemapRule(
                source: KeyCombination(
                    keyCode: KeyCode.v
                ),
                destination: KeyCombination(
                    keyCode: KeyCode.w
                ),
                matchingMode: .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source: conflictingSource,
                        action: .passThrough,
                        isEnabled: false
                    )
                ]
            )
        ]

        assertDuplicateSourceCombination(
            conflictingSource,
            rules: rules
        )
    }

    func testOverrideOwnedByExactRuleCanConflictBecauseItIsInactive()
        throws
    {
        let conflictingSource = KeyCombination(
            keyCode: KeyCode.v,
            modifiers: [.command]
        )

        let rules = [
            RemapRule(
                source: conflictingSource,
                destination: KeyCombination(
                    keyCode: KeyCode.b
                )
            ),
            RemapRule(
                source: KeyCombination(
                    keyCode: KeyCode.v
                ),
                destination: KeyCombination(
                    keyCode: KeyCode.w
                ),
                matchingMode: .exact,
                overrides: [
                    RemapOverride(
                        source: conflictingSource,
                        action: .passThrough,
                        isEnabled: true
                    )
                ]
            )
        ]

        try RemappingRulesValidator()
            .validate(rules)
    }

    func testEnabledOverrideUnderPreserveModifiersConflictingWithExactRuleIsRejected() {
        let conflictingSource = KeyCombination(
            keyCode: KeyCode.v,
            modifiers: [.command]
        )

        let rules = [
            RemapRule(
                source: conflictingSource,
                destination: KeyCombination(
                    keyCode: KeyCode.b
                )
            ),
            RemapRule(
                source: KeyCombination(
                    keyCode: KeyCode.v
                ),
                destination: KeyCombination(
                    keyCode: KeyCode.w
                ),
                matchingMode: .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source: conflictingSource,
                        action: .passThrough,
                        isEnabled: true
                    )
                ]
            )
        ]

        assertDuplicateSourceCombination(
            conflictingSource,
            rules: rules
        )
    }

    func testTwoDisabledOverridesWithSameSourceAreAccepted()
        throws
    {
        let source = KeyCombination(
            keyCode: KeyCode.v,
            modifiers: [.command]
        )

        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: source,
                    action: .passThrough,
                    isEnabled: false
                ),
                RemapOverride(
                    source: source,
                    action: .replaceWith(
                        KeyCombination(
                            keyCode: KeyCode.j
                        )
                    ),
                    isEnabled: false
                )
            ]
        )

        try RemappingRulesValidator()
            .validate([rule])
    }

    func testTwoEnabledOverridesWithSameSourceAreRejected() {
        let source = KeyCombination(
            keyCode: KeyCode.v,
            modifiers: [.command]
        )

        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: source,
                    action: .passThrough,
                    isEnabled: true
                ),
                RemapOverride(
                    source: source,
                    action: .replaceWith(
                        KeyCombination(
                            keyCode: KeyCode.j
                        )
                    ),
                    isEnabled: true
                )
            ]
        )

        assertDuplicateSourceCombination(
            source,
            rules: [rule]
        )
    }

    func testDuplicateLegacySourceKeyIsRejected() {
        let rules = [
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            ),
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.b
            )
        ]

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(rules)
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .duplicateSourceKey(KeyCode.v)
            )
        }
    }

    func testDuplicateExactCombinationIsRejected() {
        let source = KeyCombination(
            keyCode: KeyCode.n,
            modifiers: [
                .control,
                .option
            ]
        )

        let rules = [
            RemapRule(
                source: source,
                destination: KeyCombination(
                    keyCode: KeyCode.b
                )
            ),
            RemapRule(
                source: source,
                destination: KeyCombination(
                    keyCode: KeyCode.j
                )
            )
        ]

        assertDuplicateSourceCombination(
            source,
            rules: rules
        )
    }

    func testDuplicatePreservingSourceKeyIsRejected() {
        let rules = [
            RemapRule(
                source: KeyCombination(
                    keyCode: KeyCode.v
                ),
                destination: KeyCombination(
                    keyCode: KeyCode.w
                ),
                matchingMode: .preserveModifiers
            ),
            RemapRule(
                source: KeyCombination(
                    keyCode: KeyCode.v
                ),
                destination: KeyCombination(
                    keyCode: KeyCode.b
                ),
                matchingMode: .preserveModifiers
            )
        ]

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(rules)
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .duplicatePreservingSourceKey(KeyCode.v)
            )
        }
    }

    func testIdenticalLegacyRuleIsRejected() {
        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(
                    [
                        RemapRule(
                            sourceKeyCode: KeyCode.v,
                            destinationKeyCode: KeyCode.v
                        )
                    ]
                )
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .identicalSourceAndDestination(KeyCode.v)
            )
        }
    }

    func testIdenticalModifiedCombinationIsRejected() {
        let combination = KeyCombination(
            keyCode: KeyCode.n,
            modifiers: [
                .control,
                .option
            ]
        )

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(
                    [
                        RemapRule(
                            source: combination,
                            destination: combination
                        )
                    ]
                )
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .identicalSourceAndDestinationCombination(
                    combination
                )
            )
        }
    }

    func testPreservingRuleRejectsModifiedEndpoints() {
        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v,
                modifiers: [.command]
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers
        )

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate([rule])
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .invalidModifierPreservingEndpoints
            )
        }
    }

    func testOverrideMustUseParentSourceKey() {
        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.n,
                        modifiers: [.command]
                    ),
                    action: .passThrough
                )
            ]
        )

        assertSourceKeyMismatch(
            rule,
            expected: KeyCode.v,
            actual: KeyCode.n
        )
    }

    func testDisabledOverrideMustStillUseParentSourceKey() {
        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.n,
                        modifiers: [.command]
                    ),
                    action: .passThrough,
                    isEnabled: false
                )
            ]
        )

        assertSourceKeyMismatch(
            rule,
            expected: KeyCode.v,
            actual: KeyCode.n
        )
    }

    func testDisabledIdentityReplacementIsRejected() {
        let source = KeyCombination(
            keyCode: KeyCode.v,
            modifiers: [.command]
        )

        let rule = RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: source,
                    action: .replaceWith(source),
                    isEnabled: false
                )
            ]
        )

        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate([rule])
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .identicalSourceAndDestinationCombination(
                    source
                )
            )
        }
    }

    private func assertDuplicateSourceCombination(
        _ source: KeyCombination,
        rules: [RemapRule],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(rules),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .duplicateSourceCombination(source),
                file: file,
                line: line
            )
        }
    }

    private func assertSourceKeyMismatch(
        _ rule: RemapRule,
        expected: CGKeyCode,
        actual: CGKeyCode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate([rule]),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? RemappingRulesValidationError,
                .overrideSourceKeyMismatch(
                    expected: expected,
                    actual: actual
                ),
                file: file,
                line: line
            )
        }
    }
}
