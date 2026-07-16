//
//  StatusBarController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

/// Manages the application's menu bar interface.
@MainActor
final class StatusBarController: NSObject {

    private let statusItem:
        NSStatusItem

    private let remappingController:
        RemappingControlling

    private let accessibilitySettingsOpener:
        AccessibilitySettingsOpening

    private let openSettingsHandler:
        () -> Void

    private var stateMenuItem:
        NSMenuItem?

    private var toggleMenuItem:
        NSMenuItem?

    init(
        remappingController:
            RemappingControlling,
        accessibilitySettingsOpener:
            AccessibilitySettingsOpening,
        openSettingsHandler:
            @escaping () -> Void
    ) {
        self.remappingController =
            remappingController

        self.accessibilitySettingsOpener =
            accessibilitySettingsOpener

        self.openSettingsHandler =
            openSettingsHandler

        statusItem =
            NSStatusBar.system.statusItem(
                withLength:
                    NSStatusItem.squareLength
            )

        super.init()

        configureStatusItem()
        observeRemappingState()

        updateMenu(
            for: remappingController.state
        )
    }

    private func configureStatusItem() {
        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription:
                "LocalKeyRemapper"
        ) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "KR"
        }

        button.toolTip =
            "LocalKeyRemapper"
    }

    private func configureMenu() {
        let menu = NSMenu()

        let stateMenuItem =
            NSMenuItem(
                title: "Remapping: Off",
                action: nil,
                keyEquivalent: ""
            )

        stateMenuItem.isEnabled = false

        let toggleMenuItem =
            NSMenuItem(
                title: "Enable Remapping",
                action:
                    #selector(
                        performPrimaryAction
                    ),
                keyEquivalent: ""
            )

        toggleMenuItem.target = self

        let settingsMenuItem =
            NSMenuItem(
                title: "Settings…",
                action:
                    #selector(openSettings),
                keyEquivalent: ","
            )

        settingsMenuItem.target = self

        let quitMenuItem =
            NSMenuItem(
                title:
                    "Quit LocalKeyRemapper",
                action:
                    #selector(
                        quitApplication
                    ),
                keyEquivalent: "q"
            )

        quitMenuItem.target = self

        menu.addItem(stateMenuItem)
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())
        menu.addItem(settingsMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)

        statusItem.menu = menu

        self.stateMenuItem =
            stateMenuItem

        self.toggleMenuItem =
            toggleMenuItem
    }

    private func observeRemappingState() {
        remappingController.onStateChange = {
            [weak self] state in

            self?.updateMenu(for: state)
        }
    }

    private func updateMenu(
        for state: RemappingState
    ) {
        switch state {
        case .disabled:
            stateMenuItem?.title =
                "Remapping: Off"

            toggleMenuItem?.title =
                "Enable Remapping"

            toggleMenuItem?.isEnabled =
                true

        case .enabling:
            stateMenuItem?.title =
                "Remapping: Enabling…"

            toggleMenuItem?.title =
                "Cancel"

            toggleMenuItem?.isEnabled =
                true

        case .enabled:
            stateMenuItem?.title =
                "Remapping: On"

            toggleMenuItem?.title =
                "Disable Remapping"

            toggleMenuItem?.isEnabled =
                true

        case .permissionRequired:
            stateMenuItem?.title =
                "Accessibility Permission Required"

            toggleMenuItem?.title =
                "Open Accessibility Settings…"

            toggleMenuItem?.isEnabled =
                true

        case .failed(let failure):
            updateMenuForFailure(failure)
        }
    }

    private func updateMenuForFailure(
        _ failure: RemappingFailure
    ) {
        switch failure {
        case .rulesLoadingFailed:
            stateMenuItem?.title =
                "Error: Rules Could Not Load"

        case .invalidRules:
            stateMenuItem?.title =
                "Error: Invalid Remapping Rules"

        case .eventTapStartFailed:
            stateMenuItem?.title =
                "Error: Event Tap Could Not Start"
        }

        toggleMenuItem?.title =
            "Try Again"

        toggleMenuItem?.isEnabled =
            true
    }

    @objc
    private func performPrimaryAction() {
        if remappingController.state
            == .permissionRequired
        {
            checkPermissionOrOpenSettings()
            return
        }

        remappingController.toggle()
    }

    private func checkPermissionOrOpenSettings() {
        remappingController.enable()

        guard
            remappingController.state
                == .permissionRequired
        else {
            return
        }

        accessibilitySettingsOpener
            .openAccessibilitySettings()
    }

    @objc
    private func openSettings() {
        openSettingsHandler()
    }

    @objc
    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
