//
//  InterfaceLayoutMetrics.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/23/26.
//

import CoreGraphics

/// Shared layout measurements for application windows.
///
/// Spacing follows the user-selected text scale while remaining inside
/// practical limits, so small text does not make controls feel cramped and
/// large text does not create disproportionate empty areas.
nonisolated enum InterfaceLayoutMetrics {

    static func scaled(
        _ baseValue: CGFloat,
        for textScale: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        min(
            max(
                baseValue * textScale,
                minimum
            ),
            maximum
        )
    }

    static func topContentMargin(
        for textScale: CGFloat
    ) -> CGFloat {
        scaled(
            15,
            for: textScale,
            minimum: 12,
            maximum: 24
        )
    }
}
