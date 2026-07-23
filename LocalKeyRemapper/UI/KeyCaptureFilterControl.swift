//
//  KeyCaptureFilterControl.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import AppKit
import CoreGraphics

/// Displays one Source or Destination filter that is selected by local
/// key capture instead of text entry.
///
/// The control owns only visual state and callbacks. It never modifies rules,
/// persistence, dirty state, rule priority, or Undo/Redo history.
@MainActor
final class KeyCaptureFilterControl: NSView {

    var onCaptureRequested: (() -> Void)?
    var onClearRequested: (() -> Void)?

    private let fieldTitle: String
    private let captureButton = NSButton()
    private let clearButton = NSButton()
    private let contentStack = NSStackView()

    private var filterKeyCode: CGKeyCode?
    private var isCapturing = false
    private var textScale: CGFloat = 1.0

    init(
        fieldTitle: String
    ) {
        self.fieldTitle = fieldTitle

        super.init(
            frame: .zero
        )

        configureContent()
        updateAppearance()
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    func setFilterKeyCode(
        _ keyCode: CGKeyCode?
    ) {
        filterKeyCode = keyCode
        isCapturing = false
        updateAppearance()
    }

    func showCapturePrompt() {
        isCapturing = true
        updateAppearance()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale = scale

        captureButton.font =
            NSFont.systemFont(
                ofSize: 13 * scale,
                weight:
                    filterKeyCode == nil
                        ? .regular
                        : .medium
            )

        clearButton.image =
            NSImage(
                systemSymbolName:
                    "xmark.circle.fill",
                accessibilityDescription:
                    "Clear \(fieldTitle) filter"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: 12 * scale,
                    weight: .regular
                )
            )

        contentStack.spacing =
            6 * scale

        needsLayout = true
    }

    private func configureContent() {
        captureButton.bezelStyle =
            .rounded

        captureButton.imagePosition =
            .imageLeading

        captureButton.imageScaling =
            .scaleProportionallyDown

        captureButton.target =
            self

        captureButton.action =
            #selector(
                captureButtonPressed
            )

        captureButton.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        captureButton
            .setContentCompressionResistancePriority(
                .defaultLow,
                for: .horizontal
            )

        clearButton.isBordered =
            false

        clearButton.bezelStyle =
            .inline

        clearButton.target =
            self

        clearButton.action =
            #selector(
                clearButtonPressed
            )

        clearButton.toolTip =
            "Clear the \(fieldTitle) filter."

        clearButton.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        clearButton
            .setContentCompressionResistancePriority(
                .required,
                for: .horizontal
            )

        contentStack.setViews(
            [
                captureButton,
                clearButton
            ],
            in: .leading
        )

        contentStack.orientation =
            .horizontal

        contentStack.alignment =
            .centerY

        contentStack.distribution =
            .fill

        contentStack.translatesAutoresizingMaskIntoConstraints =
            false

        addSubview(
            contentStack
        )

        NSLayoutConstraint.activate(
            [
                contentStack.topAnchor.constraint(
                    equalTo:
                        topAnchor
                ),

                contentStack.leadingAnchor.constraint(
                    equalTo:
                        leadingAnchor
                ),

                contentStack.trailingAnchor.constraint(
                    equalTo:
                        trailingAnchor
                ),

                contentStack.bottomAnchor.constraint(
                    equalTo:
                        bottomAnchor
                ),

                captureButton.heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        28
                ),

                clearButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        22
                )
            ]
        )

        applyTextScale(
            textScale
        )
    }

    private func updateAppearance() {
        let title: String
        let symbolName: String
        let accessibilityValue: String
        let toolTip: String

        if isCapturing {
            title = "Press a key…"
            symbolName = "keyboard"
            accessibilityValue =
                "Waiting for a physical key"

            toolTip =
                "Press a physical key. Modifiers are ignored. Press Escape or click again to cancel."
        } else if let filterKeyCode {
            let keyName =
                KeyboardLayoutKeyName.name(
                    for: filterKeyCode
                )

            title =
                "\(fieldTitle): \(keyName)"

            symbolName =
                "line.3.horizontal.decrease.circle.fill"

            accessibilityValue =
                "Filtering \(fieldTitle) by \(keyName)"

            toolTip =
                "Click to replace the \(fieldTitle) filter with another physical key."
        } else {
            title =
                "Filter \(fieldTitle)…"

            symbolName =
                "magnifyingglass"

            accessibilityValue =
                "No \(fieldTitle) filter"

            toolTip =
                "Capture a physical key to filter rules by \(fieldTitle). Modifiers are ignored."
        }

        captureButton.title =
            title

        captureButton.image =
            NSImage(
                systemSymbolName:
                    symbolName,
                accessibilityDescription:
                    "\(fieldTitle) filter"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: 11 * textScale,
                    weight: .regular
                )
            )

        captureButton.contentTintColor =
            filterKeyCode == nil
                ? .controlTextColor
                : .systemBlue

        captureButton.toolTip =
            toolTip

        captureButton.setAccessibilityLabel(
            "\(fieldTitle) filter"
        )

        captureButton.setAccessibilityValue(
            accessibilityValue
        )

        clearButton.isHidden =
            filterKeyCode == nil
                || isCapturing

        applyTextScale(
            textScale
        )
    }

    @objc
    private func captureButtonPressed() {
        onCaptureRequested?()
    }

    @objc
    private func clearButtonPressed() {
        onClearRequested?()
    }
}
