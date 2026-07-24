//
//  RemappingRuleEditorItem.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/20/26.
//

import CoreGraphics
import Foundation

/// Represents one row in the remapping rule editor.
///
/// Unlike `RemapRule`, an editor item may be incomplete while the user is
/// still choosing its source or destination combination. The identifier and
/// remembered Exact Only combinations are valid only for the current
/// application process and are never persisted.
nonisolated struct RemappingRuleEditorItem:
    Equatable
{
    enum MatchingModeTransitionIssue:
        Equatable
    {
        case endpointModifiers

        var message: String {
            switch self {
            case .endpointModifiers:
                return "Preserve Modifiers requires source and destination keys without modifiers. Remove Fn, Shift, Control, Option, or Command before changing this rule."
            }
        }
    }

    let id: UUID

    var sourceCombination: KeyCombination?
    var destinationCombination: KeyCombination?
    var matchingMode: RemapMatchingMode
    var overrides: [RemapOverride]

    /// Remembers the complete Exact Only source while the active rule is
    /// temporarily using Preserve Modifiers.
    ///
    /// This editor-only value is included in session Undo/Redo history but is
    /// never written to persistent rule storage.
    var rememberedExactSourceCombination:
        KeyCombination?

    /// Remembers the complete Exact Only destination while the active rule is
    /// temporarily using Preserve Modifiers.
    ///
    /// This editor-only value is included in session Undo/Redo history but is
    /// never written to persistent rule storage.
    var rememberedExactDestinationCombination:
        KeyCombination?

    init(
        id: UUID = UUID(),
        sourceCombination: KeyCombination? = nil,
        destinationCombination: KeyCombination? = nil,
        matchingMode: RemapMatchingMode = .exact,
        overrides: [RemapOverride] = [],
        rememberedExactSourceCombination:
            KeyCombination? = nil,
        rememberedExactDestinationCombination:
            KeyCombination? = nil
    ) {
        self.id = id
        self.sourceCombination =
            sourceCombination
        self.destinationCombination =
            destinationCombination
        self.matchingMode =
            matchingMode
        self.overrides =
            overrides

        if matchingMode == .exact {
            self.rememberedExactSourceCombination =
                rememberedExactSourceCombination
                    ?? sourceCombination

            self.rememberedExactDestinationCombination =
                rememberedExactDestinationCombination
                    ?? destinationCombination
        } else {
            self.rememberedExactSourceCombination =
                rememberedExactSourceCombination

            self.rememberedExactDestinationCombination =
                rememberedExactDestinationCombination
        }
    }

    init(
        id: UUID = UUID(),
        rule: RemapRule
    ) {
        self.init(
            id: id,
            sourceCombination:
                rule.source,
            destinationCombination:
                rule.destination,
            matchingMode:
                rule.matchingMode,
            overrides:
                rule.overrides
        )
    }

    /// Updates the editable source while applying the normalization required
    /// by the currently selected matching mode.
    mutating func setSourceCombination(
        _ combination:
            KeyCombination
    ) {
        let normalizedCombination =
            normalizedCombination(
                combination
            )

        let previousKeyCode =
            sourceCombination?
                .keyCode

        let physicalKeyChanged =
            previousKeyCode
                != normalizedCombination
                    .keyCode

        if matchingMode == .preserveModifiers,
           physicalKeyChanged {
            invalidateRememberedExactConfiguration()
        }

        sourceCombination =
            normalizedCombination

        if matchingMode == .exact {
            rememberedExactSourceCombination =
                normalizedCombination
        }

        if previousKeyCode != nil,
           physicalKeyChanged {
            retargetOverrides(
                to:
                    normalizedCombination
                        .keyCode
            )
        }
    }

    /// Updates the editable destination while applying the normalization
    /// required by the currently selected matching mode.
    mutating func setDestinationCombination(
        _ combination:
            KeyCombination
    ) {
        let normalizedCombination =
            normalizedCombination(
                combination
            )

        let physicalKeyChanged =
            destinationCombination?
                .keyCode
                != normalizedCombination
                    .keyCode

        if matchingMode == .preserveModifiers,
           physicalKeyChanged {
            invalidateRememberedExactConfiguration()
        }

        destinationCombination =
            normalizedCombination

        if matchingMode == .exact {
            rememberedExactDestinationCombination =
                normalizedCombination
        }
    }

    /// Returns why the requested matching-mode transition cannot be applied.
    ///
    /// Preserve Modifiers uses unmodified physical source and destination keys.
    /// Converting an Exact Only rule that contains endpoint modifiers would
    /// silently broaden the rule, so the transition is rejected instead.
    func matchingModeTransitionIssue(
        to requestedMode:
            RemapMatchingMode
    ) -> MatchingModeTransitionIssue? {
        guard
            requestedMode == .preserveModifiers,
            matchingMode != .preserveModifiers
        else {
            return nil
        }

        let sourceHasModifiers =
            sourceCombination?
                .modifiers
                .isEmpty == false

        let destinationHasModifiers =
            destinationCombination?
                .modifiers
                .isEmpty == false

        guard
            sourceHasModifiers
                || destinationHasModifiers
        else {
            return nil
        }

        return .endpointModifiers
    }

    /// Changes matching mode without permanently losing Exact Only
    /// combinations.
    ///
    /// Exact Only → Preserve Modifiers is applied only when both endpoints
    /// already contain no modifiers. A modified endpoint is never stripped
    /// silently because doing so would change which physical input matches.
    ///
    /// Preserve Modifiers → Exact Only:
    /// - restores the remembered Exact Only combinations when available;
    /// - otherwise keeps the current unmodified endpoints.
    mutating func setMatchingMode(
        _ requestedMode:
            RemapMatchingMode
    ) {
        guard
            requestedMode
                != matchingMode
        else {
            return
        }

        guard
            matchingModeTransitionIssue(
                to: requestedMode
            ) == nil
        else {
            return
        }

        switch requestedMode {
        case .exact:
            sourceCombination =
                rememberedExactSourceCombination
                    ?? sourceCombination

            destinationCombination =
                rememberedExactDestinationCombination
                    ?? destinationCombination

            matchingMode =
                .exact

            rememberedExactSourceCombination =
                sourceCombination

            rememberedExactDestinationCombination =
                destinationCombination

        case .preserveModifiers:
            rememberedExactSourceCombination =
                sourceCombination

            rememberedExactDestinationCombination =
                destinationCombination

            if let sourceCombination {
                self.sourceCombination =
                    KeyCombination(
                        keyCode:
                            sourceCombination
                                .keyCode
                    )
            }

            if let destinationCombination {
                self.destinationCombination =
                    KeyCombination(
                        keyCode:
                            destinationCombination
                                .keyCode
                    )
            }

            matchingMode =
                .preserveModifiers
        }
    }

    /// Returns the source that should appear in the examples for one matching
    /// mode, including a remembered Exact Only combination when available.
    func sourceCombinationForPreview(
        in previewMode:
            RemapMatchingMode
    ) -> KeyCombination? {
        switch previewMode {
        case .exact:
            if matchingMode
                == .preserveModifiers
            {
                return
                    rememberedExactSourceCombination
                        ?? sourceCombination
            }

            return sourceCombination

        case .preserveModifiers:
            guard
                let sourceCombination
            else {
                return nil
            }

            return KeyCombination(
                keyCode:
                    sourceCombination
                        .keyCode
            )
        }
    }

    /// Returns the destination that should appear in the examples for one
    /// matching mode, including a remembered Exact Only combination when
    /// available.
    func destinationCombinationForPreview(
        in previewMode:
            RemapMatchingMode
    ) -> KeyCombination? {
        switch previewMode {
        case .exact:
            if matchingMode
                == .preserveModifiers
            {
                return
                    rememberedExactDestinationCombination
                        ?? destinationCombination
            }

            return destinationCombination

        case .preserveModifiers:
            guard
                let destinationCombination
            else {
                return nil
            }

            return KeyCombination(
                keyCode:
                    destinationCombination
                        .keyCode
            )
        }
    }

    /// Returns a persistable rule only when both endpoints are complete.
    ///
    /// Remembered Exact Only combinations are deliberately excluded because
    /// they are temporary editor state rather than active remapping rules.
    var rule: RemapRule? {
        guard
            let sourceCombination,
            let destinationCombination
        else {
            return nil
        }

        return RemapRule(
            source:
                sourceCombination,
            destination:
                destinationCombination,
            matchingMode:
                matchingMode,
            overrides:
                overrides
        )
    }

    private func normalizedCombination(
        _ combination:
            KeyCombination
    ) -> KeyCombination {
        guard
            matchingMode
                == .preserveModifiers
        else {
            return combination
        }

        return KeyCombination(
            keyCode:
                combination
                    .keyCode
        )
    }

    /// A physical endpoint change made while Preserve Modifiers is active
    /// invalidates the previous Exact Only pair. Returning to Exact Only will
    /// then use the newly configured unmodified endpoints.
    private mutating func invalidateRememberedExactConfiguration() {
        rememberedExactSourceCombination =
            nil

        rememberedExactDestinationCombination =
            nil
    }

    private mutating func retargetOverrides(
        to sourceKeyCode:
            CGKeyCode
    ) {
        overrides =
            overrides.map {
                remapOverride in

                RemapOverride(
                    source:
                        KeyCombination(
                            keyCode:
                                sourceKeyCode,
                            modifiers:
                                remapOverride
                                    .source
                                    .modifiers
                        ),
                    action:
                        remapOverride
                            .action,
                    isEnabled:
                        remapOverride
                            .isEnabled
                )
            }
    }
}
