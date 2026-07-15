//
//  main.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/14/26.
//

import AppKit

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let appDelegate = AppDelegate()

    application.delegate = appDelegate
    application.setActivationPolicy(.accessory)
    application.run()
}
