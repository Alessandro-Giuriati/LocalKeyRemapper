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

    private let increaseTextSizeHandler:
        () -> Void

    private let decreaseTextSizeHandler:
        () -> Void

    private let resetTextSizeHandler:
        () -> Void

    private let remappingStateChangeHandler:
        (RemappingState) -> Void

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
            @escaping () -> Void,
        increaseTextSizeHandler:
            @escaping () -> Void,
        decreaseTextSizeHandler:
            @escaping () -> Void,
        resetTextSizeHandler:
            @escaping () -> Void,
        remappingStateChangeHandler:
            @escaping (RemappingState) -> Void
    ) {
        self.remappingController =
            remappingController

        self.accessibilitySettingsOpener =
            accessibilitySettingsOpener

        self.openSettingsHandler =
            openSettingsHandler

        self.increaseTextSizeHandler =
            increaseTextSizeHandler

        self.decreaseTextSizeHandler =
            decreaseTextSizeHandler

        self.resetTextSizeHandler =
            resetTextSizeHandler

        self.remappingStateChangeHandler =
            remappingStateChangeHandler

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

        let textSizeMenuItem = NSMenuItem(
            title: "Text Size",
            action: nil,
            keyEquivalent: ""
        )

        textSizeMenuItem.submenu = makeTextSizeMenu()

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
        menu.addItem(textSizeMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)

        statusItem.menu = menu

        self.stateMenuItem =
            stateMenuItem

        self.toggleMenuItem =
            toggleMenuItem
    }

    private func makeTextSizeMenu() -> NSMenu {
        let menu = NSMenu(title: "Text Size")

        let increaseItem = NSMenuItem(
            title: "Increase Text Size",
            action: #selector(increaseTextSize),
            keyEquivalent: "+"
        )

        increaseItem.target = self
        increaseItem.keyEquivalentModifierMask = [.command]

        let decreaseItem = NSMenuItem(
            title: "Decrease Text Size",
            action: #selector(decreaseTextSize),
            keyEquivalent: "-"
        )

        decreaseItem.target = self
        decreaseItem.keyEquivalentModifierMask = [.command]

        let resetItem = NSMenuItem(
            title: "Reset Text Size",
            action: #selector(resetTextSize),
            keyEquivalent: "0"
        )

        resetItem.target = self
        resetItem.keyEquivalentModifierMask = [.command]

        menu.addItem(increaseItem)
        menu.addItem(decreaseItem)
        menu.addItem(resetItem)

        return menu
    }

    private func observeRemappingState() {
        remappingController.onStateChange = {
            [weak self] state in

            self?.updateMenu(for: state)
            self?.remappingStateChangeHandler(state)
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
    private func increaseTextSize() {
        increaseTextSizeHandler()
    }

    @objc
    private func decreaseTextSize() {
        decreaseTextSizeHandler()
    }

    @objc
    private func resetTextSize() {
        resetTextSizeHandler()
    }

    @objc
    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
