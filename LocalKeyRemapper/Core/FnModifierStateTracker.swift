//
//  FnModifierStateTracker.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import Carbon.HIToolbox
import CoreGraphics

/// Tracks the physical Fn/Globe modifier from ordered modifier-state events.
///
/// The tracker stores only one transient Boolean value. It does not record
/// keys, create logs, persist state, or perform polling.
nonisolated struct FnModifierStateTracker:
    Equatable
{
    private(set) var isPressed = false

    /// Aligns the tracker with the current hardware state when observation
    /// starts or resumes after being temporarily disabled.
    mutating func synchronize(
        isPressed:
            Bool
    ) {
        self.isPressed =
            isPressed
    }

    /// Applies one ordered Fn flags-changed event.
    mutating func handleFlagsChanged(
        isPressed:
            Bool
    ) {
        self.isPressed =
            isPressed
    }

    /// Clears transient state when observation stops or is interrupted.
    mutating func reset() {
        isPressed = false
    }
}

/// Preserves Shift, Control, Option, and Command across a capture session.
///
/// macOS can deliver F1 through F12 key-down events with only the Function
/// metadata even while ordinary modifiers remain physically held. Tracking
/// each modifier when its own `flagsChanged` event arrives prevents the final
/// function-key event from discarding the already observed modifier state.
///
/// The value exists only in memory for the duration of one explicit capture.
/// It does not install monitors, poll, log, persist, or transmit keyboard input.
nonisolated struct NonFnModifierStateTracker:
    Equatable
{
    private(set) var modifiers:
        KeyModifiers = []

    /// Aligns the tracker with the current AppKit modifier snapshot when a
    /// capture begins.
    mutating func synchronize(
        currentModifiers:
            KeyModifiers
    ) {
        modifiers =
            currentModifiers

        modifiers.remove(
            .fn
        )
    }

    /// Updates only the modifier represented by the current flags-changed
    /// event. Other stored modifiers remain untouched.
    mutating func handleFlagsChanged(
        keyCode:
            CGKeyCode,
        currentModifiers:
            KeyModifiers
    ) {
        switch Int(keyCode) {
        case kVK_Shift,
             kVK_RightShift:
            update(
                .shift,
                isPressed:
                    currentModifiers
                        .contains(
                            .shift
                        )
            )

        case kVK_Control,
             kVK_RightControl:
            update(
                .control,
                isPressed:
                    currentModifiers
                        .contains(
                            .control
                        )
            )

        case kVK_Option,
             kVK_RightOption:
            update(
                .option,
                isPressed:
                    currentModifiers
                        .contains(
                            .option
                        )
            )

        case kVK_Command,
             kVK_RightCommand:
            update(
                .command,
                isPressed:
                    currentModifiers
                        .contains(
                            .command
                        )
            )

        default:
            break
        }
    }

    mutating func reset() {
        modifiers = []
    }

    private mutating func update(
        _ modifier:
            KeyModifiers,
        isPressed:
            Bool
    ) {
        if isPressed {
            modifiers.insert(
                modifier
            )
        } else {
            modifiers.remove(
                modifier
            )
        }
    }
}
