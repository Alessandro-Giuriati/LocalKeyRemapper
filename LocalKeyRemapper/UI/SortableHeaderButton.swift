//
//  SortableHeaderButton.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import AppKit

/// Displays one discoverable sortable-column header.
///
/// The control owns only visual state. Selecting it does not modify rules,
/// persistence, dirty state, rule priority, or Undo/Redo history.
@MainActor
final class SortableHeaderButton: NSButton {

    enum SortState: Equatable {
        case none
        case ascending
        case descending
    }

    private var trackingAreaReference:
        NSTrackingArea?

    private var isHovered = false {
        didSet {
            guard oldValue != isHovered else {
                return
            }

            updateAppearance()
        }
    }

    private(set) var sortState:
        SortState = .none

    override init(
        frame frameRect: NSRect
    ) {
        super.init(
            frame: frameRect
        )

        configureControl()
        updateAppearance()
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaReference {
            removeTrackingArea(
                trackingAreaReference
            )
        }

        let trackingArea =
            NSTrackingArea(
                rect: bounds,
                options: [
                    .activeInActiveApp,
                    .mouseEnteredAndExited,
                    .inVisibleRect
                ],
                owner: self,
                userInfo: nil
            )

        addTrackingArea(
            trackingArea
        )

        trackingAreaReference =
            trackingArea
    }

    override func mouseEntered(
        with event: NSEvent
    ) {
        isHovered = true
    }

    override func mouseExited(
        with event: NSEvent
    ) {
        isHovered = false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    func setSortState(
        _ newState: SortState
    ) {
        guard sortState != newState else {
            return
        }

        sortState = newState
        updateAppearance()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        font =
            NSFont.systemFont(
                ofSize: 13 * scale,
                weight:
                    sortState == .none
                        ? .medium
                        : .semibold
            )

        updateAppearance()
    }

    private func configureControl() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

        isBordered = false
        alignment = .left
        imagePosition = .imageTrailing
        imageScaling = .scaleProportionallyDown
        focusRingType = .none

        setButtonType(
            .momentaryChange
        )

        setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        setContentCompressionResistancePriority(
            .defaultHigh,
            for: .horizontal
        )

        applyTextScale(
            1.0
        )
    }

    private func updateAppearance() {
        let foregroundColor: NSColor
        let backgroundColor: NSColor
        let fontWeight: NSFont.Weight

        switch sortState {
        case .none:
            foregroundColor =
                isHovered
                    ? .labelColor
                    : .secondaryLabelColor

            backgroundColor =
                isHovered
                    ? NSColor.selectedContentBackgroundColor
                        .withAlphaComponent(0.22)
                    : .clear

            fontWeight = .medium

        case .ascending,
             .descending:
            foregroundColor =
                .labelColor

            backgroundColor =
                isHovered
                    ? NSColor.controlAccentColor
                .withAlphaComponent(0.33)
                    : NSColor.controlAccentColor
                .withAlphaComponent(0.22)

            fontWeight = .semibold
        }

        layer?.backgroundColor =
            backgroundColor.cgColor

        let currentPointSize =
            font?.pointSize
                ?? 13

        let currentFont =
            NSFont.systemFont(
                ofSize: currentPointSize,
                weight: fontWeight
            )

        font = currentFont
        contentTintColor = foregroundColor

        let paragraphStyle =
            NSMutableParagraphStyle()

        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode =
            .byTruncatingTail

        attributedTitle =
            NSAttributedString(
                string: title,
                attributes: [
                    .foregroundColor:
                        foregroundColor,
                    .font:
                        currentFont,
                    .paragraphStyle:
                        paragraphStyle
                ]
            )

        image =
            NSImage(
                systemSymbolName:
                    symbolName,
                accessibilityDescription:
                    symbolAccessibilityDescription
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: 10,
                    weight: .semibold
                )
            )

        toolTip =
            sortState == .none
                ? "Click to sort by \(title)."
                : "Click to reverse sorting by \(title)."
    }

    private var symbolName: String {
        switch sortState {
        case .none:
            return "arrow.up.arrow.down"

        case .ascending:
            return "chevron.up"

        case .descending:
            return "chevron.down"
        }
    }

    private var symbolAccessibilityDescription:
        String
    {
        switch sortState {
        case .none:
            return "Sortable column"

        case .ascending:
            return "Sorted ascending"

        case .descending:
            return "Sorted descending"
        }
    }
}

/// Provides a subtle visual container for the sortable table headers.
@MainActor
final class RulesHeaderBackgroundView: NSView {

    override init(
        frame frameRect: NSRect
    ) {
        super.init(
            frame: frameRect
        )

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1

        updateAppearance()
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

    private func updateAppearance() {
        layer?.backgroundColor =
            NSColor.controlBackgroundColor
                .withAlphaComponent(0.55)
                .cgColor

        layer?.borderColor =
            NSColor.separatorColor
                .withAlphaComponent(0.55)
                .cgColor
    }
}
