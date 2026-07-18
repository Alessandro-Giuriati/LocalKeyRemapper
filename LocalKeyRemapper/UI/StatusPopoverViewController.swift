//
//  StatusPopoverViewController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import AppKit

/// Displays the status-bar controls inside a lightweight AppKit popover.
///
/// The view controller contains only interface logic. It does not manage
/// keyboard events, remapping rules, permissions, or persistence.
@MainActor
final class StatusPopoverViewController:
    NSViewController
{
    private enum Layout {
        static let width: CGFloat = 300
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 12
        static let controlSpacing: CGFloat = 8
        static let buttonHeight: CGFloat = 30
    }

    private let primaryActionHandler:
        () -> Void

    private let openSettingsHandler:
        () -> Void

    private let increaseTextSizeHandler:
        () -> Void

    private let decreaseTextSizeHandler:
        () -> Void

    private let resetTextSizeHandler:
        () -> Void

    private let quitHandler:
        () -> Void

    private let stateLabel =
        NSTextField(
            labelWithString:
                "Remapping: Off"
        )

    private let primaryActionButton =
        NSButton(
            title:
                "Enable Remapping",
            target:
                nil,
            action:
                nil
        )

    init(
        primaryActionHandler:
            @escaping () -> Void,
        openSettingsHandler:
            @escaping () -> Void,
        increaseTextSizeHandler:
            @escaping () -> Void,
        decreaseTextSizeHandler:
            @escaping () -> Void,
        resetTextSizeHandler:
            @escaping () -> Void,
        quitHandler:
            @escaping () -> Void
    ) {
        self.primaryActionHandler =
            primaryActionHandler

        self.openSettingsHandler =
            openSettingsHandler

        self.increaseTextSizeHandler =
            increaseTextSizeHandler

        self.decreaseTextSizeHandler =
            decreaseTextSizeHandler

        self.resetTextSizeHandler =
            resetTextSizeHandler

        self.quitHandler =
            quitHandler

        super.init(
            nibName: nil,
            bundle: nil
        )

        preferredContentSize =
            NSSize(
                width: Layout.width,
                height: 226
            )
    }

    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func loadView() {
        let rootView = NSView()

        view = rootView

        configureInterface()
    }

    /// Updates the visible controls from the real backend state.
    func update(
        for state:
            RemappingState
    ) {
        switch state {
        case .disabled:
            stateLabel.stringValue =
                "Remapping: Off"

            primaryActionButton.title =
                "Enable Remapping"

            primaryActionButton.isEnabled =
                true

        case .enabling:
            stateLabel.stringValue =
                "Remapping: Enabling…"

            primaryActionButton.title =
                "Cancel"

            primaryActionButton.isEnabled =
                true

        case .enabled:
            stateLabel.stringValue =
                "Remapping: On"

            primaryActionButton.title =
                "Disable Remapping"

            primaryActionButton.isEnabled =
                true

        case .permissionRequired:
            stateLabel.stringValue =
                "Accessibility Permission Required"

            primaryActionButton.title =
                "Open Accessibility Settings…"

            primaryActionButton.isEnabled =
                true

        case .failed(let failure):
            updateForFailure(
                failure
            )
        }
    }

    private func configureInterface() {
        stateLabel.font =
            NSFont.systemFont(
                ofSize: 13,
                weight: .semibold
            )

        stateLabel.lineBreakMode =
            .byTruncatingTail

        primaryActionButton.target =
            self

        primaryActionButton.action =
            #selector(
                performPrimaryAction
            )

        primaryActionButton.bezelStyle =
            .rounded

        let settingsButton =
            makeFullWidthButton(
                title:
                    "Settings…",
                action:
                    #selector(openSettings)
            )

        let textSizeRow =
            makeTextSizeRow()

        let quitButton =
            makeFullWidthButton(
                title:
                    "Quit LocalKeyRemapper",
                action:
                    #selector(quitApplication)
            )

        let firstSeparator =
            makeSeparator()

        let secondSeparator =
            makeSeparator()

        let stack =
            NSStackView(
                views: [
                    stateLabel,
                    primaryActionButton,
                    firstSeparator,
                    settingsButton,
                    textSizeRow,
                    secondSeparator,
                    quitButton
                ]
            )

        stack.orientation =
            .vertical

        stack.alignment =
            .leading

        stack.spacing =
            Layout.controlSpacing

        stack.translatesAutoresizingMaskIntoConstraints =
            false

        view.addSubview(
            stack
        )

        for fullWidthView in [
            primaryActionButton,
            firstSeparator,
            settingsButton,
            textSizeRow,
            secondSeparator,
            quitButton
        ] {
            fullWidthView.translatesAutoresizingMaskIntoConstraints =
                false

            fullWidthView.widthAnchor
                .constraint(
                    equalTo:
                        stack.widthAnchor
                )
                .isActive = true
        }

        primaryActionButton.heightAnchor
            .constraint(
                equalToConstant:
                    Layout.buttonHeight
            )
            .isActive = true

        settingsButton.heightAnchor
            .constraint(
                equalToConstant:
                    Layout.buttonHeight
            )
            .isActive = true

        quitButton.heightAnchor
            .constraint(
                equalToConstant:
                    Layout.buttonHeight
            )
            .isActive = true

        NSLayoutConstraint.activate(
            [
                stack.leadingAnchor.constraint(
                    equalTo:
                        view.leadingAnchor,
                    constant:
                        Layout.horizontalPadding
                ),
                stack.trailingAnchor.constraint(
                    equalTo:
                        view.trailingAnchor,
                    constant:
                        -Layout.horizontalPadding
                ),
                stack.topAnchor.constraint(
                    equalTo:
                        view.topAnchor,
                    constant:
                        Layout.verticalPadding
                ),
                stack.bottomAnchor.constraint(
                    lessThanOrEqualTo:
                        view.bottomAnchor,
                    constant:
                        -Layout.verticalPadding
                ),
                view.widthAnchor.constraint(
                    equalToConstant:
                        Layout.width
                )
            ]
        )
    }

    private func makeFullWidthButton(
        title:
            String,
        action:
            Selector
    ) -> NSButton {
        let button =
            NSButton(
                title:
                    title,
                target:
                    self,
                action:
                    action
            )

        button.bezelStyle =
            .rounded

        button.alignment =
            .left

        return button
    }

    private func makeTextSizeRow()
        -> NSView
    {
        let container = NSView()

        let titleLabel =
            NSTextField(
                labelWithString:
                    "Text Size"
            )

        let decreaseButton =
            NSButton(
                title:
                    "−",
                target:
                    self,
                action:
                    #selector(
                        decreaseTextSize
                    )
            )

        let resetButton =
            NSButton(
                title:
                    "Reset",
                target:
                    self,
                action:
                    #selector(
                        resetTextSize
                    )
            )

        let increaseButton =
            NSButton(
                title:
                    "+",
                target:
                    self,
                action:
                    #selector(
                        increaseTextSize
                    )
            )

        for button in [
            decreaseButton,
            resetButton,
            increaseButton
        ] {
            button.bezelStyle =
                .rounded

            button.controlSize =
                .small
        }

        let controlsStack =
            NSStackView(
                views: [
                    decreaseButton,
                    resetButton,
                    increaseButton
                ]
            )

        controlsStack.orientation =
            .horizontal

        controlsStack.spacing =
            6

        titleLabel.translatesAutoresizingMaskIntoConstraints =
            false

        controlsStack.translatesAutoresizingMaskIntoConstraints =
            false

        container.addSubview(
            titleLabel
        )

        container.addSubview(
            controlsStack
        )

        NSLayoutConstraint.activate(
            [
                titleLabel.leadingAnchor.constraint(
                    equalTo:
                        container.leadingAnchor
                ),
                titleLabel.centerYAnchor.constraint(
                    equalTo:
                        container.centerYAnchor
                ),
                controlsStack.trailingAnchor.constraint(
                    equalTo:
                        container.trailingAnchor
                ),
                controlsStack.topAnchor.constraint(
                    equalTo:
                        container.topAnchor
                ),
                controlsStack.bottomAnchor.constraint(
                    equalTo:
                        container.bottomAnchor
                ),
                titleLabel.trailingAnchor.constraint(
                    lessThanOrEqualTo:
                        controlsStack.leadingAnchor,
                    constant:
                        -Layout.controlSpacing
                )
            ]
        )

        return container
    }

    private func makeSeparator()
        -> NSBox
    {
        let separator = NSBox()

        separator.boxType =
            .separator

        return separator
    }

    private func updateForFailure(
        _ failure:
            RemappingFailure
    ) {
        switch failure {
        case .rulesLoadingFailed:
            stateLabel.stringValue =
                "Error: Rules Could Not Load"

        case .invalidRules:
            stateLabel.stringValue =
                "Error: Invalid Remapping Rules"

        case .eventTapStartFailed:
            stateLabel.stringValue =
                "Error: Event Tap Could Not Start"
        }

        primaryActionButton.title =
            "Try Again"

        primaryActionButton.isEnabled =
            true
    }

    @objc
    private func performPrimaryAction() {
        primaryActionHandler()
    }

    @objc
    private func openSettings() {
        openSettingsHandler()
    }

    @objc
    private func increaseTextSize() {
        increaseTextSizeHandler()
    }

    @objc
    private func decreaseTextSize() {
        decreaseTextSizeHandler()
    }

    @objc
    private func resetTextSize() {
        resetTextSizeHandler()
    }

    @objc
    private func quitApplication() {
        quitHandler()
    }
}
