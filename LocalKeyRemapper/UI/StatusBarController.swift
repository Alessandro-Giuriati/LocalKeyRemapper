//
//  StatusBarController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

/// Manages the application's optional menu bar icon
/// and lightweight status popover.
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

    private let refreshRemappingStateHandler:
        () -> Void

    private let openMainWindowHandler:
        () -> Void

    private let increaseTextSizeHandler:
        () -> Void

    private let decreaseTextSizeHandler:
        () -> Void

    private let resetTextSizeHandler:
        () -> Void

    private var popoverViewController:
        StatusPopoverViewController?

    init(
        remappingController:
            RemappingControlling,
        accessibilitySettingsOpener:
            AccessibilitySettingsOpening,
        refreshRemappingStateHandler:
            @escaping () -> Void = {},
        openSettingsHandler:
            @escaping () -> Void,
        increaseTextSizeHandler:
            @escaping () -> Void,
        decreaseTextSizeHandler:
            @escaping () -> Void,
        resetTextSizeHandler:
            @escaping () -> Void
    ) {
        self.remappingController =
            remappingController

        self.accessibilitySettingsOpener =
            accessibilitySettingsOpener

        self.refreshRemappingStateHandler =
            refreshRemappingStateHandler

        self.openMainWindowHandler =
            openSettingsHandler

        self.increaseTextSizeHandler =
            increaseTextSizeHandler

        self.decreaseTextSizeHandler =
            decreaseTextSizeHandler

        self.resetTextSizeHandler =
            resetTextSizeHandler

        statusItem =
            NSStatusBar.system
                .statusItem(
                    withLength:
                        NSStatusItem
                            .squareLength
                )

        super.init()

        configureStatusItem()
        configurePopover()

        update(
            for:
                remappingController.state
        )
    }

    /// Refreshes the popover using the real backend state.
    func update(
        for state:
            RemappingState
    ) {
        popoverViewController?
            .update(
                for:
                    state
            )
    }

    /// Removes the menu bar item and closes its popover.
    ///
    /// The remapping backend and global shortcut remain active.
    func stop() {
        closePopover()

        NSStatusBar.system
            .removeStatusItem(
                statusItem
            )
    }

    private func configureStatusItem() {
        guard
            let button =
                statusItem.button
        else {
            return
        }

        if
            let image =
                NSImage(
                    systemSymbolName:
                        "keyboard",
                    accessibilityDescription:
                        "LocalKeyRemapper"
                )
        {
            image.isTemplate =
                true

            button.image =
                image
        } else {
            button.title =
                "KR"
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

                    self?
                        .performPrimaryAction()
                },
                openSettingsHandler: {
                    [weak self] in

                    self?
                        .closePopover()

                    NSApplication.shared
                        .activate(
                            ignoringOtherApps:
                                true
                        )

                    self?
                        .openMainWindowHandler()
                },
                increaseTextSizeHandler: {
                    [weak self] in

                    self?
                        .closePopover()

                    self?
                        .increaseTextSizeHandler()
                },
                decreaseTextSizeHandler: {
                    [weak self] in

                    self?
                        .closePopover()

                    self?
                        .decreaseTextSizeHandler()
                },
                resetTextSizeHandler: {
                    [weak self] in

                    self?
                        .closePopover()

                    self?
                        .resetTextSizeHandler()
                },
                quitHandler: {
                    [weak self] in

                    self?
                        .closePopover()

                    NSApplication.shared
                        .terminate(
                            nil
                        )
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

        refreshRemappingStateHandler()

        update(
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
        popover.performClose(
            nil
        )

        statusItem.button?
            .highlight(
                false
            )
    }

    func popoverDidShow(
        _ notification:
            Notification
    ) {
        configureDisplayedPopoverWindow()
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

    /// Keeps only the status popover above a full-screen application.
    ///
    /// This does not activate LocalKeyRemapper and does not bring its main
    /// window forward. The currently active application remains active.
    private func configureDisplayedPopoverWindow() {
        guard
            let window =
                popover.contentViewController?
                    .view
                    .window
        else {
            return
        }

        window.level =
            .popUpMenu

        var collectionBehavior:
            NSWindow.CollectionBehavior = [
                .canJoinAllSpaces,
                .transient
            ]

        if #available(macOS 26.0, *) {
            collectionBehavior.insert(
                .canJoinAllApplications
            )
        } else {
            collectionBehavior.insert(
                .fullScreenAuxiliary
            )
        }

        window.collectionBehavior
            .formUnion(
                collectionBehavior
            )

        window.orderFrontRegardless()
    }

    private func performPrimaryAction() {
        if
            remappingController.state
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
