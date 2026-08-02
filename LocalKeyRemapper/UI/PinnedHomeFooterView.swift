//
//  PinnedHomeFooterView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 8/2/26.
//

import AppKit

/// A fixed Home footer that remains outside the scrollable settings content.
///
/// The status message collapses when hidden, while the Home Undo, Redo, and
/// Save controls remain visible at the bottom of the window.
@MainActor
final class PinnedHomeFooterView:
    NSView
{
    private let separator =
        NSBox()

    private let contentStack =
        NSStackView()

    init(
        statusView:
            NSView,
        actionsView:
            NSView
    ) {
        super.init(
            frame:
                .zero
        )

        wantsLayer =
            true

        separator.boxType =
            .separator

        separator.translatesAutoresizingMaskIntoConstraints =
            false

        statusView.translatesAutoresizingMaskIntoConstraints =
            false

        actionsView.translatesAutoresizingMaskIntoConstraints =
            false

        contentStack.setViews(
            [
                statusView,
                actionsView
            ],
            in:
                .leading
        )

        contentStack.orientation =
            .vertical

        contentStack.alignment =
            .leading

        contentStack.spacing =
            6

        contentStack.translatesAutoresizingMaskIntoConstraints =
            false

        addSubview(
            separator
        )

        addSubview(
            contentStack
        )

        NSLayoutConstraint.activate(
            [
                separator.topAnchor.constraint(
                    equalTo:
                        topAnchor
                ),

                separator.leadingAnchor.constraint(
                    equalTo:
                        leadingAnchor
                ),

                separator.trailingAnchor.constraint(
                    equalTo:
                        trailingAnchor
                ),

                contentStack.topAnchor.constraint(
                    equalTo:
                        separator.bottomAnchor,
                    constant:
                        8
                ),

                contentStack.leadingAnchor.constraint(
                    equalTo:
                        leadingAnchor,
                    constant:
                        28
                ),

                contentStack.trailingAnchor.constraint(
                    equalTo:
                        trailingAnchor,
                    constant:
                        -28
                ),

                contentStack.bottomAnchor.constraint(
                    equalTo:
                        bottomAnchor,
                    constant:
                        -12
                ),

                statusView.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                ),

                actionsView.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                )
            ]
        )

        updateBackgroundColor()
    }

    required init?(
        coder:
            NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
    }

    private func updateBackgroundColor() {
        layer?.backgroundColor =
            NSColor.windowBackgroundColor.cgColor
    }
}
