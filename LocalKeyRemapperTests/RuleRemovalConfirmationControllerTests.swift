//
//  RuleRemovalConfirmationControllerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/19/26.
//

import XCTest
@testable import LocalKeyRemapper

@MainActor
final class RuleRemovalConfirmationControllerTests:
    XCTestCase
{
    func testEnablingPreferenceContinuesWhenConfirmed() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    true
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldApply =
            controller.shouldApplyPreferenceChange(
                from:
                    false,
                to:
                    true
            )

        XCTAssertTrue(
            shouldApply
        )

        XCTAssertEqual(
            presenter.requests,
            [
                .enablePreference
            ]
        )
    }

    func testEnablingPreferenceStopsWhenCancelled() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    false
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldApply =
            controller.shouldApplyPreferenceChange(
                from:
                    false,
                to:
                    true
            )

        XCTAssertFalse(
            shouldApply
        )

        XCTAssertEqual(
            presenter.requests,
            [
                .enablePreference
            ]
        )
    }

    func testDisablingPreferenceContinuesWhenConfirmed() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    true
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldApply =
            controller.shouldApplyPreferenceChange(
                from:
                    true,
                to:
                    false
            )

        XCTAssertTrue(
            shouldApply
        )

        XCTAssertEqual(
            presenter.requests,
            [
                .disablePreference
            ]
        )
    }

    func testDisablingPreferenceStopsWhenCancelled() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    false
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldApply =
            controller.shouldApplyPreferenceChange(
                from:
                    true,
                to:
                    false
            )

        XCTAssertFalse(
            shouldApply
        )

        XCTAssertEqual(
            presenter.requests,
            [
                .disablePreference
            ]
        )
    }

    func testUnchangedPreferenceDoesNotRequestConfirmation() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    false
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldApply =
            controller.shouldApplyPreferenceChange(
                from:
                    true,
                to:
                    true
            )

        XCTAssertTrue(
            shouldApply
        )

        XCTAssertTrue(
            presenter.requests.isEmpty
        )
    }

    func testRuleRemovalProceedsImmediatelyWhenConfirmationIsDisabled() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    false
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldRemove =
            controller.shouldRemoveRule(
                confirmationRequired:
                    false
            )

        XCTAssertTrue(
            shouldRemove
        )

        XCTAssertTrue(
            presenter.requests.isEmpty
        )
    }

    func testRuleRemovalContinuesWhenConfirmed() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    true
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldRemove =
            controller.shouldRemoveRule(
                confirmationRequired:
                    true
            )

        XCTAssertTrue(
            shouldRemove
        )

        XCTAssertEqual(
            presenter.requests,
            [
                .removeRule
            ]
        )
    }

    func testRuleRemovalStopsWhenCancelled() {
        let presenter =
            RuleRemovalConfirmationPresenterMock(
                result:
                    false
            )

        let controller =
            RuleRemovalConfirmationController(
                presenter:
                    presenter
            )

        let shouldRemove =
            controller.shouldRemoveRule(
                confirmationRequired:
                    true
            )

        XCTAssertFalse(
            shouldRemove
        )

        XCTAssertEqual(
            presenter.requests,
            [
                .removeRule
            ]
        )
    }
}

@MainActor
private final class RuleRemovalConfirmationPresenterMock:
    RuleRemovalConfirmationPresenting
{
    private let result:
        Bool

    private(set) var requests:
        [RuleRemovalConfirmationRequest] =
            []

    init(
        result:
            Bool
    ) {
        self.result =
            result
    }

    func confirm(
        _ request:
            RuleRemovalConfirmationRequest
    ) -> Bool {
        requests.append(
            request
        )

        return result
    }
}
