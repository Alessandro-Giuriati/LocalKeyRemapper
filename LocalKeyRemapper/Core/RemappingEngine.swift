//
//  RemappingEngine.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import CoreGraphics

/// Contains the pure keyboard remapping logic.
///
/// This class does not intercept keyboard events, access storage,
/// update the user interface, or record keyboard input.
nonisolated final class RemappingEngine {

    /// Maps an original key code to its replacement key code.
    private var mappings: [CGKeyCode: CGKeyCode] = [:]

    init(rules: [RemapRule] = []) {
        replaceRules(rules)
    }

    /// Replaces all currently loaded remapping rules.
    func replaceRules(_ rules: [RemapRule]) {
        mappings = rules.reduce(into: [:]) { result, rule in
            result[rule.sourceKeyCode] = rule.destinationKeyCode
        }
    }

    /// Returns the remapping decision for the provided key code.
    func decision(for keyCode: CGKeyCode) -> RemapDecision {
        guard let destinationKeyCode = mappings[keyCode] else {
            return .passThrough
        }

        return .replaceKeyCode(destinationKeyCode)
    }
}
