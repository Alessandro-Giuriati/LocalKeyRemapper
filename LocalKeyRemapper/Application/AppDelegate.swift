//
//  AppDelegate.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 5/18/26.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var appCoordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appCoordinator = AppCoordinator()
        appCoordinator?.start()
    }
}
