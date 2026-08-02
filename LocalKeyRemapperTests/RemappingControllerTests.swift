//
//  RemappingControllerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class RemappingControllerTests:
    XCTestCase
{

    func testEnableWithoutPermissionRequestsAccess() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted:
                    false
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
                isGranted:
                    true
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
                isGranted:
                    true
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
                rules:
                    invalidRules
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
            .failed(
                .invalidRules
            )
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            0
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .passThrough
        )
    }

    func testEnableWithPermissionStartsEventTap() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted:
                    true
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
                rules:
                    rules
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
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )
    }

    func testEventTapFailureStopsTapAndUpdatesState() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted:
                    true
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
                isGranted:
                    true
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
                isGranted:
                    true
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
                isGranted:
                    true
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
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )
    }

    func testInvalidReplacementDoesNotSaveOrUpdateEngine() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted:
                    true
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
                for:
                    KeyCode.v
            ),
            .passThrough
        )
    }

    func testStorageFailureDoesNotUpdateEngine() {
        let permissionService =
            ControllerMockPermissionService(
                isGranted:
                    true
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
                for:
                    KeyCode.v
            ),
            .passThrough
        )
    }

    func testEnableLoadsOnlyActiveProfileRules() {
        let activeProfileID =
            UUID(
                uuidString:
                    "B303CC5B-E880-4D32-A7D3-999F98D1DF4D"
            )!

        let inactiveProfileID =
            UUID(
                uuidString:
                    "9A2A0A58-D86E-4747-BED4-95CA10584E7E"
            )!

        let activeRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let inactiveRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.b,
                destinationKeyCode:
                    KeyCode.j
            )
        ]

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            inactiveProfileID,
                        name:
                            "Inactive",
                        rules:
                            inactiveRules
                    ),
                    makeProfile(
                        id:
                            activeProfileID,
                        name:
                            "Active",
                        rules:
                            activeRules
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let rulesStore =
            ControllerMockRulesStore(
                configuration:
                    configuration
            )

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    ControllerMockPermissionService(
                        isGranted:
                            true
                    ),
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
            engine.decision(
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.b
            ),
            .passThrough
        )

        XCTAssertEqual(
            rulesStore.loadCallCount,
            1
        )
    }

    func testLoadingSpecificProfileRulesUsesStableProfileIdentity()
        throws
    {
        let activeProfileID =
            UUID(
                uuidString:
                    "267F3EF8-F243-462C-BC35-C5D632697326"
            )!

        let requestedProfileID =
            UUID(
                uuidString:
                    "8F38D593-E305-4279-9F28-64842681833B"
            )!

        let requestedRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.n,
                destinationKeyCode:
                    KeyCode.r
            )
        ]

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            activeProfileID,
                        name:
                            "Active",
                        rules: [
                            RemapRule(
                                sourceKeyCode:
                                    KeyCode.v,
                                destinationKeyCode:
                                    KeyCode.w
                            )
                        ]
                    ),
                    makeProfile(
                        id:
                            requestedProfileID,
                        name:
                            "Requested",
                        rules:
                            requestedRules
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let rulesStore =
            ControllerMockRulesStore(
                configuration:
                    configuration
            )

        let controller =
            makeController(
                permissionService:
                    ControllerMockPermissionService(
                        isGranted:
                            true
                    ),
                rulesStore:
                    rulesStore,
                engine:
                    RemappingEngine(),
                eventTapManager:
                    ControllerMockEventTapManager()
            )

        let loadedRules =
            try controller.loadConfiguredRules(
                for:
                    requestedProfileID
            )

        XCTAssertEqual(
            loadedRules,
            requestedRules
        )

        XCTAssertEqual(
            rulesStore.loadCallCount,
            1
        )
    }

    func testSavingInactiveProfileDoesNotChangeEnabledEngine()
        throws
    {
        let activeProfileID =
            UUID(
                uuidString:
                    "D0A08076-310A-4276-A96E-6383093146A8"
            )!

        let inactiveProfileID =
            UUID(
                uuidString:
                    "0D79EC90-1250-4F22-96CE-FCE5C0AEE571"
            )!

        let originalTimestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let replacementTimestamp =
            Date(
                timeIntervalSince1970:
                    1_800_000_000
            )

        let activeRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let replacementInactiveRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.n,
                destinationKeyCode:
                    KeyCode.r
            )
        ]

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            activeProfileID,
                        name:
                            "Active",
                        rules:
                            activeRules,
                        timestamp:
                            originalTimestamp
                    ),
                    makeProfile(
                        id:
                            inactiveProfileID,
                        name:
                            "Inactive",
                        rules: [],
                        timestamp:
                            originalTimestamp
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let rulesStore =
            ControllerMockRulesStore(
                configuration:
                    configuration
            )

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    ControllerMockPermissionService(
                        isGranted:
                            true
                    ),
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager,
                dateProvider: {
                    replacementTimestamp
                }
            )

        controller.enable()

        try controller.replaceConfiguredRules(
            replacementInactiveRules,
            for:
                inactiveProfileID
        )

        XCTAssertEqual(
            controller.state,
            .enabled
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            1
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.n
            ),
            .passThrough
        )

        XCTAssertEqual(
            rulesStore
                .savedConfiguration?
                .profile(
                    id:
                        inactiveProfileID
                )?
                .rules,
            replacementInactiveRules
        )

        XCTAssertEqual(
            rulesStore
                .savedConfiguration?
                .profile(
                    id:
                        inactiveProfileID
                )?
                .updatedAt,
            replacementTimestamp
        )

        XCTAssertEqual(
            rulesStore
                .savedConfiguration?
                .profile(
                    id:
                        activeProfileID
                )?
                .updatedAt,
            originalTimestamp
        )
    }

    func testSavingActiveProfileUpdatesEngineWithoutRestartingTap()
        throws
    {
        let activeProfileID =
            UUID(
                uuidString:
                    "A71DB77C-C591-43E2-B315-4C7D6D7B201D"
            )!

        let originalRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let replacementRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.b,
                destinationKeyCode:
                    KeyCode.j
            )
        ]

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            activeProfileID,
                        name:
                            "Active",
                        rules:
                            originalRules
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let rulesStore =
            ControllerMockRulesStore(
                configuration:
                    configuration
            )

        let eventTapManager =
            ControllerMockEventTapManager()

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    ControllerMockPermissionService(
                        isGranted:
                            true
                    ),
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    eventTapManager
            )

        controller.enable()

        try controller.replaceConfiguredRules(
            replacementRules,
            for:
                activeProfileID
        )

        XCTAssertEqual(
            controller.state,
            .enabled
        )

        XCTAssertEqual(
            eventTapManager.startCallCount,
            1
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .passThrough
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.b
            ),
            .replaceKeyCode(
                KeyCode.j
            )
        )

        XCTAssertEqual(
            rulesStore
                .savedConfiguration?
                .activeProfile?
                .rules,
            replacementRules
        )
    }

    func testMissingProfileDoesNotSaveOrChangeEnabledEngine() {
        let activeProfileID =
            UUID(
                uuidString:
                    "E50EE816-FEC4-4BB0-AAD9-3825CA667FF6"
            )!

        let missingProfileID =
            UUID(
                uuidString:
                    "98B25456-14C8-49EC-9374-F20CA5770748"
            )!

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            activeProfileID,
                        name:
                            "Active",
                        rules: [
                            RemapRule(
                                sourceKeyCode:
                                    KeyCode.v,
                                destinationKeyCode:
                                    KeyCode.w
                            )
                        ]
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let rulesStore =
            ControllerMockRulesStore(
                configuration:
                    configuration
            )

        let engine =
            RemappingEngine()

        let controller =
            makeController(
                permissionService:
                    ControllerMockPermissionService(
                        isGranted:
                            true
                    ),
                rulesStore:
                    rulesStore,
                engine:
                    engine,
                eventTapManager:
                    ControllerMockEventTapManager()
            )

        controller.enable()

        XCTAssertThrowsError(
            try controller.replaceConfiguredRules(
                [],
                for:
                    missingProfileID
            )
        ) { error in
            XCTAssertEqual(
                error
                    as? RemappingProfileRulesAccessError,
                .profileNotFound(
                    missingProfileID
                )
            )
        }

        XCTAssertEqual(
            rulesStore.saveCallCount,
            0
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    KeyCode.v
            ),
            .replaceKeyCode(
                KeyCode.w
            )
        )
    }

    func testSavingUnchangedRulesPreservesModificationDate()
        throws
    {
        let activeProfileID =
            UUID(
                uuidString:
                    "DD00FB7D-B10B-47CF-88C2-320A26680E48"
            )!

        let originalTimestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let unusedReplacementTimestamp =
            Date(
                timeIntervalSince1970:
                    1_800_000_000
            )

        let rules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    makeProfile(
                        id:
                            activeProfileID,
                        name:
                            "Active",
                        rules:
                            rules,
                        timestamp:
                            originalTimestamp
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let rulesStore =
            ControllerMockRulesStore(
                configuration:
                    configuration
            )

        let controller =
            makeController(
                permissionService:
                    ControllerMockPermissionService(
                        isGranted:
                            true
                    ),
                rulesStore:
                    rulesStore,
                engine:
                    RemappingEngine(),
                eventTapManager:
                    ControllerMockEventTapManager(),
                dateProvider: {
                    unusedReplacementTimestamp
                }
            )

        try controller.replaceConfiguredRules(
            rules,
            for:
                activeProfileID
        )

        XCTAssertEqual(
            rulesStore
                .savedConfiguration?
                .activeProfile?
                .updatedAt,
            originalTimestamp
        )
    }

    private func makeProfile(
        id: UUID,
        name: String,
        rules: [RemapRule],
        timestamp: Date =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )
    ) -> RemappingProfile {
        RemappingProfile(
            id:
                id,
            name:
                name,
            createdAt:
                timestamp,
            updatedAt:
                timestamp,
            rules:
                rules
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
            ControllerMockEventTapManager,
        dateProvider:
            @escaping () -> Date = {
                Date()
            }
    ) -> RemappingController {
        RemappingController(
            permissionService:
                permissionService,
            profilesStore:
                rulesStore,
            rulesValidator:
                RemappingRulesValidator(),
            remappingEngine:
                engine,
            eventTapManager:
                eventTapManager,
            dateProvider:
                dateProvider
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

    init(
        isGranted: Bool
    ) {
        self.isGranted =
            isGranted
    }

    @discardableResult
    func requestAccess() -> Bool {
        requestAccessCallCount += 1

        return isGranted
    }
}

@MainActor
final class ControllerMockRulesStore:
    RemappingProfilesStore
{
    var configuration:
        RemappingProfilesConfiguration

    var loadError: Error?
    var saveError: Error?

    private(set) var loadCallCount = 0
    private(set) var saveCallCount = 0

    private(set) var savedRules:
        [RemapRule]?

    private(set) var savedConfiguration:
        RemappingProfilesConfiguration?

    init(
        rules: [RemapRule] = []
    ) {
        let profileID =
            UUID()

        configuration =
            RemappingProfilesConfiguration.initial(
                profileID:
                    profileID,
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_700_000_000
                    ),
                defaultRules:
                    rules
            )
    }

    init(
        configuration:
            RemappingProfilesConfiguration
    ) {
        self.configuration =
            configuration
    }

    var rules:
        [RemapRule]
    {
        get {
            configuration
                .activeProfile?
                .rules
                ?? []
        }

        set {
            guard
                let activeProfileIndex =
                    configuration
                        .profiles
                        .firstIndex(
                            where: {
                                $0.id
                                    == configuration
                                        .activeProfileID
                            }
                        )
            else {
                return
            }

            configuration
                .profiles[
                    activeProfileIndex
                ]
                .rules =
                    newValue
        }
    }

    func loadConfiguration()
        throws -> RemappingProfilesConfiguration
    {
        loadCallCount += 1

        if let loadError {
            throw loadError
        }

        return configuration
    }

    func saveConfiguration(
        _ configuration:
            RemappingProfilesConfiguration
    ) throws {
        saveCallCount += 1

        if let saveError {
            throw saveError
        }

        self.configuration =
            configuration

        savedConfiguration =
            configuration

        savedRules =
            configuration
                .activeProfile?
                .rules
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

        isRunning =
            true
    }

    func stop() {
        stopCallCount += 1

        isRunning =
            false
    }

    func pause() {
        pauseCallCount += 1
    }

    func resume() {
        resumeCallCount += 1
    }
}
