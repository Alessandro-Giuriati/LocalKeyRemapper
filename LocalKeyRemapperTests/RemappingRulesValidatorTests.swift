//
//  RemappingRulesValidatorTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

//
//  RemappingRulesValidatorTests.swift
//  LocalKeyRemapperTests
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
        let validator =
            RemappingRulesValidator()

        try validator.validate([])
    }

    func testValidRulesAreAccepted()
        throws
    {
        let validator =
            RemappingRulesValidator()

        let rules = [
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

        try validator.validate(rules)
    }

    func testDuplicateSourceKeyIsRejected() {
        let validator =
            RemappingRulesValidator()

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
                    KeyCode.v
            )
        ]

        do {
            try validator.validate(rules)

            XCTFail(
                "Expected duplicate source key validation to fail."
            )
        } catch let error
            as RemappingRulesValidationError
        {
            XCTAssertEqual(
                error,
                .duplicateSourceKey(
                    KeyCode.v
                )
            )
        } catch {
            XCTFail(
                "Unexpected error: \(error)"
            )
        }
    }

    func testIdenticalSourceAndDestinationIsRejected() {
        let validator =
            RemappingRulesValidator()

        let rules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.v
            )
        ]

        do {
            try validator.validate(rules)

            XCTFail(
                "Expected identity rule validation to fail."
            )
        } catch let error
            as RemappingRulesValidationError
        {
            XCTAssertEqual(
                error,
                .identicalSourceAndDestination(
                    KeyCode.v
                )
            )
        } catch {
            XCTFail(
                "Unexpected error: \(error)"
            )
        }
    }
}
