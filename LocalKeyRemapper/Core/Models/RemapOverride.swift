//
//  RemapOverride.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

/// Represents an exact exception owned by a remapping rule.
///
/// An exception is active only when its parent rule preserves modifiers
/// and the exception itself is enabled.
nonisolated struct RemapOverride:
    Codable,
    Equatable
{
    let source: KeyCombination
    let action: RemapAction
    let isEnabled: Bool

    init(
        source: KeyCombination,
        action: RemapAction,
        isEnabled: Bool = true
    ) {
        self.source = source
        self.action = action
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case action
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        source = try container.decode(
            KeyCombination.self,
            forKey: .source
        )

        action = try container.decode(
            RemapAction.self,
            forKey: .action
        )

        // Existing saved exceptions predate the enabled-state field.
        // They remain enabled after migration to preserve old behavior.
        isEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isEnabled
        ) ?? true
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
            action,
            forKey: .action
        )

        try container.encode(
            isEnabled,
            forKey: .isEnabled
        )
    }
}
