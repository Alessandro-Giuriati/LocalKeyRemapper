//
//  KeyboardKeyCatalog.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Carbon.HIToolbox
import CoreGraphics

/// Contains the keyboard keys currently supported
/// by the remapping rules editor.
///
/// The catalog is initialized once and reused by the interface.
nonisolated enum KeyboardKeyCatalog {

    static let all: [KeyboardKey] = [
        makeKey(kVK_ANSI_A, "A"),
        makeKey(kVK_ANSI_B, "B"),
        makeKey(kVK_ANSI_C, "C"),
        makeKey(kVK_ANSI_D, "D"),
        makeKey(kVK_ANSI_E, "E"),
        makeKey(kVK_ANSI_F, "F"),
        makeKey(kVK_ANSI_G, "G"),
        makeKey(kVK_ANSI_H, "H"),
        makeKey(kVK_ANSI_I, "I"),
        makeKey(kVK_ANSI_J, "J"),
        makeKey(kVK_ANSI_K, "K"),
        makeKey(kVK_ANSI_L, "L"),
        makeKey(kVK_ANSI_M, "M"),
        makeKey(kVK_ANSI_N, "N"),
        makeKey(kVK_ANSI_O, "O"),
        makeKey(kVK_ANSI_P, "P"),
        makeKey(kVK_ANSI_Q, "Q"),
        makeKey(kVK_ANSI_R, "R"),
        makeKey(kVK_ANSI_S, "S"),
        makeKey(kVK_ANSI_T, "T"),
        makeKey(kVK_ANSI_U, "U"),
        makeKey(kVK_ANSI_V, "V"),
        makeKey(kVK_ANSI_W, "W"),
        makeKey(kVK_ANSI_X, "X"),
        makeKey(kVK_ANSI_Y, "Y"),
        makeKey(kVK_ANSI_Z, "Z"),

        makeKey(kVK_ANSI_0, "0"),
        makeKey(kVK_ANSI_1, "1"),
        makeKey(kVK_ANSI_2, "2"),
        makeKey(kVK_ANSI_3, "3"),
        makeKey(kVK_ANSI_4, "4"),
        makeKey(kVK_ANSI_5, "5"),
        makeKey(kVK_ANSI_6, "6"),
        makeKey(kVK_ANSI_7, "7"),
        makeKey(kVK_ANSI_8, "8"),
        makeKey(kVK_ANSI_9, "9"),

        makeKey(kVK_Space, "Space"),
        makeKey(kVK_Return, "Return"),
        makeKey(kVK_Tab, "Tab"),
        makeKey(kVK_Delete, "Delete"),
        makeKey(kVK_ForwardDelete, "Forward Delete"),
        makeKey(kVK_Escape, "Escape"),

        makeKey(kVK_LeftArrow, "Left Arrow"),
        makeKey(kVK_RightArrow, "Right Arrow"),
        makeKey(kVK_UpArrow, "Up Arrow"),
        makeKey(kVK_DownArrow, "Down Arrow"),

        makeKey(kVK_Home, "Home"),
        makeKey(kVK_End, "End"),
        makeKey(kVK_PageUp, "Page Up"),
        makeKey(kVK_PageDown, "Page Down"),

        makeKey(kVK_F1, "F1"),
        makeKey(kVK_F2, "F2"),
        makeKey(kVK_F3, "F3"),
        makeKey(kVK_F4, "F4"),
        makeKey(kVK_F5, "F5"),
        makeKey(kVK_F6, "F6"),
        makeKey(kVK_F7, "F7"),
        makeKey(kVK_F8, "F8"),
        makeKey(kVK_F9, "F9"),
        makeKey(kVK_F10, "F10"),
        makeKey(kVK_F11, "F11"),
        makeKey(kVK_F12, "F12")
    ]

    private static let keysByCode: [CGKeyCode: KeyboardKey] =
        Dictionary(
            uniqueKeysWithValues: all.map {
                ($0.keyCode, $0)
            }
        )

    /// Returns the displayable keyboard key associated
    /// with a macOS virtual key code.
    static func key(
        for keyCode: CGKeyCode
    ) -> KeyboardKey? {
        keysByCode[keyCode]
    }

    private static func makeKey(
        _ keyCode: Int,
        _ displayName: String
    ) -> KeyboardKey {
        KeyboardKey(
            keyCode: CGKeyCode(keyCode),
            displayName: displayName
        )
    }
}
