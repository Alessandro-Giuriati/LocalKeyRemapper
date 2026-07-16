//
//  AppDelegate.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 5/18/26.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var appCoordinator: AppCoordinator?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let appCoordinator = AppCoordinator()

        self.appCoordinator = appCoordinator

        appCoordinator.start()
    }

    func applicationDidBecomeActive(
        _ notification: Notification
    ) {
        appCoordinator?.applicationDidBecomeActive()
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        appCoordinator?.stop()
    }
}
