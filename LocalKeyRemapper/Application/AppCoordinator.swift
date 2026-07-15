//
//  AppCoordinator.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

/// Creates and connects the main application components.
@MainActor
final class AppCoordinator {

    private let permissionService: AccessibilityPermissionService
    private let rulesStore: StaticRulesStore
    private let remappingEngine: RemappingEngine
    private let eventTapManager: EventTapManager
    private let remappingController: RemappingController

    private var statusBarController: StatusBarController?

    init() {
        let permissionService = AccessibilityPermissionService()
        let rulesStore = StaticRulesStore()
        let remappingEngine = RemappingEngine()

        let eventTapManager = EventTapManager(
            remappingEngine: remappingEngine
        )

        let remappingController = RemappingController(
            permissionService: permissionService,
            rulesStore: rulesStore,
            remappingEngine: remappingEngine,
            eventTapManager: eventTapManager
        )

        self.permissionService = permissionService
        self.rulesStore = rulesStore
        self.remappingEngine = remappingEngine
        self.eventTapManager = eventTapManager
        self.remappingController = remappingController
    }

    /// Starts the application user interface.
    func start() {
        statusBarController = StatusBarController(
            remappingController: remappingController
        )
    }

    /// Stops active system components before the application terminates.
    func stop() {
        remappingController.disable()
        statusBarController = nil
    }
}
