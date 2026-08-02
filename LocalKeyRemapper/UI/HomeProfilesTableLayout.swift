//
//  HomeProfilesTableLayout.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 8/1/26.
//

import CoreGraphics

/// Calculates a stable, non-scrolling column layout for the Home Profiles
/// table.
///
/// The table progressively reduces secondary presentation details while
/// preserving the configured profile name and shortcut mode for as long as
/// possible. The compression order from widest to narrowest is:
///
/// 1. Show the complete month name.
/// 2. Abbreviate the month to three letters.
/// 3. Replace labeled action buttons with symbols.
/// 4. Replace the Shortcut Edit label with the keyboard symbol.
/// 5. Replace the abbreviated date with the numeric short date.
///
/// `widestFullDateWidth` must be measured from the longest full-month date in
/// the active locale, plus one additional character of safety. This prevents a
/// short month such as July from enabling the full-date layout when September
/// would not fit.
nonisolated struct HomeProfilesTableLayout:
    Equatable
{
    enum Stage:
        Int,
        CaseIterable,
        Equatable
    {
        case fullDate = 0
        case abbreviatedDate = 1
        case compactActions = 2
        case compactShortcut = 3
        case compactDate = 4
    }

    enum ActionsPresentation:
        Equatable
    {
        case labeled
        case symbolsOnly
    }

    enum ShortcutEditPresentation:
        Equatable
    {
        case labeled
        case symbolOnly
    }

    enum DatePresentation:
        Equatable
    {
        case fullMonth
        case abbreviatedMonth
        case numeric
    }

    struct Metrics:
        Equatable
    {
        let minimumProfileWidth:
            CGFloat

        let rulesWidth:
            CGFloat

        let labeledShortcutWidth:
            CGFloat

        let symbolShortcutWidth:
            CGFloat

        /// Width of the longest full-month date plus one character of safety.
        let widestFullDateWidth:
            CGFloat

        let abbreviatedDateWidth:
            CGFloat

        let numericDateWidth:
            CGFloat

        let labeledActionsWidth:
            CGFloat

        let symbolActionsWidth:
            CGFloat

        let columnSpacing:
            CGFloat

        init(
            minimumProfileWidth:
                CGFloat,
            rulesWidth:
                CGFloat,
            labeledShortcutWidth:
                CGFloat,
            symbolShortcutWidth:
                CGFloat,
            widestFullDateWidth:
                CGFloat,
            abbreviatedDateWidth:
                CGFloat,
            numericDateWidth:
                CGFloat,
            labeledActionsWidth:
                CGFloat,
            symbolActionsWidth:
                CGFloat,
            columnSpacing:
                CGFloat
        ) {
            self.minimumProfileWidth =
                max(
                    0,
                    minimumProfileWidth
                )

            self.rulesWidth =
                max(
                    0,
                    rulesWidth
                )

            self.labeledShortcutWidth =
                max(
                    0,
                    labeledShortcutWidth
                )

            self.symbolShortcutWidth =
                max(
                    0,
                    symbolShortcutWidth
                )

            self.widestFullDateWidth =
                max(
                    0,
                    widestFullDateWidth
                )

            self.abbreviatedDateWidth =
                max(
                    0,
                    abbreviatedDateWidth
                )

            self.numericDateWidth =
                max(
                    0,
                    numericDateWidth
                )

            self.labeledActionsWidth =
                max(
                    0,
                    labeledActionsWidth
                )

            self.symbolActionsWidth =
                max(
                    0,
                    symbolActionsWidth
                )

            self.columnSpacing =
                max(
                    0,
                    columnSpacing
                )
        }
    }

    let stage:
        Stage

    let actionsPresentation:
        ActionsPresentation

    let shortcutEditPresentation:
        ShortcutEditPresentation

    let datePresentation:
        DatePresentation

    let profileWidth:
        CGFloat

    let rulesWidth:
        CGFloat

    let shortcutWidth:
        CGFloat

    let createdWidth:
        CGFloat

    let actionsWidth:
        CGFloat

    let columnSpacing:
        CGFloat

    var totalWidth:
        CGFloat
    {
        profileWidth
            + rulesWidth
            + shortcutWidth
            + createdWidth
            + actionsWidth
            + Self.totalSpacing(
                columnSpacing:
                    columnSpacing
            )
    }

    static func resolved(
        availableWidth:
            CGFloat,
        metrics:
            Metrics
    ) -> HomeProfilesTableLayout {
        let normalizedAvailableWidth =
            max(
                0,
                availableWidth
            )

        let stage =
            Stage
                .allCases
                .first {
                    minimumRequiredWidth(
                        for:
                            $0,
                        metrics:
                            metrics
                    )
                        <= normalizedAvailableWidth
                }
                ?? .compactDate

        let presentation =
            presentation(
                for:
                    stage
            )

        let rulesWidth =
            metrics.rulesWidth

        let shortcutWidth =
            presentation
                .shortcutEditPresentation
                == .labeled
                    ? metrics.labeledShortcutWidth
                    : metrics.symbolShortcutWidth

        let createdWidth:
            CGFloat

        switch presentation.datePresentation {
        case .fullMonth:
            createdWidth =
                metrics.widestFullDateWidth

        case .abbreviatedMonth:
            createdWidth =
                metrics.abbreviatedDateWidth

        case .numeric:
            createdWidth =
                metrics.numericDateWidth
        }

        let actionsWidth =
            presentation
                .actionsPresentation
                == .labeled
                    ? metrics.labeledActionsWidth
                    : metrics.symbolActionsWidth

        let spacingWidth =
            totalSpacing(
                columnSpacing:
                    metrics.columnSpacing
            )

        let fixedWidth =
            rulesWidth
                + shortcutWidth
                + createdWidth
                + actionsWidth
                + spacingWidth

        let profileWidth =
            max(
                0,
                normalizedAvailableWidth
                    - fixedWidth
            )

        return HomeProfilesTableLayout(
            stage:
                stage,
            actionsPresentation:
                presentation
                    .actionsPresentation,
            shortcutEditPresentation:
                presentation
                    .shortcutEditPresentation,
            datePresentation:
                presentation
                    .datePresentation,
            profileWidth:
                profileWidth,
            rulesWidth:
                rulesWidth,
            shortcutWidth:
                shortcutWidth,
            createdWidth:
                createdWidth,
            actionsWidth:
                actionsWidth,
            columnSpacing:
                metrics.columnSpacing
        )
    }

    static func minimumRequiredWidth(
        for stage:
            Stage,
        metrics:
            Metrics
    ) -> CGFloat {
        let presentation =
            presentation(
                for:
                    stage
            )

        let shortcutWidth =
            presentation
                .shortcutEditPresentation
                == .labeled
                    ? metrics.labeledShortcutWidth
                    : metrics.symbolShortcutWidth

        let createdWidth:
            CGFloat

        switch presentation.datePresentation {
        case .fullMonth:
            createdWidth =
                metrics.widestFullDateWidth

        case .abbreviatedMonth:
            createdWidth =
                metrics.abbreviatedDateWidth

        case .numeric:
            createdWidth =
                metrics.numericDateWidth
        }

        let actionsWidth =
            presentation
                .actionsPresentation
                == .labeled
                    ? metrics.labeledActionsWidth
                    : metrics.symbolActionsWidth

        return metrics.minimumProfileWidth
            + metrics.rulesWidth
            + shortcutWidth
            + createdWidth
            + actionsWidth
            + totalSpacing(
                columnSpacing:
                    metrics.columnSpacing
            )
    }

    private static func presentation(
        for stage:
            Stage
    ) -> (
        actionsPresentation:
            ActionsPresentation,
        shortcutEditPresentation:
            ShortcutEditPresentation,
        datePresentation:
            DatePresentation
    ) {
        switch stage {
        case .fullDate:
            return (
                actionsPresentation:
                    .labeled,
                shortcutEditPresentation:
                    .labeled,
                datePresentation:
                    .fullMonth
            )

        case .abbreviatedDate:
            return (
                actionsPresentation:
                    .labeled,
                shortcutEditPresentation:
                    .labeled,
                datePresentation:
                    .abbreviatedMonth
            )

        case .compactActions:
            return (
                actionsPresentation:
                    .symbolsOnly,
                shortcutEditPresentation:
                    .labeled,
                datePresentation:
                    .abbreviatedMonth
            )

        case .compactShortcut:
            return (
                actionsPresentation:
                    .symbolsOnly,
                shortcutEditPresentation:
                    .symbolOnly,
                datePresentation:
                    .abbreviatedMonth
            )

        case .compactDate:
            return (
                actionsPresentation:
                    .symbolsOnly,
                shortcutEditPresentation:
                    .symbolOnly,
                datePresentation:
                    .numeric
            )
        }
    }

    private static func totalSpacing(
        columnSpacing:
            CGFloat
    ) -> CGFloat {
        columnSpacing
            * 4
    }
}
