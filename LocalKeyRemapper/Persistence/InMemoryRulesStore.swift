//
//  InMemoryRulesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

/// Stores the currently configured remapping rules in memory.
///
/// This implementation performs no disk access and stores only
/// configured rules. It never records keyboard input.
@MainActor
final class InMemoryRulesStore: RulesStore {

    private var rules: [RemapRule]

    init(
        rules: [RemapRule] = [
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            )
        ]
    ) {
        self.rules = rules
    }

    func loadRules() throws -> [RemapRule] {
        rules
    }

    func saveRules(_ rules: [RemapRule]) throws {
        self.rules = rules
    }
}
