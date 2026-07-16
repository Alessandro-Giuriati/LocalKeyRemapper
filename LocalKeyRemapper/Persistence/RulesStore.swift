//
//  RulesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

/// Defines a common interface for components capable
/// of loading and saving keyboard remapping rules.
///
/// The store contains configured rules only.
/// It never receives or stores keyboard input.
@MainActor
protocol RulesStore: AnyObject {

    /// Loads all currently configured remapping rules.
    func loadRules() throws -> [RemapRule]

    /// Replaces all currently configured remapping rules.
    func saveRules(_ rules: [RemapRule]) throws
}
