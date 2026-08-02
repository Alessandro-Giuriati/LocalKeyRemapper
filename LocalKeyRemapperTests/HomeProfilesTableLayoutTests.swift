//
//  HomeProfilesTableLayoutTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/1/26.
//

import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class HomeProfilesTableLayoutTests:
    XCTestCase
{
    private let metrics =
        HomeProfilesTableLayout.Metrics(
            minimumProfileWidth:
                155,
            rulesWidth:
                60,
            labeledShortcutWidth:
                165,
            symbolShortcutWidth:
                120,
            widestFullDateWidth:
                145,
            abbreviatedDateWidth:
                110,
            numericDateWidth:
                82,
            labeledActionsWidth:
                205,
            symbolActionsWidth:
                116,
            columnSpacing:
                3
        )

    func testFullDateStageUsesCompleteControlsAndFullMonth() {
        let layout =
            layout(
                atMinimumWidthFor:
                    .fullDate
            )

        XCTAssertEqual(
            layout.stage,
            .fullDate
        )

        XCTAssertEqual(
            layout.actionsPresentation,
            .labeled
        )

        XCTAssertEqual(
            layout.shortcutEditPresentation,
            .labeled
        )

        XCTAssertEqual(
            layout.datePresentation,
            .fullMonth
        )
    }

    func testFullDateFallsBackToAbbreviationBeforeActionsCompact() {
        let fullDateMinimum =
            HomeProfilesTableLayout
                .minimumRequiredWidth(
                    for:
                        .fullDate,
                    metrics:
                        metrics
                )

        let layout =
            HomeProfilesTableLayout
                .resolved(
                    availableWidth:
                        fullDateMinimum
                            - 1,
                    metrics:
                        metrics
                )

        XCTAssertEqual(
            layout.stage,
            .abbreviatedDate
        )

        XCTAssertEqual(
            layout.actionsPresentation,
            .labeled
        )

        XCTAssertEqual(
            layout.shortcutEditPresentation,
            .labeled
        )

        XCTAssertEqual(
            layout.datePresentation,
            .abbreviatedMonth
        )
    }

    func testActionsCompactBeforeShortcutEditButton() {
        let abbreviatedMinimum =
            HomeProfilesTableLayout
                .minimumRequiredWidth(
                    for:
                        .abbreviatedDate,
                    metrics:
                        metrics
                )

        let layout =
            HomeProfilesTableLayout
                .resolved(
                    availableWidth:
                        abbreviatedMinimum
                            - 1,
                    metrics:
                        metrics
                )

        XCTAssertEqual(
            layout.stage,
            .compactActions
        )

        XCTAssertEqual(
            layout.actionsPresentation,
            .symbolsOnly
        )

        XCTAssertEqual(
            layout.shortcutEditPresentation,
            .labeled
        )

        XCTAssertEqual(
            layout.datePresentation,
            .abbreviatedMonth
        )
    }

    func testShortcutEditButtonCompactsAfterActions() {
        let compactActionsMinimum =
            HomeProfilesTableLayout
                .minimumRequiredWidth(
                    for:
                        .compactActions,
                    metrics:
                        metrics
                )

        let layout =
            HomeProfilesTableLayout
                .resolved(
                    availableWidth:
                        compactActionsMinimum
                            - 1,
                    metrics:
                        metrics
                )

        XCTAssertEqual(
            layout.stage,
            .compactShortcut
        )

        XCTAssertEqual(
            layout.actionsPresentation,
            .symbolsOnly
        )

        XCTAssertEqual(
            layout.shortcutEditPresentation,
            .symbolOnly
        )

        XCTAssertEqual(
            layout.datePresentation,
            .abbreviatedMonth
        )
    }

    func testDateBecomesNumericOnlyAfterActionsAndShortcutCompact() {
        let compactShortcutMinimum =
            HomeProfilesTableLayout
                .minimumRequiredWidth(
                    for:
                        .compactShortcut,
                    metrics:
                        metrics
                )

        let layout =
            HomeProfilesTableLayout
                .resolved(
                    availableWidth:
                        compactShortcutMinimum
                            - 1,
                    metrics:
                        metrics
                )

        XCTAssertEqual(
            layout.stage,
            .compactDate
        )

        XCTAssertEqual(
            layout.actionsPresentation,
            .symbolsOnly
        )

        XCTAssertEqual(
            layout.shortcutEditPresentation,
            .symbolOnly
        )

        XCTAssertEqual(
            layout.datePresentation,
            .numeric
        )
    }

    func testFullDateThresholdUsesWidestMonthSafetyWidth() {
        let fullDateMinimum =
            HomeProfilesTableLayout
                .minimumRequiredWidth(
                    for:
                        .fullDate,
                    metrics:
                        metrics
                )

        let abbreviatedMinimum =
            HomeProfilesTableLayout
                .minimumRequiredWidth(
                    for:
                        .abbreviatedDate,
                    metrics:
                        metrics
                )

        XCTAssertEqual(
            fullDateMinimum
                - abbreviatedMinimum,
            metrics.widestFullDateWidth
                - metrics.abbreviatedDateWidth,
            accuracy:
                0.001
        )

        let widthThatFitsAbbreviatedButNotTheWidestFullDate =
            fullDateMinimum
                - 1

        XCTAssertGreaterThanOrEqual(
            widthThatFitsAbbreviatedButNotTheWidestFullDate,
            abbreviatedMinimum
        )

        let layout =
            HomeProfilesTableLayout
                .resolved(
                    availableWidth:
                        widthThatFitsAbbreviatedButNotTheWidestFullDate,
                    metrics:
                        metrics
                )

        XCTAssertEqual(
            layout.datePresentation,
            .abbreviatedMonth
        )
    }

    func testProfileColumnReceivesRemainingWidth() {
        let minimumWidth =
            HomeProfilesTableLayout
                .minimumRequiredWidth(
                    for:
                        .fullDate,
                    metrics:
                        metrics
                )

        let additionalWidth:
            CGFloat =
                87

        let layout =
            HomeProfilesTableLayout
                .resolved(
                    availableWidth:
                        minimumWidth
                            + additionalWidth,
                    metrics:
                        metrics
                )

        XCTAssertEqual(
            layout.profileWidth,
            metrics.minimumProfileWidth
                + additionalWidth,
            accuracy:
                0.001
        )

        XCTAssertEqual(
            layout.totalWidth,
            minimumWidth
                + additionalWidth,
            accuracy:
                0.001
        )
    }

    func testEveryStageFitsExactlyAtItsMinimumWidth() {
        for stage in
            HomeProfilesTableLayout
                .Stage
                .allCases
        {
            let minimumWidth =
                HomeProfilesTableLayout
                    .minimumRequiredWidth(
                        for:
                            stage,
                        metrics:
                            metrics
                    )

            let layout =
                HomeProfilesTableLayout
                    .resolved(
                        availableWidth:
                            minimumWidth,
                        metrics:
                            metrics
                    )

            XCTAssertEqual(
                layout.stage,
                stage
            )

            XCTAssertEqual(
                layout.profileWidth,
                metrics.minimumProfileWidth,
                accuracy:
                    0.001
            )

            XCTAssertEqual(
                layout.totalWidth,
                minimumWidth,
                accuracy:
                    0.001
            )
        }
    }

    private func layout(
        atMinimumWidthFor stage:
            HomeProfilesTableLayout.Stage
    ) -> HomeProfilesTableLayout {
        HomeProfilesTableLayout
            .resolved(
                availableWidth:
                    HomeProfilesTableLayout
                        .minimumRequiredWidth(
                            for:
                                stage,
                            metrics:
                                metrics
                        ),
                metrics:
                    metrics
            )
    }
}
