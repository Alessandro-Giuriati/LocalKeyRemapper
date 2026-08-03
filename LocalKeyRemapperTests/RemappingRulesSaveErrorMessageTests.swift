//
//  RemappingRulesSaveErrorMessageTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/3/26.
//

import Foundation
import XCTest
@testable import LocalKeyRemapper

final class RemappingRulesSaveErrorMessageTests:
    XCTestCase
{
    func testMissingPersistedProfileExplainsRequiredSaveSequence() {
        let profileID =
            UUID()

        let message =
            RemappingRulesSaveErrorMessage
                .message(
                    for:
                        RemappingProfileRulesAccessError
                            .profileNotFound(
                                profileID
                            )
                )

        XCTAssertEqual(
            message,
            "This profile hasn’t been saved yet. Click Save in the Home window, then return here and click Save Rules."
        )
    }

    func testUnrelatedFailureKeepsGenericFallback() {
        let message =
            RemappingRulesSaveErrorMessage
                .message(
                    for:
                        TestError.failure
                )

        XCTAssertEqual(
            message,
            "The remapping rules could not be saved."
        )
    }

    private enum TestError:
        Error
    {
        case failure
    }
}
