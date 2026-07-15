//
//  StaticRulesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

/// Provides the static remapping rules used by the MVP.
///
/// This implementation does not read or write files
/// and does not store keyboard input.
nonisolated struct StaticRulesStore: RulesStore {

    func loadRules() throws -> [RemapRule] {
        [
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            )
        ]
    }
}
