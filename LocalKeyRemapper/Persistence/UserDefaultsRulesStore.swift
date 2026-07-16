//
//  UserDefaultsRulesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Foundation

/// Persists configured remapping rules in the application's
/// local UserDefaults domain.
///
/// This store saves configured rules only.
/// It never receives, records, or stores keyboard input.
@MainActor
final class UserDefaultsRulesStore: RulesStore {

    private enum StorageKey {
        static let remappingRules =
            "remappingRules.v1"
    }

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let defaultRules: [RemapRule]

    init(
        userDefaults: UserDefaults = .standard,
        defaultRules: [RemapRule] = [
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            )
        ]
    ) {
        self.userDefaults = userDefaults
        self.defaultRules = defaultRules

        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func loadRules() throws -> [RemapRule] {
        guard
            let data = userDefaults.data(
                forKey: StorageKey.remappingRules
            )
        else {
            return defaultRules
        }

        return try decoder.decode(
            [RemapRule].self,
            from: data
        )
    }

    func saveRules(
        _ rules: [RemapRule]
    ) throws {
        let data = try encoder.encode(rules)

        userDefaults.set(
            data,
            forKey: StorageKey.remappingRules
        )
    }
}
