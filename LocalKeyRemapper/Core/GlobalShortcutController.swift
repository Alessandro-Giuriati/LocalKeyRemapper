//
//  GlobalShortcutController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

/// Coordinates global shortcut registration, local persistence,
/// and protection from normal remapping rules.
///
/// This controller stores only the configured shortcut.
/// It never receives, records, or logs normal keyboard input.
@MainActor
final class GlobalShortcutController {

    private let shortcutManager:
        GlobalShortcutRegistering

    private let appPreferencesController:
        AppPreferencesControlling

    private let remappingEngine:
        RemappingEngine

    private let action:
        () -> Void

    /// The shortcut currently stored in the application preferences.
    var configuredShortcut: KeyCombination? {
        appPreferencesController
            .preferences
            .toggleShortcut
    }

    init(
        shortcutManager:
            GlobalShortcutRegistering,
        appPreferencesController:
            AppPreferencesControlling,
        remappingEngine:
            RemappingEngine = RemappingEngine(),
        action:
            @escaping () -> Void
    ) {
        self.shortcutManager =
            shortcutManager

        self.appPreferencesController =
            appPreferencesController

        self.remappingEngine =
            remappingEngine

        self.action =
            action
    }

    /// Registers and protects the shortcut currently stored
    /// in local preferences.
    ///
    /// If no shortcut is configured, any existing registration
    /// and reservation are removed.
    func start() throws {
        let shortcut =
            configuredShortcut

        do {
            try applyRegistration(
                for: shortcut
            )

            applyReservation(
                for: shortcut
            )
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for: nil
            )

            throw error
        }
    }

    /// Replaces or disables the configured global shortcut.
    ///
    /// Passing nil disables the global shortcut.
    ///
    /// If registration or persistence fails, the previous
    /// registration and reservation are restored whenever possible.
    func setShortcut(
        _ newShortcut:
            KeyCombination?
    ) throws {
        let previousShortcut =
            configuredShortcut

        guard
            previousShortcut
                != newShortcut
        else {
            return
        }

        do {
            try applyRegistration(
                for: newShortcut
            )

            applyReservation(
                for: newShortcut
            )
        } catch {
            restoreRegistrationAndReservation(
                for: previousShortcut
            )

            throw error
        }

        do {
            try appPreferencesController
                .setToggleShortcut(
                    newShortcut
                )
        } catch {
            restoreRegistrationAndReservation(
                for: previousShortcut
            )

            throw error
        }
    }

    /// Removes the shortcut registration, Carbon event handler,
    /// and protected remapping combination.
    func stop() {
        shortcutManager.stop()

        applyReservation(
            for: nil
        )
    }

    private func applyRegistration(
        for shortcut:
            KeyCombination?
    ) throws {
        guard let shortcut else {
            shortcutManager.unregister()
            return
        }

        try shortcutManager.register(
            shortcut,
            action: action
        )
    }

    private func applyReservation(
        for shortcut:
            KeyCombination?
    ) {
        guard let shortcut else {
            remappingEngine
                .replaceReservedCombinations(
                    []
                )

            return
        }

        remappingEngine
            .replaceReservedCombinations(
                [shortcut]
            )
    }

    private func restoreRegistrationAndReservation(
        for shortcut:
            KeyCombination?
    ) {
        do {
            try applyRegistration(
                for: shortcut
            )

            applyReservation(
                for: shortcut
            )
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for: nil
            )
        }
    }
}
