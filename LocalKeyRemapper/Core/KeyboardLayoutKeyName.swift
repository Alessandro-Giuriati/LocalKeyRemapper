//
//  KeyboardLayoutKeyName.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Produces a readable key name using the active macOS keyboard layout.
///
/// This type translates only stored virtual key codes for display.
/// It does not monitor, record, or persist keyboard input.
nonisolated enum KeyboardLayoutKeyName {

    /// Returns a readable name for a physical macOS virtual key code.
    static func name(
        for keyCode:
            CGKeyCode
    ) -> String {
        displayName(
            for:
                keyCode,
            translatedCharacters:
                translatedCharacters(
                    for:
                        keyCode
                )
        )
    }

    /// Builds a display name from an optionally translated layout value.
    ///
    /// This overload keeps the formatting logic deterministic and testable
    /// without depending on the keyboard layout installed on the test Mac.
    static func displayName(
        for keyCode:
            CGKeyCode,
        translatedCharacters:
            String?
    ) -> String {
        if let specialName =
            specialKeyNames[
                keyCode
            ]
        {
            return specialName
        }

        if let translatedName =
            normalizedPrintableName(
                translatedCharacters
            )
        {
            return translatedName
        }

        if let catalogKey =
            KeyboardKeyCatalog.key(
                for:
                    keyCode
            )
        {
            return catalogKey
                .displayName
        }

        return "Key \(keyCode)"
    }

    private static let specialKeyNames:
        [CGKeyCode: String] =
    [
        CGKeyCode(kVK_Space):
            "Space",
        CGKeyCode(kVK_Return):
            "Return",
        CGKeyCode(kVK_ANSI_KeypadEnter):
            "Keypad Enter",
        CGKeyCode(kVK_Tab):
            "Tab",
        CGKeyCode(kVK_Delete):
            "Delete",
        CGKeyCode(kVK_ForwardDelete):
            "Forward Delete",
        CGKeyCode(kVK_Escape):
            "Escape",

        CGKeyCode(kVK_LeftArrow):
            "Left Arrow",
        CGKeyCode(kVK_RightArrow):
            "Right Arrow",
        CGKeyCode(kVK_UpArrow):
            "Up Arrow",
        CGKeyCode(kVK_DownArrow):
            "Down Arrow",

        CGKeyCode(kVK_Home):
            "Home",
        CGKeyCode(kVK_End):
            "End",
        CGKeyCode(kVK_PageUp):
            "Page Up",
        CGKeyCode(kVK_PageDown):
            "Page Down",

        CGKeyCode(kVK_F1):
            "F1",
        CGKeyCode(kVK_F2):
            "F2",
        CGKeyCode(kVK_F3):
            "F3",
        CGKeyCode(kVK_F4):
            "F4",
        CGKeyCode(kVK_F5):
            "F5",
        CGKeyCode(kVK_F6):
            "F6",
        CGKeyCode(kVK_F7):
            "F7",
        CGKeyCode(kVK_F8):
            "F8",
        CGKeyCode(kVK_F9):
            "F9",
        CGKeyCode(kVK_F10):
            "F10",
        CGKeyCode(kVK_F11):
            "F11",
        CGKeyCode(kVK_F12):
            "F12",
        CGKeyCode(kVK_F13):
            "F13",
        CGKeyCode(kVK_F14):
            "F14",
        CGKeyCode(kVK_F15):
            "F15",
        CGKeyCode(kVK_F16):
            "F16",
        CGKeyCode(kVK_F17):
            "F17",
        CGKeyCode(kVK_F18):
            "F18",
        CGKeyCode(kVK_F19):
            "F19",
        CGKeyCode(kVK_F20):
            "F20"
    ]

    private static func translatedCharacters(
        for keyCode:
            CGKeyCode
    ) -> String? {
        guard
            let unmanagedInputSource =
                TISCopyCurrentKeyboardLayoutInputSource()
        else {
            return nil
        }

        let inputSource =
            unmanagedInputSource
                .takeRetainedValue()

        guard
            let rawLayoutData =
                TISGetInputSourceProperty(
                    inputSource,
                    kTISPropertyUnicodeKeyLayoutData
                )
        else {
            return nil
        }

        let layoutData =
            unsafeBitCast(
                rawLayoutData,
                to:
                    CFData.self
            )

        guard
            let layoutBytes =
                CFDataGetBytePtr(
                    layoutData
                )
        else {
            return nil
        }

        let keyboardLayout =
            UnsafeRawPointer(
                layoutBytes
            )
            .assumingMemoryBound(
                to:
                    UCKeyboardLayout.self
            )

        var deadKeyState:
            UInt32 = 0

        var actualLength = 0

        var unicodeCharacters =
            [UniChar](
                repeating:
                    0,
                count:
                    8
            )

        let status =
            unicodeCharacters
                .withUnsafeMutableBufferPointer {
                    buffer in

                    UCKeyTranslate(
                        keyboardLayout,
                        UInt16(
                            keyCode
                        ),
                        UInt16(
                            kUCKeyActionDisplay
                        ),
                        0,
                        UInt32(
                            LMGetKbdType()
                        ),
                        OptionBits(
                            kUCKeyTranslateNoDeadKeysBit
                        ),
                        &deadKeyState,
                        buffer.count,
                        &actualLength,
                        buffer.baseAddress
                    )
                }

        guard
            status == noErr,
            actualLength > 0
        else {
            return nil
        }

        return unicodeCharacters
            .withUnsafeBufferPointer {
                buffer in

                guard
                    let baseAddress =
                        buffer.baseAddress
                else {
                    return nil
                }

                return String(
                    utf16CodeUnits:
                        baseAddress,
                    count:
                        actualLength
                )
            }
    }

    private static func normalizedPrintableName(
        _ characters:
            String?
    ) -> String? {
        guard
            let characters
        else {
            return nil
        }

        let trimmedCharacters =
            characters
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !trimmedCharacters.isEmpty,
            trimmedCharacters
                .rangeOfCharacter(
                    from:
                        .controlCharacters
                ) == nil
        else {
            return nil
        }

        let scalars =
            Array(
                trimmedCharacters
                    .unicodeScalars
            )

        if
            scalars.count == 1,
            let scalar =
                scalars.first,
            scalar.value >= 97,
            scalar.value <= 122
        {
            return trimmedCharacters
                .uppercased()
        }

        return trimmedCharacters
    }
}
