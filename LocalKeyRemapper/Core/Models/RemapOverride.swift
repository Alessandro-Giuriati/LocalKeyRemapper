//
//  RemapOverride.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

/// Represents an exact exception to a modifier-preserving rule.
///
/// Exact overrides always take precedence over the general rule.
nonisolated struct RemapOverride:
    Codable,
    Equatable
{
    let source: KeyCombination
    let action: RemapAction

    init(
        source: KeyCombination,
        action: RemapAction
    ) {
        self.source = source
        self.action = action
    }
}
