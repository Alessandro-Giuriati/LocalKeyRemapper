//
//  RemappingProfilesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

/// Defines a common interface for components capable of loading and saving
/// the complete remapping-profiles configuration.
///
/// The store contains explicit configuration only.
/// It never receives, records, or stores keyboard input.
@MainActor
protocol RemappingProfilesStore: AnyObject {

    /// Loads the complete profiles configuration.
    ///
    /// A concrete store may create an initial configuration or migrate
    /// compatible legacy rules when no profiles payload exists yet.
    func loadConfiguration() throws
        -> RemappingProfilesConfiguration

    /// Replaces the complete persisted profiles configuration.
    func saveConfiguration(
        _ configuration: RemappingProfilesConfiguration
    ) throws
}
