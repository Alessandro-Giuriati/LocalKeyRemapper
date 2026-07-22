//
//  FnModifierStateTrackerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import XCTest
@testable import LocalKeyRemapper

final class FnModifierStateTrackerTests:
    XCTestCase
{
    func testInitialStateIsReleased() {
        let tracker =
            FnModifierStateTracker()

        XCTAssertFalse(
            tracker.isPressed
        )
    }

    func testFlagsChangedPressRemainsLatchedUntilReleaseEvent() {
        var tracker =
            FnModifierStateTracker()

        tracker.handleFlagsChanged(
            isPressed:
                true
        )

        XCTAssertTrue(
            tracker.isPressed
        )

        // No hardware-state resampling occurs while processing the key event.
        XCTAssertTrue(
            tracker.isPressed
        )
    }

    func testFlagsChangedReleaseClearsPressedState() {
        var tracker =
            FnModifierStateTracker()

        tracker.handleFlagsChanged(
            isPressed:
                true
        )
        tracker.handleFlagsChanged(
            isPressed:
                false
        )

        XCTAssertFalse(
            tracker.isPressed
        )
    }

    func testSynchronizeAndResetControlLifecycleState() {
        var tracker =
            FnModifierStateTracker()

        tracker.synchronize(
            isPressed:
                true
        )

        XCTAssertTrue(
            tracker.isPressed
        )

        tracker.reset()

        XCTAssertFalse(
            tracker.isPressed
        )
    }
}
