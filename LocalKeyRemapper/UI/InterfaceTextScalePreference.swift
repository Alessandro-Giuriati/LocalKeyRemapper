//
//  InterfaceTextScalePreference.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import AppKit

/// Stores one shared text scale for the application's AppKit windows.
///
/// Only this visual preference is persisted. No keyboard input, captured
/// combination, remapping activity, or usage information is stored here.
enum InterfaceTextScalePreference {
    static let defaultScale: CGFloat = 1.0
    static let minimumScale: CGFloat = 0.8
    static let maximumScale: CGFloat = 1.4
    static let step: CGFloat = 0.1

    private static let storageKey =
        "settingsTextScale.v1"

    static var currentScale: CGFloat {
        let storedScale =
            UserDefaults.standard.double(
                forKey: storageKey
            )

        guard storedScale != 0 else {
            return defaultScale
        }

        return clamped(
            CGFloat(storedScale)
        )
    }

    @discardableResult
    static func increase() -> CGFloat {
        set(
            currentScale + step
        )
    }

    @discardableResult
    static func decrease() -> CGFloat {
        set(
            currentScale - step
        )
    }

    @discardableResult
    static func reset() -> CGFloat {
        set(
            defaultScale
        )
    }

    @discardableResult
    static func set(
        _ proposedScale: CGFloat
    ) -> CGFloat {
        let newScale =
            clamped(
                proposedScale
            )

        UserDefaults.standard.set(
            Double(newScale),
            forKey: storageKey
        )

        return newScale
    }

    static func clamped(
        _ scale: CGFloat
    ) -> CGFloat {
        min(
            max(
                scale,
                minimumScale
            ),
            maximumScale
        )
    }
}
