//
//  AppCoordinatorWindowReuseTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/24/26.
//

import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class AppCoordinatorWindowReuseTests:
    XCTestCase
{
    func testRepeatedRulesWindowRequestsReuseOneControllerAndOneWindow() {
        let coordinator =
            AppCoordinator()

        defer {
            coordinator.stop()
        }

        coordinator.showRemappingRulesWindow()

        guard
            let firstController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "The first rules-window request did not create a controller."
            )
            return
        }

        XCTAssertTrue(
            firstController.window?.isVisible
                == true
        )

        coordinator.showRemappingRulesWindow()

        guard
            let secondController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "The second rules-window request lost the existing controller."
            )
            return
        }

        XCTAssertTrue(
            firstController
                === secondController
        )

        XCTAssertEqual(
            visibleRulesWindowCount,
            1
        )

        firstController.close()
    }

    func testClosingAndReopeningRulesWindowPreservesControllerAndPresentationState() {
        let coordinator =
            AppCoordinator()

        defer {
            coordinator.stop()
        }

        coordinator.showRemappingRulesWindow()

        guard
            let firstController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                ),
            let firstPresentationModel =
                reflectedPresentationModel(
                    from:
                        firstController
                )
        else {
            XCTFail(
                "The rules window or its presentation model was not created."
            )
            return
        }

        _ = firstPresentationModel
            .selectSortColumn(
                .source
            )

        firstPresentationModel
            .toggleConfigurationWarningFilter()

        let expectedSortDescriptor =
            RemappingRulesPresentationModel
                .SortDescriptor(
                    column:
                        .source,
                    direction:
                        .ascending
                )

        XCTAssertEqual(
            firstPresentationModel
                .sortDescriptor,
            expectedSortDescriptor
        )

        XCTAssertTrue(
            firstPresentationModel
                .showsOnlyConfigurationWarnings
        )

        firstController.close()

        XCTAssertFalse(
            firstController.window?.isVisible
                == true
        )

        coordinator.showRemappingRulesWindow()

        guard
            let reopenedController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                ),
            let reopenedPresentationModel =
                reflectedPresentationModel(
                    from:
                        reopenedController
                )
        else {
            XCTFail(
                "The rules window was not restored after reopening."
            )
            return
        }

        XCTAssertTrue(
            firstController
                === reopenedController
        )

        XCTAssertTrue(
            firstPresentationModel
                === reopenedPresentationModel
        )

        XCTAssertEqual(
            reopenedPresentationModel
                .sortDescriptor,
            expectedSortDescriptor
        )

        XCTAssertTrue(
            reopenedPresentationModel
                .showsOnlyConfigurationWarnings
        )

        XCTAssertEqual(
            visibleRulesWindowCount,
            1
        )

        reopenedController.close()
    }

    private var visibleRulesWindowCount:
        Int
    {
        NSApplication.shared
            .windows
            .filter {
                window in

                window.title
                    == "Remapping Rules"
                    && window.isVisible
            }
            .count
    }

    private func reflectedRulesWindowController(
        from coordinator:
            AppCoordinator
    ) -> RemappingRulesWindowController? {
        reflectedValue(
            named:
                "remappingRulesWindowController",
            from:
                coordinator,
            as:
                RemappingRulesWindowController.self
        )
    }

    private func reflectedPresentationModel(
        from controller:
            RemappingRulesWindowController
    ) -> RemappingRulesPresentationModel? {
        reflectedValue(
            named:
                "presentationModel",
            from:
                controller,
            as:
                RemappingRulesPresentationModel.self
        )
    }

    /// Reads one private ownership value without widening the production API
    /// solely for tests. The test will fail clearly if the ownership contract
    /// or stored-property name changes.
    private func reflectedValue<
        Value
    >(
        named propertyName:
            String,
        from owner:
            Any,
        as valueType:
            Value.Type
    ) -> Value? {
        guard
            let storedValue =
                Mirror(
                    reflecting:
                        owner
                )
                .children
                .first(
                    where: {
                        $0.label
                            == propertyName
                    }
                )?
                .value
        else {
            return nil
        }

        if let directValue =
            storedValue
                as? Value
        {
            return directValue
        }

        let optionalMirror =
            Mirror(
                reflecting:
                    storedValue
            )

        guard
            optionalMirror.displayStyle
                == .optional
        else {
            return nil
        }

        return optionalMirror
            .children
            .first?
            .value
            as? Value
    }
}
