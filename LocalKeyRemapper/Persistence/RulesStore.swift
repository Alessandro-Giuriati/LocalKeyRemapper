//
//  RulesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

/// Defines a common interface for components
/// capable of providing keyboard remapping rules.
nonisolated protocol RulesStore {

    func loadRules() throws -> [RemapRule]
}
