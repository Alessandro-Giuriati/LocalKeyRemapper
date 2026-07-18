//
//  StatusBarController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

/// Manages the application's menu bar icon and lightweight status popover.
@MainActor
final class StatusBarController:
    NSObject,
    NSPopoverDelegate
{
    private let statusItem:
        NSStatusItem

    private let popover =
        NSPopover()

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

    private var popoverViewController:
        StatusPopoverViewController?

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
        configurePopover()
        observeRemappingState()

        updatePopover(
            for: remappingController.state
        )
    }

    private func configureStatusItem() {
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

        button.target =
            self

        button.action =
            #selector(
                togglePopover
            )
    }

    private func configurePopover() {
        let controller =
            StatusPopoverViewController(
                primaryActionHandler: {
                    [weak self] in

                    self?.performPrimaryAction()
                },
                openSettingsHandler: {
                    [weak self] in

                    self?.closePopover()
                    NSApplication.shared
                        .activate(
                            ignoringOtherApps:
                                true
                        )
                    self?.openSettingsHandler()
                },
                increaseTextSizeHandler: {
                    [weak self] in

                    self?.closePopover()
                    self?.increaseTextSizeHandler()
                },
                decreaseTextSizeHandler: {
                    [weak self] in

                    self?.closePopover()
                    self?.decreaseTextSizeHandler()
                },
                resetTextSizeHandler: {
                    [weak self] in

                    self?.closePopover()
                    self?.resetTextSizeHandler()
                },
                quitHandler: {
                    [weak self] in

                    self?.closePopover()

                    NSApplication.shared
                        .terminate(nil)
                }
            )

        popoverViewController =
            controller

        popover.contentViewController =
            controller

        popover.behavior =
            .transient

        popover.animates =
            true

        popover.delegate =
            self
    }

    private func observeRemappingState() {
        remappingController.onStateChange = {
            [weak self] state in

            self?.updatePopover(
                for: state
            )

            self?
                .remappingStateChangeHandler(
                    state
                )
        }
    }

    private func updatePopover(
        for state:
            RemappingState
    ) {
        popoverViewController?
            .update(
                for: state
            )
    }

    @objc
    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard
            let button =
                statusItem.button
        else {
            return
        }

        updatePopover(
            for:
                remappingController.state
        )

        popover.show(
            relativeTo:
                button.bounds,
            of:
                button,
            preferredEdge:
                .minY
        )

        button.highlight(
            true
        )
    }

    private func closePopover() {
        popover.performClose(nil)

        statusItem.button?
            .highlight(
                false
            )
    }

    func popoverDidClose(
        _ notification:
            Notification
    ) {
        statusItem.button?
            .highlight(
                false
            )
    }

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

        closePopover()

        accessibilitySettingsOpener
            .openAccessibilitySettings()
    }
}
