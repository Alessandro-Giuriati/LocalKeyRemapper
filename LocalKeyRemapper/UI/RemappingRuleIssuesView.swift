//
//  RemappingRuleIssuesView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/23/26.
//

import AppKit

/// Presents red and yellow issue indicators for one remapping-rule row.
///
/// A single visible indicator is centered in the Issues column. When both are
/// visible, they are displayed side by side around the column center.
///
/// The view is presentation-only. Updating either indicator never changes the
/// editor session, persistent rules, dirty state, sorting, filtering, or
/// Undo/Redo history.
@MainActor
final class RemappingRuleIssuesView: NSView {

    private enum LayoutMetrics {
        static let indicatorSide: CGFloat = 22
        static let pairedCenterOffset: CGFloat = 13
    }

    private let validationImageView =
        NSImageView()

    private let warningImageView =
        NSImageView()

    private var validationMessage:
        String?

    /// Generic non-blocking warning text shown by the yellow indicator.
    ///
    /// Keeping presentation as a plain message allows the same indicator to
    /// represent Fn guidance, reserved shortcuts, and future warnings without
    /// coupling this view to one specific warning policy.
    private var configurationWarningMessage:
        String?

    private var textScale:
        CGFloat = 1.0

    private var hasAppliedTextScale =
        false

    private var symbolUpdateCount =
        0

    override init(
        frame frameRect: NSRect
    ) {
        super.init(
            frame:
                frameRect
        )

        configureContent()
        applyTextScale(
            textScale
        )
        updatePresentation()
    }

    convenience init() {
        self.init(
            frame:
                .zero
        )
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updatePresentation()
    }

    override func layout() {
        super.layout()
        layoutIndicators()
    }

    func setValidationMessage(
        _ message: String?
    ) {
        validationMessage =
            message

        updatePresentation()
    }

    /// Compatibility entry point for existing key-combination warnings.
    func setConfigurationWarning(
        _ warning:
            KeyCombinationConfigurationWarning?
    ) {
        setConfigurationWarningMessage(
            warning?.message
        )
    }

    /// Associates any non-blocking configuration warning with this row.
    ///
    /// The message controls only the yellow indicator and its tooltip.
    func setConfigurationWarningMessage(
        _ message: String?
    ) {
        configurationWarningMessage =
            message

        updatePresentation()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        let clampedScale =
            InterfaceTextScalePreference
                .clamped(
                    scale
                )

        guard
            !hasAppliedTextScale
                || abs(
                    textScale
                        - clampedScale
                ) > 0.0001
        else {
            return
        }

        textScale =
            clampedScale

        hasAppliedTextScale =
            true

        updateSymbols()
        needsLayout =
            true
    }

    private func configureContent() {
        let views: [NSImageView] = [
            validationImageView,
            warningImageView
        ]

        for imageView in views {
            imageView.imageScaling =
                .scaleProportionallyDown

            imageView.translatesAutoresizingMaskIntoConstraints =
                true

            imageView.autoresizingMask =
                []

            addSubview(
                imageView
            )
        }

        validationImageView.setAccessibilityLabel(
            "Validation error"
        )

        warningImageView.setAccessibilityLabel(
            "Configuration warning"
        )
    }

    private func updateSymbols() {
        symbolUpdateCount +=
            1

        validationImageView.image =
            NSImage(
                systemSymbolName:
                    "xmark.octagon.fill",
                accessibilityDescription:
                    "Validation error"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize:
                        13 * textScale,
                    weight:
                        .medium
                )
            )

        warningImageView.image =
            NSImage(
                systemSymbolName:
                    "exclamationmark.triangle.fill",
                accessibilityDescription:
                    "Configuration warning"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize:
                        13 * textScale,
                    weight:
                        .medium
                )
            )
    }

    private func updatePresentation() {
        let hasValidationIssue =
            validationMessage != nil

        let hasConfigurationWarning =
            configurationWarningMessage != nil

        validationImageView.contentTintColor =
            .systemRed

        validationImageView.alphaValue =
            hasValidationIssue
                ? 1
                : 0

        validationImageView.toolTip =
            validationMessage

        validationImageView.setAccessibilityHidden(
            !hasValidationIssue
        )

        validationImageView.setAccessibilityValue(
            validationMessage
                ?? "No validation error"
        )

        warningImageView.contentTintColor =
            .systemYellow

        warningImageView.alphaValue =
            hasConfigurationWarning
                ? 1
                : 0

        warningImageView.toolTip =
            configurationWarningMessage

        warningImageView.setAccessibilityHidden(
            !hasConfigurationWarning
        )

        warningImageView.setAccessibilityValue(
            configurationWarningMessage
                ?? "No configuration warning"
        )

        needsLayout =
            true
    }

    private func layoutIndicators() {
        let side =
            min(
                LayoutMetrics
                    .indicatorSide,
                min(
                    bounds.width,
                    bounds.height
                )
            )

        let hasValidationIssue =
            validationMessage != nil

        let hasConfigurationWarning =
            configurationWarningMessage != nil

        let validationOffset:
            CGFloat

        let warningOffset:
            CGFloat

        if hasValidationIssue
            && hasConfigurationWarning
        {
            validationOffset =
                -LayoutMetrics
                    .pairedCenterOffset

            warningOffset =
                LayoutMetrics
                    .pairedCenterOffset
        } else {
            validationOffset =
                0

            warningOffset =
                0
        }

        validationImageView.frame =
            indicatorFrame(
                side:
                    side,
                centerOffset:
                    validationOffset
            )

        warningImageView.frame =
            indicatorFrame(
                side:
                    side,
                centerOffset:
                    warningOffset
            )
    }

    private func indicatorFrame(
        side: CGFloat,
        centerOffset: CGFloat
    ) -> NSRect {
        NSRect(
            x:
                bounds.midX
                + centerOffset
                - side / 2,
            y:
                bounds.midY
                - side / 2,
            width:
                side,
            height:
                side
        )
    }

    // MARK: - Test support

    var directConstraintCountForTesting: Int {
        constraints.count
    }

    var indicatorFramesForTesting:
        (validation: NSRect, warning: NSRect)
    {
        (
            validation:
                validationImageView.frame,
            warning:
                warningImageView.frame
        )
    }

    var symbolUpdateCountForTesting: Int {
        symbolUpdateCount
    }
}
