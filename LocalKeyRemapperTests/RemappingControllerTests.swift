//
//  RemappingControllerTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import Testing
@testable import LocalKeyRemapper

@Suite("Remapping Controller")
struct RemappingControllerTests {

    @Test("Enabling starts the event tap when permission is granted")
    @MainActor
    func enableStartsEventTapWhenPermissionIsGranted() {
        let permissionService = FakePermissionService(
            isGranted: true
        )

        let rulesStore = FakeRulesStore(
            rules: [
                RemapRule(
                    sourceKeyCode: KeyCode.v,
                    destinationKeyCode: KeyCode.w
                )
            ]
        )

        let remappingEngine = RemappingEngine()
        let eventTapManager = FakeEventTapManager()

        let controller = RemappingController(
            permissionService: permissionService,
            rulesStore: rulesStore,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager
        )

        controller.enable()

        #expect(controller.state == .enabled)
        #expect(eventTapManager.startCallCount == 1)
        #expect(eventTapManager.stopCallCount == 0)

        #expect(
            remappingEngine.decision(for: KeyCode.v)
                == .replaceKeyCode(KeyCode.w)
        )
    }

    @Test("Enabling requests permission when permission is missing")
    @MainActor
    func enableRequestsPermissionWhenPermissionIsMissing() {
        let permissionService = FakePermissionService(
            isGranted: false
        )

        let rulesStore = FakeRulesStore(rules: [])
        let remappingEngine = RemappingEngine()
        let eventTapManager = FakeEventTapManager()

        let controller = RemappingController(
            permissionService: permissionService,
            rulesStore: rulesStore,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager
        )

        controller.enable()

        #expect(controller.state == .permissionRequired)
        #expect(permissionService.requestAccessCallCount == 1)
        #expect(eventTapManager.startCallCount == 0)
    }

    @Test("Disabling stops the event tap")
    @MainActor
    func disableStopsEventTap() {
        let permissionService = FakePermissionService(
            isGranted: true
        )

        let rulesStore = FakeRulesStore(rules: [])
        let remappingEngine = RemappingEngine()
        let eventTapManager = FakeEventTapManager()

        let controller = RemappingController(
            permissionService: permissionService,
            rulesStore: rulesStore,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager
        )

        controller.enable()
        controller.disable()

        #expect(controller.state == .disabled)
        #expect(eventTapManager.stopCallCount == 1)
    }

    @Test("A rules loading failure does not start the event tap")
    @MainActor
    func rulesLoadingFailureDoesNotStartEventTap() {
        let permissionService = FakePermissionService(
            isGranted: true
        )

        let rulesStore = FakeRulesStore(
            error: FakeRulesStoreError.expectedFailure
        )

        let remappingEngine = RemappingEngine()
        let eventTapManager = FakeEventTapManager()

        let controller = RemappingController(
            permissionService: permissionService,
            rulesStore: rulesStore,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager
        )

        controller.enable()

        #expect(
            controller.state == .failed(.rulesLoadingFailed)
        )

        #expect(eventTapManager.startCallCount == 0)
    }

    @Test("An event tap failure sets the failed state")
    @MainActor
    func eventTapFailureSetsFailedState() {
        let permissionService = FakePermissionService(
            isGranted: true
        )

        let rulesStore = FakeRulesStore(rules: [])
        let remappingEngine = RemappingEngine()

        let eventTapManager = FakeEventTapManager(
            shouldFailWhenStarting: true
        )

        let controller = RemappingController(
            permissionService: permissionService,
            rulesStore: rulesStore,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager
        )

        controller.enable()

        #expect(
            controller.state == .failed(.eventTapStartFailed)
        )

        #expect(eventTapManager.startCallCount == 1)
        #expect(eventTapManager.stopCallCount == 1)
    }

    @Test("Loading configured rules returns the stored rules")
    @MainActor
    func loadingConfiguredRulesReturnsStoredRules() throws {
        let expectedRules = [
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            )
        ]

        let rulesStore = FakeRulesStore(
            rules: expectedRules
        )

        let controller = RemappingController(
            permissionService: FakePermissionService(
                isGranted: true
            ),
            rulesStore: rulesStore,
            remappingEngine: RemappingEngine(),
            eventTapManager: FakeEventTapManager()
        )

        let loadedRules = try controller.loadConfiguredRules()

        #expect(loadedRules == expectedRules)
    }

    @Test("Replacing configured rules updates the store and engine")
    @MainActor
    func replacingConfiguredRulesUpdatesStoreAndEngine() throws {
        let rulesStore = FakeRulesStore(
            rules: [
                RemapRule(
                    sourceKeyCode: KeyCode.v,
                    destinationKeyCode: KeyCode.w
                )
            ]
        )

        let remappingEngine = RemappingEngine()

        let controller = RemappingController(
            permissionService: FakePermissionService(
                isGranted: true
            ),
            rulesStore: rulesStore,
            remappingEngine: remappingEngine,
            eventTapManager: FakeEventTapManager()
        )

        let replacementRules = [
            RemapRule(
                sourceKeyCode: KeyCode.w,
                destinationKeyCode: KeyCode.v
            )
        ]

        try controller.replaceConfiguredRules(
            replacementRules
        )

        let storedRules = try rulesStore.loadRules()

        #expect(storedRules == replacementRules)

        #expect(
            remappingEngine.decision(for: KeyCode.w)
                == .replaceKeyCode(KeyCode.v)
        )

        #expect(
            remappingEngine.decision(for: KeyCode.v)
                == .passThrough
        )
    }

    @Test("Beginning key capture pauses an enabled event tap")
    @MainActor
    func beginningKeyCapturePausesEnabledEventTap() {
        let eventTapManager = FakeEventTapManager()

        let controller = RemappingController(
            permissionService: FakePermissionService(
                isGranted: true
            ),
            rulesStore: FakeRulesStore(rules: []),
            remappingEngine: RemappingEngine(),
            eventTapManager: eventTapManager
        )

        controller.enable()
        controller.beginKeyCapture()

        #expect(controller.state == .enabled)
        #expect(eventTapManager.pauseCallCount == 1)

        controller.beginKeyCapture()

        #expect(eventTapManager.pauseCallCount == 1)
    }

    @Test("Ending key capture resumes an enabled event tap")
    @MainActor
    func endingKeyCaptureResumesEnabledEventTap() {
        let eventTapManager = FakeEventTapManager()

        let controller = RemappingController(
            permissionService: FakePermissionService(
                isGranted: true
            ),
            rulesStore: FakeRulesStore(rules: []),
            remappingEngine: RemappingEngine(),
            eventTapManager: eventTapManager
        )

        controller.enable()
        controller.beginKeyCapture()
        controller.endKeyCapture()

        #expect(eventTapManager.pauseCallCount == 1)
        #expect(eventTapManager.resumeCallCount == 1)

        controller.endKeyCapture()

        #expect(eventTapManager.resumeCallCount == 1)
    }

    @Test("Enabling while key capture is active starts and pauses the tap")
    @MainActor
    func enablingDuringKeyCaptureStartsAndPausesEventTap() {
        let eventTapManager = FakeEventTapManager()

        let controller = RemappingController(
            permissionService: FakePermissionService(
                isGranted: true
            ),
            rulesStore: FakeRulesStore(rules: []),
            remappingEngine: RemappingEngine(),
            eventTapManager: eventTapManager
        )

        controller.beginKeyCapture()
        controller.enable()

        #expect(controller.state == .enabled)
        #expect(eventTapManager.startCallCount == 1)
        #expect(eventTapManager.pauseCallCount == 1)

        controller.endKeyCapture()

        #expect(eventTapManager.resumeCallCount == 1)
    }
}

private nonisolated final class FakePermissionService:
    AccessibilityPermissionChecking {

    let isGranted: Bool

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
private final class FakeRulesStore: RulesStore {

    private(set) var rules: [RemapRule]
    private let error: Error?

    init(
        rules: [RemapRule] = [],
        error: Error? = nil
    ) {
        self.rules = rules
        self.error = error
    }

    func loadRules() throws -> [RemapRule] {
        if let error {
            throw error
        }

        return rules
    }

    func saveRules(
        _ rules: [RemapRule]
    ) throws {
        if let error {
            throw error
        }

        self.rules = rules
    }
}

private nonisolated enum FakeRulesStoreError: Error {

    case expectedFailure
}

@MainActor
private final class FakeEventTapManager: EventTapManaging {

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0

    private let shouldFailWhenStarting: Bool

    var isRunning: Bool {
        startCallCount > stopCallCount
    }

    init(
        shouldFailWhenStarting: Bool = false
    ) {
        self.shouldFailWhenStarting =
            shouldFailWhenStarting
    }

    func start() throws {
        startCallCount += 1

        if shouldFailWhenStarting {
            throw FakeEventTapError.expectedFailure
        }
    }

    func stop() {
        stopCallCount += 1
    }

    func pause() {
        pauseCallCount += 1
    }

    func resume() {
        resumeCallCount += 1
    }
}

private nonisolated enum FakeEventTapError: Error {

    case expectedFailure
}
