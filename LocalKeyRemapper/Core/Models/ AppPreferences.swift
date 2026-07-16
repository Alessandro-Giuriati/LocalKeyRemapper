//
//   AppPreferences.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Foundation

/// Contains application preferences that are safe to persist locally.
///
/// These preferences describe application behavior only.
/// They never contain keyboard input or key-press history.
nonisolated struct AppPreferences: Codable, Equatable {

    /// Indicates whether remapping should be enabled automatically
    /// after the application finishes launching.
    var enableRemappingAtLaunch: Bool

    /// Safe preferences used when nothing has been stored yet.
    static let standard = AppPreferences(
        enableRemappingAtLaunch: false
    )
}
