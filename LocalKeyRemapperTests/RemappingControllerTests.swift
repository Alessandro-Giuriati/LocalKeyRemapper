//
//  RemappingControllerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import XCTest
@testable import LocalKeyRemapper

@MainActor
final class RemappingControllerTests:
    XCTestCase
{

    func testEnableWithoutPermissionRequestsAccess() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: false
            )

        let rulesStore =
            ControllerMockRulesStore()

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager
            )

        controller.enable()

        XCTAssertEqual(
            controller.state,
            .permissionRequired
        )

        XCTAssertEqual(
            permissionService
                .requestAccessCallCount,
            1
        )

        XCTAssertEqual(
            rulesStore.loadCallCount,
            0
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            0
        )
    }

    func testRulesLoadingFailureUpdatesState() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rulesStore =
            ControllerMockRulesStore()

        rulesStore.loadError =
            ControllerTestError.expected

        let eventTapManager =
            ControllerMockEventTapManager()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    RemappingEngine(),
                eventTapManager:
                    eventTapManager
            )

        controller.enable()

        XCTAssertEqual(
            controller.state,
            .failed(
                .rulesLoadingFailed
            )
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            0
        )
    }

    func testInvalidLoadedRulesPreventEventTapStart() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let invalidRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.v
            )
        ]

        let rulesStore =
            ControllerMockRulesStore(
                rules: invalidRules
            )

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager
            )

        controller.enable()

        XCTAssertEqual(
            controller.state,
            .failed(.invalidRules)
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            0
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .passThrough
        )
    }

    func testEnableWithPermissionStartsEventTap() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let rulesStore =
            ControllerMockRulesStore(
                rules: rules
            )

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager
            )

        controller.enable()

        XCTAssertEqual(
            controller.state,
            .enabled
        )

        XCTAssertEqual(
            rulesStore.loadCallCount,
            1
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            1
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )
    }

    func testEventTapFailureStopsTapAndUpdatesState() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rulesStore =
            ControllerMockRulesStore(
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ]
            )

        let eventTapManager =
            ControllerMockEventTapManager()

        eventTapManager.startError =
            ControllerTestError.expected

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    RemappingEngine(),
                eventTapManager:
                    eventTapManager
            )

        controller.enable()

        XCTAssertEqual(
            controller.state,
            .failed(
                .eventTapStartFailed
            )
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            1
        )

        XCTAssertEqual(
            eventTapManager.stopCallCount,
            1
        )
    }

    func testDisableStopsEventTap() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rulesStore =
            ControllerMockRulesStore()

        let eventTapManager =
            ControllerMockEventTapManager()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    RemappingEngine(),
                eventTapManager:
                    eventTapManager
            )

        controller.enable()
        controller.disable()

        XCTAssertEqual(
            controller.state,
            .disabled
        )

        XCTAssertEqual(
            eventTapManager.stopCallCount,
            1
        )

        XCTAssertFalse(
            eventTapManager.isRunning
        )
    }

    func testKeyCapturePausesAndResumesEnabledTap() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rulesStore =
            ControllerMockRulesStore()

        let eventTapManager =
            ControllerMockEventTapManager()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    RemappingEngine(),
                eventTapManager:
                    eventTapManager
            )

        controller.enable()

        controller.beginKeyCapture()
        controller.beginKeyCapture()

        XCTAssertEqual(
            eventTapManager.pauseCallCount,
            1
        )

        controller.endKeyCapture()
        controller.endKeyCapture()

        XCTAssertEqual(
            eventTapManager.resumeCallCount,
            1
        )
    }

    func testValidReplacementSavesAndUpdatesEngine()
        throws
    {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rulesStore =
            ControllerMockRulesStore()

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager
            )

        let rules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        try controller.replaceConfiguredRules(
            rules
        )

        XCTAssertEqual(
            rulesStore.savedRules,
            rules
        )

        XCTAssertEqual(
            rulesStore.saveCallCount,
            1
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )
    }

    func testInvalidReplacementDoesNotSaveOrUpdateEngine() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rulesStore =
            ControllerMockRulesStore()

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager
            )

        let invalidRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.v
            )
        ]

        do {
            try controller
                .replaceConfiguredRules(
                    invalidRules
                )

            XCTFail(
                "Expected invalid rules to be rejected."
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

        XCTAssertEqual(
            rulesStore.saveCallCount,
            0
        )

        XCTAssertNil(
            rulesStore.savedRules
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .passThrough
        )
    }

    func testStorageFailureDoesNotUpdateEngine() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted: true
            )

        let rulesStore =
            ControllerMockRulesStore()

        rulesStore.saveError =
            ControllerTestError.expected

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager
            )

        let rules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        do {
            try controller
                .replaceConfiguredRules(
                    rules
                )

            XCTFail(
                "Expected storage failure."
            )
        } catch ControllerTestError.expected {
            // Expected error.
        } catch {
            XCTFail(
                "Unexpected error: \(error)"
            )
        }

        XCTAssertEqual(
            rulesStore.saveCallCount,
            1
        )

        XCTAssertEqual(
            engine.decision(
                for: KeyCode.v
            ),
            .passThrough
        )
    }

    private func makeController(
        permissionService:
            ControllerMockPermissionService,
        rulesStore:
            ControllerMockRulesStore,
        engine:
            RemappingEngine,
        eventTapManager:
            ControllerMockEventTapManager
    ) -> RemappingController {
        RemappingController(
            permissionService:
                permissionService,
            rulesStore:
                rulesStore,
            rulesValidator:
                RemappingRulesValidator(),
            remappingEngine:
                engine,
            eventTapManager:
                eventTapManager
        )
    }
}

nonisolated enum ControllerTestError:
    Error
{
    case expected
}

nonisolated final class
ControllerMockPermissionService:
    AccessibilityPermissionChecking
{

    var isGranted: Bool

    private(set) var requestAccessCallCount = 0

    init(isGranted: Bool) {
        self.isGranted = isGranted
    }

    @discardableResult
    func requestAccess() -> Bool {
        requestAccessCallCount += 1
        return isGranted
    }
}

@MainActor
final class ControllerMockRulesStore:
    RulesStore
{

    var rules: [RemapRule]
    var loadError: Error?
    var saveError: Error?

    private(set) var loadCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var savedRules: [RemapRule]?

    init(
        rules: [RemapRule] = []
    ) {
        self.rules = rules
    }

    func loadRules() throws -> [RemapRule] {
        loadCallCount += 1

        if let loadError {
            throw loadError
        }

        return rules
    }

    func saveRules(
        _ rules: [RemapRule]
    ) throws {
        saveCallCount += 1

        if let saveError {
            throw saveError
        }

        self.rules = rules
        savedRules = rules
    }
}

@MainActor
final class ControllerMockEventTapManager:
    EventTapManaging
{

    private(set) var isRunning = false

    var startError: Error?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0

    func start() throws {
        startCallCount += 1

        if let startError {
            throw startError
        }

        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    func pause() {
        pauseCallCount += 1
    }

    func resume() {
        resumeCallCount += 1
    }
}
