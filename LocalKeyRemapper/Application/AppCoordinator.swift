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
    private let rulesStore: InMemoryRulesStore
    private let remappingEngine: RemappingEngine
    private let eventTapManager: EventTapManager
    private let remappingController: RemappingController

    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    init() {
        let permissionService =
            AccessibilityPermissionService()

        let rulesStore =
            InMemoryRulesStore()

        let remappingEngine =
            RemappingEngine()

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
            remappingController: remappingController,
            accessibilitySettingsOpener: permissionService,
            openSettingsHandler: { [weak self] in
                self?.showSettings()
            }
        )
    }

    /// Checks whether Accessibility permission was granted
    /// after the application becomes active again.
    func applicationDidBecomeActive() {
        guard
            remappingController.state == .permissionRequired
        else {
            return
        }

        remappingController.enable()
    }

    /// Stops active system components before
    /// the application terminates.
    func stop() {
        remappingController.disable()

        settingsWindowController?.close()
        settingsWindowController = nil

        statusBarController = nil
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController =
                SettingsWindowController()
        }

        settingsWindowController?.showWindow(nil)
    }
}
