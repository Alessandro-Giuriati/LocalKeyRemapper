//
//  FnModifierStateTracker.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

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
