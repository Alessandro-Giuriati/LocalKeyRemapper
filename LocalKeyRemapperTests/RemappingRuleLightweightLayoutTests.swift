//
//  RemappingRuleLightweightLayoutTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/4/26.
//

import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class RemappingRuleLightweightLayoutTests:
    XCTestCase
{
    func testRuleRowUsesManualFrameLayoutWithoutBackingLayer() {
        let row =
            RemappingRuleRowView()

        row.frame =
            NSRect(
                x: 0,
                y: 0,
                width: 1100,
                height: 42
            )

        row.layout()

        XCTAssertEqual(
            row.subviews.count,
            9
        )

        XCTAssertTrue(
            row.subviews.allSatisfy {
                $0.translatesAutoresizingMaskIntoConstraints
            }
        )

        XCTAssertFalse(
            row.usesBackingLayerForTesting
        )

        let widths =
            row.sourceAndDestinationWidthsForTesting

        XCTAssertEqual(
            widths.0,
            widths.1,
            accuracy: 0.001
        )
    }

    func testRuleRowControlFramesRemainOrderedAndInsideBounds() {
        let row =
            RemappingRuleRowView()

        row.frame =
            NSRect(
                x: 0,
                y: 0,
                width: 1100,
                height: 42
            )

        row.layout()

        let frames =
            row.orderedControlFramesForTesting

        XCTAssertEqual(
            frames.count,
            9
        )

        for frame in frames {
            XCTAssertGreaterThanOrEqual(
                frame.minX,
                row.bounds.minX
            )

            XCTAssertLessThanOrEqual(
                frame.maxX,
                row.bounds.maxX
            )

            XCTAssertGreaterThanOrEqual(
                frame.minY,
                row.bounds.minY
            )

            XCTAssertLessThanOrEqual(
                frame.maxY,
                row.bounds.maxY
            )
        }

        for pair in zip(
            frames,
            frames.dropFirst()
        ) {
            XCTAssertLessThanOrEqual(
                pair.0.maxX,
                pair.1.minX
            )
        }
    }

    func testValidationDrawingDoesNotCreateBackingLayer() {
        let row =
            RemappingRuleRowView()

        row.setValidationErrorVisible(
            true
        )

        XCTAssertFalse(
            row.usesBackingLayerForTesting
        )
    }

    func testIssuesViewUsesManualLayoutAndDoesNotRebuildSymbolsForMessages() {
        let view =
            RemappingRuleIssuesView()

        view.frame =
            NSRect(
                x: 0,
                y: 0,
                width: 72,
                height: 34
            )

        let initialSymbolUpdates =
            view.symbolUpdateCountForTesting

        view.setValidationMessage(
            "Validation"
        )

        view.setConfigurationWarningMessage(
            "Warning"
        )

        view.layout()

        XCTAssertEqual(
            view.subviews.count,
            2
        )

        XCTAssertTrue(
            view.subviews.allSatisfy {
                $0.translatesAutoresizingMaskIntoConstraints
            }
        )

        XCTAssertEqual(
            view.symbolUpdateCountForTesting,
            initialSymbolUpdates
        )

        let frames =
            view.indicatorFramesForTesting

        XCTAssertLessThan(
            frames.validation.midX,
            frames.warning.midX
        )
    }
}
