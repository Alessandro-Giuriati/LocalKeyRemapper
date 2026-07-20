//
//  ApplicationMenuController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit

/// Installs the application's native macOS menu commands.
///
/// Text-size actions are real menu commands, so users can replace their
/// shortcuts in System Settings > Keyboard > Keyboard Shortcuts > App
/// Shortcuts. Undo and Redo use the responder chain and are handled by the
/// active main window.
@MainActor
final class ApplicationMenuController:
    NSObject
{
    private let increaseTextSizeHandler: () -> Void
    private let decreaseTextSizeHandler: () -> Void
    private let resetTextSizeHandler: () -> Void
    private let menuBarVisibilityChangeHandler: (Bool) throws -> Void

    private var showMenuBarIconItem: NSMenuItem?

    init(
        increaseTextSizeHandler: @escaping () -> Void,
        decreaseTextSizeHandler: @escaping () -> Void,
        resetTextSizeHandler: @escaping () -> Void,
        showsMenuBarIcon: Bool = true,
        menuBarVisibilityChangeHandler:
            @escaping (Bool) throws -> Void = { _ in }
    ) {
        self.increaseTextSizeHandler =
            increaseTextSizeHandler
        self.decreaseTextSizeHandler =
            decreaseTextSizeHandler
        self.resetTextSizeHandler =
            resetTextSizeHandler
        self.menuBarVisibilityChangeHandler =
            menuBarVisibilityChangeHandler

        super.init()

        installMainMenu(
            showsMenuBarIcon: showsMenuBarIcon
        )
    }

    /// Updates the checkmark shown beside the menu bar preference.
    func updateMenuBarIconVisibility(
        _ showsMenuBarIcon: Bool
    ) {
        showMenuBarIconItem?.state =
            showsMenuBarIcon ? .on : .off
    }

    private func installMainMenu(
        showsMenuBarIcon: Bool
    ) {
        let mainMenu = NSMenu()

        installApplicationMenu(
            in: mainMenu,
            showsMenuBarIcon: showsMenuBarIcon
        )
        installEditMenu(in: mainMenu)
        installViewMenu(in: mainMenu)

        NSApplication.shared.mainMenu = mainMenu
    }

    private func installApplicationMenu(
        in mainMenu: NSMenu,
        showsMenuBarIcon: Bool
    ) {
        let applicationMenuItem = NSMenuItem()
        applicationMenuItem.title = "LocalKeyRemapper"

        let applicationMenu = NSMenu(
            title: "LocalKeyRemapper"
        )

        let showMenuBarIconItem = NSMenuItem(
            title: "Show Icon in Menu Bar",
            action: #selector(toggleMenuBarIcon),
            keyEquivalent: ""
        )
        showMenuBarIconItem.target = self
        showMenuBarIconItem.state =
            showsMenuBarIcon ? .on : .off
        self.showMenuBarIconItem =
            showMenuBarIconItem

        let quitItem = NSMenuItem(
            title: "Quit LocalKeyRemapper",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [
            .command
        ]

        applicationMenu.addItem(showMenuBarIconItem)
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(quitItem)

        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
    }

    private func installEditMenu(
        in mainMenu: NSMenu
    ) {
        let editMenuItem = NSMenuItem()
        editMenuItem.title = "Edit"

        let editMenu = NSMenu(
            title: "Edit"
        )

        let undoItem = NSMenuItem(
            title: "Undo",
            action: Selector(("performRuleEditorUndo:")),
            keyEquivalent: "z"
        )
        undoItem.target = nil
        undoItem.keyEquivalentModifierMask = [
            .command
        ]

        let redoItem = NSMenuItem(
            title: "Redo",
            action: Selector(("performRuleEditorRedo:")),
            keyEquivalent: "z"
        )
        redoItem.target = nil
        redoItem.keyEquivalentModifierMask = [
            .command,
            .shift
        ]

        editMenu.addItem(undoItem)
        editMenu.addItem(redoItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
    }

    private func installViewMenu(
        in mainMenu: NSMenu
    ) {
        let viewMenuItem = NSMenuItem()
        viewMenuItem.title = "View"

        let viewMenu = NSMenu(
            title: "View"
        )

        let increaseItem = NSMenuItem(
            title: "Increase Text Size",
            action: #selector(increaseTextSize),
            keyEquivalent: "+"
        )
        increaseItem.target = self
        increaseItem.keyEquivalentModifierMask = [
            .command
        ]

        let decreaseItem = NSMenuItem(
            title: "Decrease Text Size",
            action: #selector(decreaseTextSize),
            keyEquivalent: "-"
        )
        decreaseItem.target = self
        decreaseItem.keyEquivalentModifierMask = [
            .command
        ]

        let resetItem = NSMenuItem(
            title: "Reset Text Size",
            action: #selector(resetTextSize),
            keyEquivalent: "0"
        )
        resetItem.target = self
        resetItem.keyEquivalentModifierMask = [
            .command
        ]

        viewMenu.addItem(increaseItem)
        viewMenu.addItem(decreaseItem)
        viewMenu.addItem(resetItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
    }

    @objc
    private func toggleMenuBarIcon() {
        guard let showMenuBarIconItem else {
            return
        }

        let requestedVisibility =
            showMenuBarIconItem.state != .on

        do {
            try menuBarVisibilityChangeHandler(
                requestedVisibility
            )
        } catch {
            let alert = NSAlert()
            alert.messageText =
                "The menu bar preference could not be saved."
            alert.informativeText =
                "LocalKeyRemapper kept the previous menu bar setting."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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
