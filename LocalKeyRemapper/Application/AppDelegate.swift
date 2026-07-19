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

    /// Unit tests are injected into the application process.
    ///
    /// The application interface and system integrations are not started
    /// while that process is acting only as an XCTest host.
    private var isRunningUnitTests:
        Bool
    {
        ProcessInfo
            .processInfo
            .environment[
                "XCTestConfigurationFilePath"
            ] != nil
    }

    func applicationDidFinishLaunching(
        _ notification:
            Notification
    ) {
        guard !isRunningUnitTests else {
            NSApplication.shared
                .setActivationPolicy(
                    .prohibited
                )

            return
        }

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
