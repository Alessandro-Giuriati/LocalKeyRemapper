//
//  ApplicationMenuController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit

/// Installs the application's native macOS menu commands.
///
/// Because text-size actions are real menu commands, users can
/// replace their keyboard shortcuts in System Settings > Keyboard >
/// Keyboard Shortcuts > App Shortcuts.
@MainActor
final class ApplicationMenuController: NSObject {

    private let increaseTextSizeHandler: () -> Void
    private let decreaseTextSizeHandler: () -> Void
    private let resetTextSizeHandler: () -> Void

    init(
        increaseTextSizeHandler: @escaping () -> Void,
        decreaseTextSizeHandler: @escaping () -> Void,
        resetTextSizeHandler: @escaping () -> Void
    ) {
        self.increaseTextSizeHandler = increaseTextSizeHandler
        self.decreaseTextSizeHandler = decreaseTextSizeHandler
        self.resetTextSizeHandler = resetTextSizeHandler

        super.init()

        installMainMenu()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let applicationMenuItem = NSMenuItem()
        applicationMenuItem.title = "LocalKeyRemapper"

        let applicationMenu = NSMenu(
            title: "LocalKeyRemapper"
        )

        let quitItem = NSMenuItem(
            title: "Quit LocalKeyRemapper",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )

        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]

        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        let viewMenuItem = NSMenuItem()
        viewMenuItem.title = "View"

        let viewMenu = NSMenu(title: "View")

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

        viewMenu.addItem(increaseItem)
        viewMenu.addItem(decreaseItem)
        viewMenu.addItem(resetItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApplication.shared.mainMenu = mainMenu
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
