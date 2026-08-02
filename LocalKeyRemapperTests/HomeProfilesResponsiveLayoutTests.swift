//
//  HomeProfilesResponsiveLayoutTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/1/26.
//

import AppKit
import Foundation
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class HomeProfilesResponsiveLayoutTests: XCTestCase {
    func testResponsiveStagesUseTheRequiredCompressionOrder() {
        let view = makeView()

        view.applyTableLayoutForTesting(stage: .fullDate)
        XCTAssertEqual(view.currentLayoutStageForTesting, .fullDate)
        XCTAssertEqual(view.currentActionsPresentationForTesting, .labeled)
        XCTAssertEqual(view.currentShortcutEditPresentationForTesting, .labeled)
        XCTAssertEqual(view.currentDatePresentationForTesting, .fullMonth)

        view.applyTableLayoutForTesting(stage: .abbreviatedDate)
        XCTAssertEqual(view.currentLayoutStageForTesting, .abbreviatedDate)
        XCTAssertEqual(view.currentActionsPresentationForTesting, .labeled)
        XCTAssertEqual(view.currentShortcutEditPresentationForTesting, .labeled)
        XCTAssertEqual(
            view.currentDatePresentationForTesting,
            .abbreviatedMonth
        )

        view.applyTableLayoutForTesting(stage: .compactActions)
        XCTAssertEqual(view.currentLayoutStageForTesting, .compactActions)
        XCTAssertEqual(
            view.currentActionsPresentationForTesting,
            .symbolsOnly
        )
        XCTAssertEqual(view.currentShortcutEditPresentationForTesting, .labeled)
        XCTAssertEqual(
            view.currentDatePresentationForTesting,
            .abbreviatedMonth
        )

        view.applyTableLayoutForTesting(stage: .compactShortcut)
        XCTAssertEqual(view.currentLayoutStageForTesting, .compactShortcut)
        XCTAssertEqual(
            view.currentActionsPresentationForTesting,
            .symbolsOnly
        )
        XCTAssertEqual(
            view.currentShortcutEditPresentationForTesting,
            .symbolOnly
        )
        XCTAssertEqual(
            view.currentDatePresentationForTesting,
            .abbreviatedMonth
        )

        view.applyTableLayoutForTesting(stage: .compactDate)
        XCTAssertEqual(view.currentLayoutStageForTesting, .compactDate)
        XCTAssertEqual(
            view.currentActionsPresentationForTesting,
            .symbolsOnly
        )
        XCTAssertEqual(
            view.currentShortcutEditPresentationForTesting,
            .symbolOnly
        )
        XCTAssertEqual(view.currentDatePresentationForTesting, .numeric)
    }

    func testCreatedDateUsesFullAbbreviatedAndNumericFormats() {
        let view = makeView()

        view.applyTableLayoutForTesting(stage: .fullDate)
        XCTAssertEqual(
            view.createdDateTitleForVisibleProfileForTesting(at: 0),
            "September 30, 2026"
        )

        view.applyTableLayoutForTesting(stage: .abbreviatedDate)
        XCTAssertEqual(
            view.createdDateTitleForVisibleProfileForTesting(at: 0),
            "Sep 30, 2026"
        )

        view.applyTableLayoutForTesting(stage: .compactDate)
        XCTAssertEqual(
            view.createdDateTitleForVisibleProfileForTesting(at: 0),
            "9/30/26"
        )
    }

    func testEachAppliedLayoutExactlyUsesItsAvailableWidth() {
        let view = makeView()

        for stage in HomeProfilesTableLayout.Stage.allCases {
            let availableWidth =
                view.minimumWidthForTableLayoutStageForTesting(stage)

            view.applyTableLayoutForTesting(stage: stage)

            XCTAssertEqual(
                view.currentTableLayoutWidthForTesting,
                availableWidth,
                accuracy: 0.001
            )
        }
    }

    func testHorizontalScrollingAndElasticMovementRemainDisabled() {
        let view = makeView()

        for stage in HomeProfilesTableLayout.Stage.allCases {
            view.applyTableLayoutForTesting(stage: stage)

            XCTAssertFalse(view.usesHorizontalScrollingForTesting)
            XCTAssertEqual(
                view.horizontalScrollElasticityForTesting,
                .none
            )
        }
    }

    func testTableDelegatesContinuousResizeToTheProfileColumn() {
        let view = makeView()

        XCTAssertTrue(
            view.usesNativeProfileColumnAutoresizingForTesting
        )
    }

    func testIntermediateWidthInsideOneStageDoesNotRewriteFixedColumns() {
        let view = makeView()
        let minimumWidth =
            view.minimumWidthForTableLayoutStageForTesting(
                .fullDate
            )

        view.applyTableLayoutForTesting(
            stage: .fullDate
        )

        let fixedWidthsBefore =
            Array(
                view.currentColumnWidthsForTesting
                    .dropFirst()
            )

        let widerWidth =
            minimumWidth + 120

        view.applyTableAvailableWidthForTesting(
            widerWidth
        )

        XCTAssertEqual(
            view.currentLayoutStageForTesting,
            .fullDate
        )
        XCTAssertEqual(
            Array(
                view.currentColumnWidthsForTesting
                    .dropFirst()
            ),
            fixedWidthsBefore
        )
        XCTAssertEqual(
            view.currentTableLayoutWidthForTesting,
            widerWidth,
            accuracy: 0.001
        )
    }

    func testActionsColumnsUseMeasuredButtonWidths() {
        let view = makeView()

        let labeledWidth = view.actionsColumnWidthForTesting(
            symbolsOnly: false
        )
        let symbolsOnlyWidth = view.actionsColumnWidthForTesting(
            symbolsOnly: true
        )

        XCTAssertGreaterThan(
            labeledWidth,
            symbolsOnlyWidth
        )

        view.applyTableLayoutForTesting(stage: .fullDate)
        XCTAssertEqual(
            view.currentColumnWidthsForTesting.last ?? -1,
            labeledWidth,
            accuracy: 0.001
        )

        view.applyTableLayoutForTesting(stage: .compactDate)
        XCTAssertEqual(
            view.currentColumnWidthsForTesting.last ?? -1,
            symbolsOnlyWidth,
            accuracy: 0.001
        )
    }

    func testInitialFallbackActionsColumnFitsLabeledButtonsBeforeLayout() {
        let view = makeView()

        XCTAssertEqual(
            view.currentColumnWidthsForTesting.last ?? -1,
            view.actionsColumnWidthForTesting(symbolsOnly: false),
            accuracy: 0.001
        )
    }

    func testActionButtonsHaveARealMinimumClickableWidth() throws {
        let view = makeView()

        let labeledOpenWidth = try XCTUnwrap(
            view.openActionButtonWidthForTesting(
                symbolsOnly: false
            )
        )
        let compactOpenWidth = try XCTUnwrap(
            view.openActionButtonWidthForTesting(
                symbolsOnly: true
            )
        )
        let labeledRenameWidth = try XCTUnwrap(
            view.renameActionButtonWidthForTesting(
                symbolsOnly: false
            )
        )

        XCTAssertGreaterThanOrEqual(
            labeledOpenWidth,
            75
        )
        XCTAssertGreaterThanOrEqual(
            compactOpenWidth,
            30
        )
        XCTAssertGreaterThanOrEqual(
            labeledRenameWidth,
            88
        )
    }

    func testActionButtonsDoNotUseConflictingFixedWidthConstraints() {
        let view = makeView()

        XCTAssertTrue(
            view.actionButtonsUseManualFramesForTesting(
                at: 0,
                stage: .fullDate
            )
        )
        XCTAssertTrue(
            view.actionButtonsUseManualFramesForTesting(
                at: 0,
                stage: .compactDate
            )
        )
    }

    func testOpenActionRemainsHitTestableInEveryPresentation() {
        let view = makeView()

        for stage in HomeProfilesTableLayout.Stage.allCases {
            XCTAssertTrue(
                view.openActionIsHitTestableForTesting(
                    at: 0,
                    stage: stage
                ),
                "Open must remain hit-testable in stage \(stage)."
            )
        }
    }

    func testOpenActionInvokesTheProfileCallbackWhenWideAndCompact() {
        let view = makeView()
        let expectedProfileID = view.visibleProfileIDsForTesting[0]
        var openedProfileIDs: [UUID] = []

        view.onOpenProfile = {
            profileID in

            openedProfileIDs.append(profileID)
        }

        XCTAssertTrue(
            view.performOpenActionClickForTesting(
                at: 0,
                stage: .fullDate
            )
        )
        XCTAssertTrue(
            view.performOpenActionClickForTesting(
                at: 0,
                stage: .compactDate
            )
        )

        XCTAssertEqual(
            openedProfileIDs,
            [
                expectedProfileID,
                expectedProfileID
            ]
        )
    }

    func testLiveResizeUsesOneCompactSafePresentationUntilResizeEnds() {
        let view = makeView()

        view.applyTableLayoutForTesting(stage: .fullDate)
        XCTAssertEqual(view.currentLayoutStageForTesting, .fullDate)

        view.beginTableLiveResizeForTesting()

        XCTAssertTrue(view.isUsingLiveResizeTableLayoutForTesting)
        XCTAssertEqual(view.currentLayoutStageForTesting, .compactDate)
        XCTAssertEqual(
            view.currentActionsPresentationForTesting,
            .symbolsOnly
        )
        XCTAssertEqual(
            view.currentShortcutEditPresentationForTesting,
            .symbolOnly
        )
        XCTAssertEqual(
            view.currentDatePresentationForTesting,
            .numeric
        )
    }

    func testLiveResizeRestoresTheFinalResponsiveStageOnceItEnds() {
        let view = makeView()

        view.applyTableLayoutForTesting(stage: .fullDate)
        view.beginTableLiveResizeForTesting()

        let finalWidth =
            view.minimumWidthForTableLayoutStageForTesting(
                .abbreviatedDate
            )

        view.endTableLiveResizeForTesting(
            availableWidth: finalWidth
        )

        XCTAssertFalse(view.isUsingLiveResizeTableLayoutForTesting)
        XCTAssertEqual(
            view.currentLayoutStageForTesting,
            .abbreviatedDate
        )
        XCTAssertEqual(
            view.currentActionsPresentationForTesting,
            .labeled
        )
        XCTAssertEqual(
            view.currentShortcutEditPresentationForTesting,
            .labeled
        )
        XCTAssertEqual(
            view.currentDatePresentationForTesting,
            .abbreviatedMonth
        )
    }

    private func makeView() -> HomeProfilesSectionView {
        let locale = Locale(identifier: "en_US")

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let createdAt = calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 9,
                day: 30
            )
        )!

        let profile = RemappingProfile(
            name: "Responsive Profile",
            createdAt: createdAt
        )

        let configuration = RemappingProfilesConfiguration(
            profiles: [profile],
            activeProfileID: profile.id
        )

        let session = HomeConfigurationEditorSession(
            snapshot: HomeConfigurationSnapshot(
                profilesConfiguration: configuration,
                launchBehavior: .alwaysOff,
                shortcutConfiguration: .disabled
            )
        )

        return HomeProfilesSectionView(
            editorSession: session,
            initialConfiguration: configuration,
            dateLocale: locale,
            dateCalendar: calendar
        )
    }
}
