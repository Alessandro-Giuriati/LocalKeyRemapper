//
//  RemappingSettingsControlling.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Foundation

/// Defines the backend operations required by the Rules window.
///
/// The interface supports both the temporary active-profile compatibility
/// operations and explicit profile access through stable UUIDs.
@MainActor
protocol RemappingSettingsControlling: AnyObject {

    /// Returns the rules belonging to the currently active profile.
    ///
    /// Retained temporarily while every caller is migrated to explicit
    /// profile identity.
    func loadConfiguredRules()
        throws -> [RemapRule]
    /// Returns the rules belonging to one specific profile.
    func loadConfiguredRules(
        for profileID: UUID
    ) throws -> [RemapRule]

    /// Replaces the rules belonging to the currently active profile.
    ///
    /// Retained temporarily while every caller is migrated to explicit
    /// profile identity.
    func replaceConfiguredRules(
        _ rules: [RemapRule]
    ) throws

    /// Replaces the rules belonging to one specific profile.
    func replaceConfiguredRules(
        _ rules: [RemapRule],
        for profileID: UUID
    ) throws

    /// Temporarily suspends remapping during key capture.
    func beginKeyCapture()

    /// Ends key capture and restores remapping when appropriate.
    func endKeyCapture()
}
