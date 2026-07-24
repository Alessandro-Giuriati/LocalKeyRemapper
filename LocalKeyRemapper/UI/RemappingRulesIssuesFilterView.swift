//
//  RemappingRulesIssuesFilterView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/23/26.
//

import AppKit

/// Displays the sortable Issues column title above two independent
/// presentation filters.
///
/// The red filter shows rules with blocking validation issues. The yellow
/// filter shows rules with non-blocking Fn configuration warnings. When both
/// filters are active, matching uses OR semantics.
@MainActor
final class RemappingRulesIssuesFilterView:
    NSView
{
    var onSortRequested:
        (() -> Void)?

    var onValidationFilterToggle:
        (() -> Void)?

    var onWarningFilterToggle:
        (() -> Void)?

    private let titleButton =
        SortableHeaderButton(
            frame: .zero
        )

    private let validationFilterButton =
        NSButton()

    private let warningFilterButton =
        NSButton()

    private let filterButtonsStack =
        NSStackView()

    private let stackView =
        NSStackView()

    private var validationFilterIsActive =
        false

    private var warningFilterIsActive =
        false

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

        setFilterState(
            validationIsActive:
                false,
            warningIsActive:
                false
        )
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

    override var intrinsicContentSize:
        NSSize
    {
        NSSize(
            width:
                72,
            height:
                46
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateButtonPresentation()
    }

    // AppKit's normal child hit testing is intentionally preserved so each
    // nested button receives its own mouse events and target/action callback.

    func setSortState(
        _ state:
            SortableHeaderButton.SortState
    ) {
        titleButton.setSortState(
            state
        )
    }

    func setFilterState(
        validationIsActive: Bool,
        warningIsActive: Bool
    ) {
        validationFilterIsActive =
            validationIsActive

        warningFilterIsActive =
            warningIsActive

        updateButtonPresentation()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale =
            InterfaceTextScalePreference
                .clamped(
                    scale
                )

        titleButton.applyTextScale(
            textScale
        )

        stackView.spacing =
            InterfaceLayoutMetrics.scaled(
                1,
                for:
                    textScale,
                minimum:
                    0,
                maximum:
                    3
            )

        filterButtonsStack.spacing =
            InterfaceLayoutMetrics.scaled(
                4,
                for:
                    textScale,
                minimum:
                    3,
                maximum:
                    6
            )

        updateButtonSymbols()

        invalidateIntrinsicContentSize()

        needsLayout =
            true
    }

    private func configureContent() {
        titleButton.title =
            "Issues"

        titleButton.target =
            self

        titleButton.action =
            #selector(
                sortRequested
            )

        titleButton.setAccessibilityLabel(
            "Sort by Issues"
        )

        titleButton.sendAction(
            on:
                .leftMouseUp
        )

        configureFilterButton(
            validationFilterButton,
            action:
                #selector(
                    validationFilterPressed
                ),
            accessibilityLabel:
                "Show only rules with validation errors",
            toolTip:
                "Show only rules with blocking validation errors."
        )

        configureFilterButton(
            warningFilterButton,
            action:
                #selector(
                    warningFilterPressed
                ),
            accessibilityLabel:
                "Show only rules with Fn warnings",
            toolTip:
                "Show only rules with non-blocking Fn configuration warnings."
        )

        filterButtonsStack.setViews(
            [
                validationFilterButton,
                warningFilterButton
            ],
            in:
                .leading
        )

        filterButtonsStack.orientation =
            .horizontal

        filterButtonsStack.alignment =
            .centerY

        filterButtonsStack.distribution =
            .fill

        filterButtonsStack.translatesAutoresizingMaskIntoConstraints =
            false

        stackView.setViews(
            [
                titleButton,
                filterButtonsStack
            ],
            in:
                .leading
        )

        stackView.orientation =
            .vertical

        stackView.alignment =
            .centerX

        stackView.distribution =
            .fill

        stackView.translatesAutoresizingMaskIntoConstraints =
            false

        addSubview(
            stackView
        )

        NSLayoutConstraint.activate(
            [
                stackView.leadingAnchor.constraint(
                    equalTo:
                        leadingAnchor
                ),

                stackView.trailingAnchor.constraint(
                    equalTo:
                        trailingAnchor
                ),

                stackView.centerYAnchor.constraint(
                    equalTo:
                        centerYAnchor
                ),

                titleButton.widthAnchor.constraint(
                    equalTo:
                        stackView.widthAnchor
                ),

                titleButton.heightAnchor.constraint(
                    equalToConstant:
                        23
                ),

                validationFilterButton.widthAnchor.constraint(
                    equalToConstant:
                        20
                ),

                validationFilterButton.heightAnchor.constraint(
                    equalToConstant:
                        20
                ),

                warningFilterButton.widthAnchor.constraint(
                    equalToConstant:
                        20
                ),

                warningFilterButton.heightAnchor.constraint(
                    equalToConstant:
                        20
                )
            ]
        )

        setContentHuggingPriority(
            .required,
            for:
                .vertical
        )

        setContentCompressionResistancePriority(
            .required,
            for:
                .vertical
        )
    }

    private func configureFilterButton(
        _ button: NSButton,
        action: Selector,
        accessibilityLabel: String,
        toolTip: String
    ) {
        button.setButtonType(
            .momentaryPushIn
        )

        button.isBordered =
            false

        button.focusRingType =
            .none

        button.imagePosition =
            .imageOnly

        button.imageScaling =
            .scaleProportionallyDown

        button.title =
            ""

        button.target =
            self

        button.action =
            action

        button.sendAction(
            on:
                .leftMouseUp
        )

        button.toolTip =
            toolTip

        button.wantsLayer =
            true

        button.layer?.cornerRadius =
            5

        button.layer?.masksToBounds =
            true

        button.setAccessibilityLabel(
            accessibilityLabel
        )

        button.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        button
            .setContentCompressionResistancePriority(
                .required,
                for:
                    .horizontal
            )
    }

    private func updateButtonSymbols() {
        validationFilterButton.image =
            NSImage(
                systemSymbolName:
                    "xmark.octagon.fill",
                accessibilityDescription:
                    "Validation error filter"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize:
                        10.5 * textScale,
                    weight:
                        .medium
                )
            )

        warningFilterButton.image =
            NSImage(
                systemSymbolName:
                    "exclamationmark.triangle.fill",
                accessibilityDescription:
                    "Fn warning filter"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize:
                        10.5 * textScale,
                    weight:
                        .medium
                )
            )
    }

    private func updateButtonPresentation() {
        updateButtonSymbols()

        updateButton(
            validationFilterButton,
            color:
                .systemRed,
            isActive:
                validationFilterIsActive
        )

        updateButton(
            warningFilterButton,
            color:
                .systemYellow,
            isActive:
                warningFilterIsActive
        )
    }

    private func updateButton(
        _ button: NSButton,
        color: NSColor,
        isActive: Bool
    ) {
        button.contentTintColor =
            color

        button.alphaValue =
            isActive
                ? 1.0
                : 0.48

        button.layer?.backgroundColor =
            isActive
                ? color
                    .withAlphaComponent(
                        0.16
                    )
                    .cgColor
                : NSColor.clear
                    .cgColor

        button.setAccessibilityValue(
            isActive
                ? "Active"
                : "Inactive"
        )
    }

    @objc
    private func sortRequested() {
        onSortRequested?()
    }

    @objc
    private func validationFilterPressed() {
        onValidationFilterToggle?()
    }

    @objc
    private func warningFilterPressed() {
        onWarningFilterToggle?()
    }
}
