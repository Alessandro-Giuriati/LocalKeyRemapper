//
//  RemapMatchingMode.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

/// Defines how a remapping rule matches keyboard input.
nonisolated enum RemapMatchingMode:
    String,
    Codable,
    Equatable
{
    /// Matches only the complete source combination.
    ///
    /// Example:
    /// V -> W does not affect Command + V.
    case exact

    /// Matches every supported modifier combination for the source key
    /// and preserves the pressed modifiers on the destination key.
    ///
    /// Example:
    /// V -> W also produces Command + W for Command + V.
    case preserveModifiers
}
