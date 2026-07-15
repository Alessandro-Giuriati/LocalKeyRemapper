//
//  RemapDecision.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import CoreGraphics

/// Represents the decision made by the remapping engine
/// for a specific keyboard event.
nonisolated enum RemapDecision: Equatable {

    /// The key does not match any rule and must remain unchanged.
    case passThrough

    /// The original key code must be replaced.
    case replaceKeyCode(CGKeyCode)
}
