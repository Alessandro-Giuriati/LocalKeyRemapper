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

    private let validationImageView =
        NSImageView()

    private let warningImageView =
        NSImageView()

    private var validationCenterXConstraint:
        NSLayoutConstraint?

    private var warningCenterXConstraint:
        NSLayoutConstraint?

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
        textScale =
            InterfaceTextScalePreference
                .clamped(
                    scale
                )

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
                false

            addSubview(
                imageView
            )
        }

        let validationCenterXConstraint =
            validationImageView
                .centerXAnchor
                .constraint(
                    equalTo:
                        centerXAnchor
                )

        let warningCenterXConstraint =
            warningImageView
                .centerXAnchor
                .constraint(
                    equalTo:
                        centerXAnchor
                )

        self.validationCenterXConstraint =
            validationCenterXConstraint

        self.warningCenterXConstraint =
            warningCenterXConstraint

        NSLayoutConstraint.activate(
            [
                validationImageView.centerYAnchor.constraint(
                    equalTo:
                        centerYAnchor
                ),

                validationCenterXConstraint,

                validationImageView.widthAnchor.constraint(
                    equalToConstant:
                        22
                ),

                validationImageView.heightAnchor.constraint(
                    equalTo:
                        validationImageView
                            .widthAnchor
                ),

                warningImageView.centerYAnchor.constraint(
                    equalTo:
                        centerYAnchor
                ),

                warningCenterXConstraint,

                warningImageView.widthAnchor.constraint(
                    equalToConstant:
                        22
                ),

                warningImageView.heightAnchor.constraint(
                    equalTo:
                        warningImageView
                            .widthAnchor
                )
            ]
        )

        validationImageView.setAccessibilityLabel(
            "Validation error"
        )

        warningImageView.setAccessibilityLabel(
            "Configuration warning"
        )
    }

    private func updateSymbols() {
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
        updateSymbols()

        let hasValidationIssue =
            validationMessage != nil

        let hasConfigurationWarning =
            configurationWarningMessage != nil

        updateIndicatorPositions(
            hasValidationIssue:
                hasValidationIssue,
            hasConfigurationWarning:
                hasConfigurationWarning
        )

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
    }

    private func updateIndicatorPositions(
        hasValidationIssue: Bool,
        hasConfigurationWarning: Bool
    ) {
        if hasValidationIssue
            && hasConfigurationWarning
        {
            validationCenterXConstraint?.constant =
                -13

            warningCenterXConstraint?.constant =
                13
        } else {
            validationCenterXConstraint?.constant =
                0

            warningCenterXConstraint?.constant =
                0
        }

        needsLayout =
            true
    }
}
