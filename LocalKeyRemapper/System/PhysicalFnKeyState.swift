//
//  PhysicalFnKeyState.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/21/26.
//

import Carbon.HIToolbox
import CoreGraphics

/// Reads the current physical state of the keyboard's Fn/Globe key.
///
/// This performs one synchronous state lookup only when the application is
/// already handling a key event. It does not install a monitor, poll, log,
/// persist, or transmit keyboard input.
nonisolated enum PhysicalFnKeyState {

    static func isPressed() -> Bool {
        CGEventSource.keyState(
            .hidSystemState,
            key:
                CGKeyCode(
                    kVK_Function
                )
        )
    }
}
