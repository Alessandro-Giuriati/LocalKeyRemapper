//
//  RemapAction.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

//
//  RemapAction.swift
//  LocalKeyRemapper
//

/// Represents the result of an exact remapping rule or override.
nonisolated enum RemapAction:
    Codable,
    Equatable
{
    /// Replaces the source with the provided complete combination.
    case replaceWith(KeyCombination)

    /// Leaves the original keyboard event unchanged.
    ///
    /// This is used for explicit exceptions such as:
    /// Command + V -> Keep Original
    case passThrough
}
