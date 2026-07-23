//
//  ConfigurationWarningBannerView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/23/26.
//

import AppKit

/// Displays persistent, non-blocking configuration guidance.
///
/// The banner is presentation-only. Showing or hiding it never changes rules,
/// persistence, dirty state, sorting, filtering, or Undo/Redo history.
@MainActor
final class ConfigurationWarningBannerView: NSView {

    private let iconImageView = NSImageView()

    private let messageLabel =
        NSTextField(
            wrappingLabelWithString: ""
        )

    private let contentStack = NSStackView()

    private var contentTopConstraint:
        NSLayoutConstraint?

    private var contentLeadingConstraint:
        NSLayoutConstraint?

    private var contentTrailingConstraint:
        NSLayoutConstraint?

    private var contentBottomConstraint:
        NSLayoutConstraint?

    private var textScale:
        CGFloat = 1.0

    convenience init() {
        self.init(
            frame: .zero
        )
    }

    override init(
        frame frameRect: NSRect
    ) {
        super.init(
            frame: frameRect
        )

        configureContent()
        applyTextScale(
            textScale
        )
        setWarning(
            nil
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
        updateAppearance()
    }

    /// Shows guidance for the supplied warning, or hides the banner when the
    /// warning is `nil`.
    func setWarning(
        _ warning:
            KeyCombinationConfigurationWarning?
    ) {
        setMessage(
            warning?.message
        )
    }

    /// Shows an explicitly supplied informational message.
    ///
    /// Passing `nil` or an empty string hides the banner.
    func setMessage(
        _ message: String?
    ) {
        let resolvedMessage =
            message?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            let resolvedMessage,
            !resolvedMessage.isEmpty
        else {
            messageLabel.stringValue = ""
            toolTip = nil
            isHidden = true
            return
        }

        messageLabel.stringValue =
            resolvedMessage

        toolTip =
            resolvedMessage

        isHidden =
            false
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale =
            InterfaceTextScalePreference
                .clamped(
                    scale
                )

        messageLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * textScale,
                weight:
                    .regular
            )

        contentStack.spacing =
            InterfaceLayoutMetrics.scaled(
                9,
                for:
                    textScale,
                minimum:
                    7,
                maximum:
                    14
            )

        let verticalPadding =
            InterfaceLayoutMetrics.scaled(
                10,
                for:
                    textScale,
                minimum:
                    8,
                maximum:
                    15
            )

        let horizontalPadding =
            InterfaceLayoutMetrics.scaled(
                12,
                for:
                    textScale,
                minimum:
                    10,
                maximum:
                    18
            )

        contentTopConstraint?.constant =
            verticalPadding

        contentLeadingConstraint?.constant =
            horizontalPadding

        contentTrailingConstraint?.constant =
            -horizontalPadding

        contentBottomConstraint?.constant =
            -verticalPadding

        updateWarningIcon()

        needsLayout =
            true
    }

    private func configureContent() {
        wantsLayer =
            true

        layer?.cornerRadius =
            8

        layer?.masksToBounds =
            true

        iconImageView.imageScaling =
            .scaleProportionallyDown

        iconImageView.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        iconImageView
            .setContentCompressionResistancePriority(
                .required,
                for:
                    .horizontal
            )

        messageLabel.maximumNumberOfLines =
            0

        messageLabel.lineBreakMode =
            .byWordWrapping

        messageLabel.isEditable =
            false

        messageLabel.isSelectable =
            true

        messageLabel.drawsBackground =
            false

        messageLabel.isBezeled =
            false

        messageLabel.setContentHuggingPriority(
            .defaultLow,
            for:
                .horizontal
        )

        messageLabel
            .setContentCompressionResistancePriority(
                .defaultLow,
                for:
                    .horizontal
            )

        messageLabel
            .setContentCompressionResistancePriority(
                .required,
                for:
                    .vertical
            )

        contentStack.setViews(
            [
                iconImageView,
                messageLabel
            ],
            in:
                .leading
        )

        contentStack.orientation =
            .horizontal

        contentStack.alignment =
            .top

        contentStack.distribution =
            .fill

        contentStack.translatesAutoresizingMaskIntoConstraints =
            false

        addSubview(
            contentStack
        )

        let contentTopConstraint =
            contentStack.topAnchor.constraint(
                equalTo:
                    topAnchor
            )

        let contentLeadingConstraint =
            contentStack.leadingAnchor.constraint(
                equalTo:
                    leadingAnchor
            )

        let contentTrailingConstraint =
            contentStack.trailingAnchor.constraint(
                equalTo:
                    trailingAnchor
            )

        let contentBottomConstraint =
            contentStack.bottomAnchor.constraint(
                equalTo:
                    bottomAnchor
            )

        self.contentTopConstraint =
            contentTopConstraint

        self.contentLeadingConstraint =
            contentLeadingConstraint

        self.contentTrailingConstraint =
            contentTrailingConstraint

        self.contentBottomConstraint =
            contentBottomConstraint

        NSLayoutConstraint.activate(
            [
                contentTopConstraint,
                contentLeadingConstraint,
                contentTrailingConstraint,
                contentBottomConstraint
            ]
        )

        updateAppearance()
    }

    private func updateWarningIcon() {
        iconImageView.image =
            NSImage(
                systemSymbolName:
                    "exclamationmark.triangle.fill",
                accessibilityDescription:
                    "Configuration warning"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize:
                        14 * textScale,
                    weight:
                        .semibold
                )
            )

        iconImageView.contentTintColor =
            .systemOrange
    }

    private func updateAppearance() {
        messageLabel.textColor =
            .labelColor

        iconImageView.contentTintColor =
            .systemOrange

        layer?.backgroundColor =
            NSColor.systemOrange
                .withAlphaComponent(
                    0.10
                )
                .cgColor

        layer?.borderWidth =
            1

        layer?.borderColor =
            NSColor.systemOrange
                .withAlphaComponent(
                    0.28
                )
                .cgColor
    }
}
