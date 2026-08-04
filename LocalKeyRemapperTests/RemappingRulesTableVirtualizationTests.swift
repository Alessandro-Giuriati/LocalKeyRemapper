//
//  RemappingRulesTableVirtualizationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/4/26.
//

import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class RemappingRulesTableVirtualizationTests:
    XCTestCase
{
    func testRulesWindowMaterializesOnlyViewportRows() {
        let coordinator =
            AppCoordinator()

        coordinator.showRemappingRulesWindow()

        guard
            let controller =
                reflectedValue(
                    named:
                        "remappingRulesWindowController",
                    from:
                        coordinator,
                    as:
                        RemappingRulesWindowController.self
                ),
            let session =
                reflectedValue(
                    named:
                        "ruleEditorSession",
                    from:
                        controller,
                    as:
                        RemappingRuleEditorSession.self
                )
        else {
            coordinator.stop()

            XCTFail(
                "The Rules controller or editor session was not created."
            )
            return
        }

        defer {
            session.restoreSavedRules()
            controller.close()
            coordinator.stop()
        }

        for _ in 0..<40 {
            _ = session.insertEmptyItem()
        }

        controller.window?
            .contentView?
            .layoutSubtreeIfNeeded()

        controller.window?
            .displayIfNeeded()

        RunLoop.current.run(
            until:
                Date()
                    .addingTimeInterval(
                        0.1
                    )
        )

        XCTAssertTrue(
            controller
                .usesVirtualizedRulesTableForTesting
        )

        XCTAssertEqual(
            controller
                .visibleRuleItemCountForTesting,
            session.items.count
        )

        let materializedRowCount =
            controller
                .materializedRuleRowCountForTesting

        XCTAssertGreaterThan(
            materializedRowCount,
            0
        )

        XCTAssertLessThan(
            materializedRowCount,
            controller
                .visibleRuleItemCountForTesting
        )
    }

    private func reflectedValue<
        Value
    >(
        named propertyName:
            String,
        from value:
            Any,
        as type:
            Value.Type
    ) -> Value? {
        var currentMirror:
            Mirror? =
                Mirror(
                    reflecting:
                        value
                )

        while let mirror =
            currentMirror
        {
            if let reflectedValue =
                mirror.children
                    .first(
                        where: {
                            $0.label
                                == propertyName
                        }
                    )?
                    .value as? Value
            {
                return reflectedValue
            }

            currentMirror =
                mirror.superclassMirror
        }

        return nil
    }
}
