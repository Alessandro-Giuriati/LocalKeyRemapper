//
//  StatusBarController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

final class StatusBarController: NSObject {

    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        super.init()

        configureStatusItem()
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
            accessibilityDescription: "LocalKeyRemapper"
        ) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "KR"
        }

        button.toolTip = "LocalKeyRemapper"
    }

    private func configureMenu() {
        let menu = NSMenu()

        let stateMenuItem = NSMenuItem(
            title: "Remapping: Off",
            action: nil,
            keyEquivalent: ""
        )
        stateMenuItem.isEnabled = false

        let quitMenuItem = NSMenuItem(
            title: "Quit LocalKeyRemapper",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self

        menu.addItem(stateMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    @objc
    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
