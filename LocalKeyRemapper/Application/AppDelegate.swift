//
//  AppDelegate.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 5/18/26.
//

import AppKit

/// The application-lifecycle surface used by `AppDelegate`.
///
/// Keeping this boundary small makes the macOS termination hook directly
/// testable without constructing the remapping backend or installing an event
/// tap. The production implementation is `AppCoordinator`.
@MainActor
protocol ApplicationLifecycleCoordinating:
    AnyObject
{
    func start()
    func applicationDidBecomeActive()
    func applicationShouldTerminate()
        -> NSApplication.TerminateReply
    func showMainWindow()
    func stop()
}

@MainActor
final class AppDelegate:
    NSObject,
    NSApplicationDelegate
{
    private let appCoordinatorFactory:
        @MainActor () -> any ApplicationLifecycleCoordinating

    private var appCoordinator:
        (any ApplicationLifecycleCoordinating)?

    override init() {
        appCoordinatorFactory = {
            AppCoordinator()
        }

        super.init()
    }

    /// Test-only injection point for lifecycle behavior.
    ///
    /// Production startup always uses `init()` and creates `AppCoordinator`.
    init(
        appCoordinator:
            any ApplicationLifecycleCoordinating
    ) {
        self.appCoordinator =
            appCoordinator

        appCoordinatorFactory = {
            appCoordinator
        }

        super.init()
    }

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
            self.appCoordinator
                ?? appCoordinatorFactory()

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

    /// Central termination gate used by every normal macOS Quit path.
    ///
    /// `Command-Q`, the application menu, the optional menu-bar popover, the
    /// Dock, and system termination requests all reach this delegate method
    /// when they call `NSApplication.terminate(_:)`.
    func applicationShouldTerminate(
        _ sender:
            NSApplication
    ) -> NSApplication.TerminateReply {
        appCoordinator?
            .applicationShouldTerminate()
            ?? .terminateNow
    }

    func applicationWillTerminate(
        _ notification:
            Notification
    ) {
        appCoordinator?
            .stop()
    }
}
