//
//  AppConfigurationNotifications.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/28/26.
//

import Foundation

/// Names the local, process-only notifications used to synchronize
/// configuration-dependent user interfaces.
///
/// These notifications never leave the application process. They contain no
/// keyboard input, key combinations, rules, or other configuration payloads.
/// Receiving components independently read the latest local state.
enum AppConfigurationNotification {

    /// Posted after remapping rules have been successfully validated,
    /// persisted, and applied.
    static let remappingRulesDidChange =
        Notification.Name(
            "LocalKeyRemapper.remappingRulesDidChange"
        )

    /// Posted after the global shortcut configuration has been successfully
    /// validated, registered, and persisted.
    static let globalShortcutConfigurationDidChange =
        Notification.Name(
            "LocalKeyRemapper.globalShortcutConfigurationDidChange"
        )
}
