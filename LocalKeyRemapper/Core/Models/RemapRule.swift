//
//  RemapRule.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import CoreGraphics

/// Represents a single keyboard remapping rule.
///
/// Example:
/// sourceKeyCode: V
/// destinationKeyCode: W
nonisolated struct RemapRule: Codable, Equatable {

    let sourceKeyCode: CGKeyCode
    let destinationKeyCode: CGKeyCode
}
