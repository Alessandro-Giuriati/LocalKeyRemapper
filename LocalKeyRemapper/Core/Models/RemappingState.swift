//
//  RemappingState.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

/// Represents a failure that prevents keyboard remapping
/// from being enabled.
nonisolated enum RemappingFailure: Error, Equatable {

    /// The configured remapping rules could not be loaded.
    case rulesLoadingFailed

    /// The loaded remapping rules are not valid.
    case invalidRules

    /// The keyboard event tap could not be created or installed.
    case eventTapStartFailed
}

/// Represents the current state of the keyboard remapping system.
nonisolated enum RemappingState: Equatable {

    /// No event tap is installed.
    case disabled

    /// The controller is preparing the remapping system.
    case enabling

    /// The event tap is installed and remapping is active.
    case enabled

    /// Accessibility permission must be granted by the user.
    case permissionRequired

    /// The remapping system could not be enabled.
    case failed(RemappingFailure)
}
