//
//  StatusPopoverViewController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import AppKit

/// One profile displayed by the lightweight menu-bar popover.
///
/// Identity uses the stable profile UUID. The editable name is presentation
/// only and is never used to select or persist a profile.
nonisolated struct StatusPopoverProfileItem:
    Equatable
{
    let id:
        UUID

    let name:
        String

    /// Allows the provider to disable a profile defensively when it is not
    /// available for runtime activation.
    let isActivatable:
        Bool
}

/// Complete profile-selection state displayed by the status popover.
nonisolated struct StatusPopoverProfilesSnapshot:
    Equatable
{
    let profiles:
        [StatusPopoverProfileItem]

    let activeProfileID:
        UUID?

    static let unavailable =
        StatusPopoverProfilesSnapshot(
            profiles: [],
            activeProfileID: nil
        )
}

/// Displays the status-bar controls inside a lightweight AppKit popover.
///
/// The view controller contains only interface logic. It does not manage
/// keyboard events, remapping rules, permissions, shortcuts, or persistence.
@MainActor
final class StatusPopoverViewController:
    NSViewController
{
    private enum Layout {
        static let width:
            CGFloat = 300

        static let horizontalPadding:
            CGFloat = 16

        static let verticalPadding:
            CGFloat = 14

        static let controlSpacing:
            CGFloat = 8

        static let buttonHeight:
            CGFloat = 30

        static let profileControlHeight:
            CGFloat = 26
    }

    private let primaryActionHandler:
        () -> Void

    private let activeProfileSelectionHandler:
        (UUID) -> Void

    private let openMainWindowHandler:
        () -> Void

    private let increaseTextSizeHandler:
        () -> Void

    private let decreaseTextSizeHandler:
        () -> Void

    private let resetTextSizeHandler:
        () -> Void

    private let quitHandler:
        () -> Void

    private var isUpdatingProfiles =
        false

    /// Stores the newest authoritative profile snapshot even before AppKit
    /// lazily loads the popover view for the first time.
    private var latestProfilesSnapshot =
        StatusPopoverProfilesSnapshot.unavailable

    private let stateLabel =
        NSTextField(
            labelWithString:
                "Remapping: Off"
        )

    private let activeProfileLabel =
        NSTextField(
            labelWithString:
                "Active Profile"
        )

    private let activeProfilePopUpButton =
        NSPopUpButton(
            frame:
                .zero,
            pullsDown:
                false
        )

    private let profileStatusLabel =
        NSTextField(
            wrappingLabelWithString:
                ""
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
        activeProfileSelectionHandler:
            @escaping (UUID) -> Void = {
                _ in
            },
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

        self.activeProfileSelectionHandler =
            activeProfileSelectionHandler

        self.openMainWindowHandler =
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
                width:
                    Layout.width,
                height:
                    318
            )
    }

    @available(*, unavailable)
    required init?(
        coder:
            NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func loadView() {
        let rootView =
            NSView()

        view =
            rootView

        configureInterface()
        applyProfilesSnapshot(
            latestProfilesSnapshot
        )
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

        case .failed(
            let failure
        ):
            updateForFailure(
                failure
            )
        }
    }

    /// Rebuilds the profile menu from one authoritative snapshot.
    ///
    /// Menu items carry UUID strings as represented objects. Profile names are
    /// never used as identity, so renaming and duplicate-looking draft names
    /// cannot activate the wrong profile.
    func updateProfiles(
        _ snapshot:
            StatusPopoverProfilesSnapshot
    ) {
        latestProfilesSnapshot =
            snapshot

        // AppKit creates popover content lazily. Keep the snapshot now and
        // render it from loadView() when the view does not exist yet.
        guard isViewLoaded else {
            return
        }

        applyProfilesSnapshot(
            snapshot
        )
    }

    private func applyProfilesSnapshot(
        _ snapshot:
            StatusPopoverProfilesSnapshot
    ) {
        isUpdatingProfiles =
            true

        defer {
            isUpdatingProfiles =
                false
        }

        activeProfilePopUpButton
            .removeAllItems()

        guard
            !snapshot
                .profiles
                .isEmpty
        else {
            let unavailableItem =
                NSMenuItem(
                    title:
                        "Profiles Unavailable",
                    action:
                        nil,
                    keyEquivalent:
                        ""
                )

            unavailableItem.isEnabled =
                false

            activeProfilePopUpButton
                .menu?
                .addItem(
                    unavailableItem
                )

            activeProfilePopUpButton
                .isEnabled =
                    false

            return
        }

        for profile in snapshot.profiles {
            let item =
                NSMenuItem(
                    title:
                        profile.name,
                    action:
                        nil,
                    keyEquivalent:
                        ""
                )

            item.representedObject =
                profile
                    .id
                    .uuidString

            item.isEnabled =
                profile
                    .isActivatable

            item.toolTip =
                profile.isActivatable
                    ? "Activate “\(profile.name)” immediately."
                    : "Save “\(profile.name)” in Home before activating it."

            activeProfilePopUpButton
                .menu?
                .addItem(
                    item
                )
        }

        if
            let activeProfileID =
                snapshot.activeProfileID,
            let activeIndex =
                snapshot
                    .profiles
                    .firstIndex(
                        where: {
                            $0.id
                                == activeProfileID
                        }
                    )
        {
            activeProfilePopUpButton
                .selectItem(
                    at:
                        activeIndex
                )
        } else {
            activeProfilePopUpButton
                .selectItem(
                    at:
                        0
                )
        }

        let activatableProfileCount =
            snapshot
                .profiles
                .filter(
                    \.isActivatable
                )
                .count

        activeProfilePopUpButton
            .isEnabled =
                activatableProfileCount > 1

        activeProfilePopUpButton.toolTip =
            activatableProfileCount > 1
                ? "Select the active remapping profile."
                : "No other saved profile is available."
    }

    func showProfileSelectionFailure() {
        profileStatusLabel.stringValue =
            "The profile could not be activated. The previous profile remains active."

        profileStatusLabel.textColor =
            .systemRed

        profileStatusLabel.isHidden =
            false
    }

    func showProfilesLoadingFailure() {
        updateProfiles(
            .unavailable
        )

        profileStatusLabel.stringValue =
            "The profiles could not be loaded."

        profileStatusLabel.textColor =
            .systemRed

        profileStatusLabel.isHidden =
            false
    }

    func clearProfileStatus() {
        profileStatusLabel.stringValue =
            ""

        profileStatusLabel.isHidden =
            true
    }

    private func configureInterface() {
        stateLabel.font =
            NSFont.systemFont(
                ofSize:
                    13,
                weight:
                    .semibold
            )

        stateLabel.lineBreakMode =
            .byTruncatingTail

        activeProfileLabel.font =
            NSFont.systemFont(
                ofSize:
                    12,
                weight:
                    .semibold
            )

        activeProfilePopUpButton.target =
            self

        activeProfilePopUpButton.action =
            #selector(
                activeProfileChanged
            )

        activeProfilePopUpButton
            .setAccessibilityLabel(
                "Active remapping profile"
            )

        profileStatusLabel.font =
            NSFont.systemFont(
                ofSize:
                    11,
                weight:
                    .regular
            )

        profileStatusLabel.maximumNumberOfLines =
            2

        profileStatusLabel.isHidden =
            true

        primaryActionButton.target =
            self

        primaryActionButton.action =
            #selector(
                performPrimaryAction
            )

        primaryActionButton.bezelStyle =
            .rounded

        let openMainWindowButton =
            makeFullWidthButton(
                title:
                    "Open LocalKeyRemapper",
                action:
                    #selector(
                        openMainWindow
                    )
            )

        let textSizeRow =
            makeTextSizeRow()

        let quitButton =
            makeFullWidthButton(
                title:
                    "Quit LocalKeyRemapper",
                action:
                    #selector(
                        quitApplication
                    )
            )

        let firstSeparator =
            makeSeparator()

        let secondSeparator =
            makeSeparator()

        let stack =
            NSStackView(
                views: [
                    stateLabel,
                    activeProfileLabel,
                    activeProfilePopUpButton,
                    profileStatusLabel,
                    primaryActionButton,
                    firstSeparator,
                    openMainWindowButton,
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
            activeProfilePopUpButton,
            profileStatusLabel,
            primaryActionButton,
            firstSeparator,
            openMainWindowButton,
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
                .isActive =
                    true
        }

        activeProfilePopUpButton
            .heightAnchor
            .constraint(
                equalToConstant:
                    Layout
                        .profileControlHeight
            )
            .isActive =
                true

        primaryActionButton
            .heightAnchor
            .constraint(
                equalToConstant:
                    Layout.buttonHeight
            )
            .isActive =
                true

        openMainWindowButton
            .heightAnchor
            .constraint(
                equalToConstant:
                    Layout.buttonHeight
            )
            .isActive =
                true

        quitButton
            .heightAnchor
            .constraint(
                equalToConstant:
                    Layout.buttonHeight
            )
            .isActive =
                true

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
        let container =
            NSView()

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
        let separator =
            NSBox()

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
    private func activeProfileChanged() {
        guard
            !isUpdatingProfiles,
            let representedObject =
                activeProfilePopUpButton
                    .selectedItem?
                    .representedObject
                    as? String,
            let profileID =
                UUID(
                    uuidString:
                        representedObject
                )
        else {
            return
        }

        clearProfileStatus()

        activeProfileSelectionHandler(
            profileID
        )
    }

    @objc
    private func performPrimaryAction() {
        primaryActionHandler()
    }

    @objc
    private func openMainWindow() {
        openMainWindowHandler()
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
