//
//  RemapRule.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//


import CoreGraphics

/// Represents one configurable keyboard remapping rule.
///
/// A rule can match one exact combination or preserve the modifiers
/// pressed with a source key. Modifier-preserving rules can also contain
/// exact, fully customizable overrides.
nonisolated struct RemapRule:
    Codable,
    Equatable
{
    let source: KeyCombination
    let destination: KeyCombination
    let matchingMode: RemapMatchingMode
    let overrides: [RemapOverride]

    init(
        source: KeyCombination,
        destination: KeyCombination,
        matchingMode: RemapMatchingMode = .exact,
        overrides: [RemapOverride] = []
    ) {
        self.source = source
        self.destination = destination
        self.matchingMode = matchingMode
        self.overrides = overrides
    }

    /// Compatibility initializer used by the current Settings interface.
    ///
    /// Existing rules are interpreted safely as exact combinations
    /// without modifiers, so V -> W does not affect Command + V.
    init(
        sourceKeyCode: CGKeyCode,
        destinationKeyCode: CGKeyCode
    ) {
        self.init(
            source: KeyCombination(
                keyCode: sourceKeyCode
            ),
            destination: KeyCombination(
                keyCode: destinationKeyCode
            ),
            matchingMode: .exact
        )
    }

    /// Compatibility property used by the current Settings interface.
    var sourceKeyCode: CGKeyCode {
        source.keyCode
    }

    /// Compatibility property used by the current Settings interface.
    var destinationKeyCode: CGKeyCode {
        destination.keyCode
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case source
        case destination
        case matchingMode
        case overrides

        /// Keys used by the previous rule format.
        case sourceKeyCode
        case destinationKeyCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        if let source = try container.decodeIfPresent(
            KeyCombination.self,
            forKey: .source
        ) {
            self.source = source

            destination = try container.decode(
                KeyCombination.self,
                forKey: .destination
            )

            matchingMode = try container.decodeIfPresent(
                RemapMatchingMode.self,
                forKey: .matchingMode
            ) ?? .exact

            overrides = try container.decodeIfPresent(
                [RemapOverride].self,
                forKey: .overrides
            ) ?? []

            return
        }

        let legacySourceKeyCode = try container.decode(
            CGKeyCode.self,
            forKey: .sourceKeyCode
        )

        let legacyDestinationKeyCode = try container.decode(
            CGKeyCode.self,
            forKey: .destinationKeyCode
        )

        source = KeyCombination(
            keyCode: legacySourceKeyCode
        )

        destination = KeyCombination(
            keyCode: legacyDestinationKeyCode
        )

        matchingMode = .exact
        overrides = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            source,
            forKey: .source
        )

        try container.encode(
            destination,
            forKey: .destination
        )

        try container.encode(
            matchingMode,
            forKey: .matchingMode
        )

        try container.encode(
            overrides,
            forKey: .overrides
        )
    }
}
