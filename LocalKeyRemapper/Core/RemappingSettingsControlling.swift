//
//  RemappingSettingsControlling.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

/// Defines the backend operations required by the Settings window.
///
/// The Settings UI can load and replace configured rules and can
/// temporarily suspend remapping while capturing a physical key.
@MainActor
protocol RemappingSettingsControlling: AnyObject {

    /// Returns the rules currently stored by the application.
    func loadConfiguredRules() throws -> [RemapRule]

    /// Replaces all configured rules.
    func replaceConfiguredRules(
        _ rules: [RemapRule]
    ) throws

    /// Temporarily suspends remapping during key capture.
    func beginKeyCapture()

    /// Ends key capture and restores remapping when appropriate.
    func endKeyCapture()
}
