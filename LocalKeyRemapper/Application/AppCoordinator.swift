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

    private let permissionService:
        AccessibilityPermissionService

    private let rulesStore:
        UserDefaultsRulesStore

    private let rulesValidator:
        RemappingRulesValidator

    private let remappingEngine:
        RemappingEngine

    private let eventTapManager:
        EventTapManager

    private let remappingController:
        RemappingController

    private var applicationMenuController:
        ApplicationMenuController?

    private var statusBarController:
        StatusBarController?

    private var settingsWindowController:
        SettingsWindowController?

    init() {
        let permissionService =
            AccessibilityPermissionService()

        let rulesStore =
            UserDefaultsRulesStore()

        let rulesValidator =
            RemappingRulesValidator()

        let remappingEngine =
            RemappingEngine()

        let eventTapManager =
            EventTapManager(
                remappingEngine: remappingEngine
            )

        let remappingController =
            RemappingController(
                permissionService:
                    permissionService,
                rulesStore:
                    rulesStore,
                rulesValidator:
                    rulesValidator,
                remappingEngine:
                    remappingEngine,
                eventTapManager:
                    eventTapManager
            )

        self.permissionService =
            permissionService

        self.rulesStore =
            rulesStore

        self.rulesValidator =
            rulesValidator

        self.remappingEngine =
            remappingEngine

        self.eventTapManager =
            eventTapManager

        self.remappingController =
            remappingController
    }

    /// Starts the application user interface.
    func start() {
        applicationMenuController =
            ApplicationMenuController(
                increaseTextSizeHandler: {
                    [weak self] in

                    self?.increaseTextSize()
                },
                decreaseTextSizeHandler: {
                    [weak self] in

                    self?.decreaseTextSize()
                },
                resetTextSizeHandler: {
                    [weak self] in

                    self?.resetTextSize()
                }
            )

        statusBarController =
            StatusBarController(
                remappingController:
                    remappingController,
                accessibilitySettingsOpener:
                    permissionService,
                openSettingsHandler: {
                    [weak self] in

                    self?.showSettings()
                },
                increaseTextSizeHandler: {
                    [weak self] in

                    self?.increaseTextSize()
                },
                decreaseTextSizeHandler: {
                    [weak self] in

                    self?.decreaseTextSize()
                },
                resetTextSizeHandler: {
                    [weak self] in

                    self?.resetTextSize()
                }
            )
    }

    /// Checks whether Accessibility permission was granted
    /// after the application becomes active again.
    func applicationDidBecomeActive() {
        guard
            remappingController.state
                == .permissionRequired
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
        applicationMenuController = nil
    }

    private func settingsController()
        -> SettingsWindowController
    {
        if let settingsWindowController {
            return settingsWindowController
        }

        let controller = SettingsWindowController(
            remappingController:
                remappingController
        )

        settingsWindowController = controller
        return controller
    }

    private func showSettings() {
        settingsController().showWindow(nil)
    }

    private func increaseTextSize() {
        let controller = settingsController()

        if controller.window?.isVisible != true {
            controller.showWindow(nil)
        }

        controller.increaseTextSize()
    }

    private func decreaseTextSize() {
        let controller = settingsController()

        if controller.window?.isVisible != true {
            controller.showWindow(nil)
        }

        controller.decreaseTextSize()
    }

    private func resetTextSize() {
        let controller = settingsController()

        if controller.window?.isVisible != true {
            controller.showWindow(nil)
        }

        controller.resetTextSize()
    }
}
