//
//  GlobalShortcutSettingsViewPLUSDefaultPresentation.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import AppKit

/// Applies the Home-specific presentation used now that profiles may define
/// shortcut overrides.
///
/// `GlobalShortcutSettingsView` remains reusable for its existing compatibility
/// call sites. This extension changes only the two leading presentation labels
/// in the Home instance and does not alter shortcut state or validation.
@MainActor
extension GlobalShortcutSettingsView {

    func applyDefaultGlobalShortcutPresentation() {
        guard
            let contentStack =
                subviews
                    .compactMap({
                        $0 as? NSStackView
                    })
                    .first
        else {
            return
        }

        let leadingLabels =
            contentStack
                .arrangedSubviews
                .compactMap {
                    $0 as? NSTextField
                }

        guard
            leadingLabels.count >= 2
        else {
            return
        }

        leadingLabels[0].stringValue =
            "Default Global Shortcuts"

        leadingLabels[1].stringValue =
            "Used by profiles set to Use Default. Profiles with Off, Toggle, or Separate overrides use their own shortcut settings. Changes are saved with the Home configuration."
    }

    // MARK: - Test support

    var defaultSectionTitleForTesting:
        String?
    {
        leadingPresentationLabels
            .first?
            .stringValue
    }

    var defaultSectionDescriptionForTesting:
        String?
    {
        guard
            leadingPresentationLabels.count >= 2
        else {
            return nil
        }

        return leadingPresentationLabels[1]
            .stringValue
    }

    private var leadingPresentationLabels:
        [NSTextField]
    {
        guard
            let contentStack =
                subviews
                    .compactMap({
                        $0 as? NSStackView
                    })
                    .first
        else {
            return []
        }

        return contentStack
            .arrangedSubviews
            .compactMap {
                $0 as? NSTextField
            }
    }
}
