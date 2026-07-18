//
//  AppDelegate.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 5/18/26.
//

import AppKit

@MainActor
final class AppDelegate:
    NSObject,
    NSApplicationDelegate
{
    private var appCoordinator:
        AppCoordinator?

    func applicationDidFinishLaunching(
        _ notification:
            Notification
    ) {
        // LocalKeyRemapper is now a regular windowed macOS application.
        //
        // A regular activation policy keeps the application visible
        // in the Dock and provides the standard application menu bar.
        NSApplication.shared.setActivationPolicy(
            .regular
        )

        let appCoordinator =
            AppCoordinator()

        self.appCoordinator =
            appCoordinator

        appCoordinator.start()
    }

    func applicationDidBecomeActive(
        _ notification:
            Notification
    ) {
        appCoordinator?
            .applicationDidBecomeActive()
    }

    /// Reopens the main window when the user clicks the Dock icon
    /// while the application has no visible windows.
    func applicationShouldHandleReopen(
        _ sender:
            NSApplication,
        hasVisibleWindows flag:
            Bool
    ) -> Bool {
        if !flag {
            appCoordinator?
                .showMainWindow()
        }

        return true
    }

    func applicationWillTerminate(
        _ notification:
            Notification
    ) {
        appCoordinator?
            .stop()
    }
}
