//
//  MainWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A main application window that intercepts a key press only while
/// the user is explicitly selecting a key or global shortcut.
///
/// The handler receives events only from this window.
/// It is not a global keyboard monitor.
@MainActor
private final class MainWindow: NSWindow {
    var keyDownHandler: ((NSEvent) -> Bool)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           keyDownHandler?(event) == true {
            return
        }

        super.sendEvent(event)
    }
}

/// Keeps scrollable rule content anchored to the top-left corner.
@MainActor
private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

/// Manages application settings, remapping rules, launch behavior,
/// and global shortcut configuration.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private enum TextSizePreference {
        static let storageKey = "settingsTextScale.v1"
        static let defaultScale: CGFloat = 1.0
        static let minimumScale: CGFloat = 0.8
        static let maximumScale: CGFloat = 1.4
        static let step: CGFloat = 0.1
    }

    private enum EditorValidationIssue {
        case incompleteRule
        case duplicateSource
        case identicalSourceAndDestination

        var message: String {
            switch self {
            case .incompleteRule:
                return "Complete every highlighted rule before saving."
            case .duplicateSource:
                return "Each exact source combination and each Preserve Modifiers source key can appear only once."
            case .identicalSourceAndDestination:
                return "A source and destination key cannot be identical."
            }
        }
    }

    private struct ValidationSnapshot {
        let issue: EditorValidationIssue?
        let invalidRows: Set<ObjectIdentifier>
    }

    private let remappingController: RemappingSettingsControlling
    private let appPreferencesController: AppPreferencesControlling
    private let globalShortcutController: GlobalShortcutController
    private let menuBarVisibilityChangeHandler: (Bool) throws -> Void
    private let openAccessibilitySettingsHandler: () -> Void
    private let globalShortcutSettingsView: GlobalShortcutSettingsView
    private let ruleRemovalConfirmationController =
        RuleRemovalConfirmationController()

    /// The application controller implements both the settings and runtime
    /// remapping interfaces. Keeping the cast here avoids widening the
    /// settings-only protocol used by tests and other UI components.
    private var remappingRuntimeController: RemappingControlling? {
        remappingController as? RemappingControlling
    }

    private let titleLabel = NSTextField(
        labelWithString: "Remapping Rules"
    )

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Record complete combinations, choose how modifiers behave, and add exact exceptions when needed."
    )

    private let sourceHeader = NSTextField(
        labelWithString: "Source"
    )

    private let destinationHeader = NSTextField(
        labelWithString: "Destination"
    )

    private let behaviorHeader = NSTextField(
        labelWithString: "Modifier behavior"
    )

    private let exceptionsHeader = NSTextField(
        labelWithString: "Exceptions"
    )

    private let launchBehaviorTitleLabel = NSTextField(
        labelWithString: "Remapping at launch"
    )

    private let launchBehaviorDescriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Choose how remapping should behave when LocalKeyRemapper starts."
    )

    private let launchBehaviorControl = NSSegmentedControl(
        labels: [
            "Always Off",
            "Restore Last State",
            "Always On"
        ],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private let launchBehaviorStack = NSStackView()

    private let confirmRuleRemovalCheckbox = NSButton(
        checkboxWithTitle: "Confirm before removing rules",
        target: nil,
        action: nil
    )

    private let rulesScrollView = NSScrollView()
    private let rulesDocumentView = FlippedView()
    private let rulesStackView = NSStackView()
    private let addRuleButton = NSButton()
    private let saveButton = NSButton()
    private let actionsStack = NSStackView()

    private let remappingLabel = NSTextField(
        labelWithString: "Remapping"
    )

    private let remappingSwitch = NSSwitch()

    private let accessibilityPermissionLabel = NSTextField(
        labelWithString: "Accessibility Permission Required"
    )

    private let openAccessibilitySettingsButton = NSButton()
    private let accessibilityPermissionStack = NSStackView()

    private let textSizeLabel = NSTextField(
        labelWithString: "Text size"
    )

    private let decreaseTextSizeButton = NSButton()
    private let resetTextSizeButton = NSButton()
    private let increaseTextSizeButton = NSButton()

    private let mainStack = NSStackView()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private let showMenuBarIconCheckbox = NSButton(
        checkboxWithTitle: "Show icon in menu bar",
        target: nil,
        action: nil
    )

    private var ruleRows: [RemappingRuleRowView] = []

    /// Last rule collection successfully loaded or saved.
    private var savedRules: [RemapRule] = []

    private var captureRow: RemappingRuleRowView?
    private var captureField: RemappingRuleRowView.KeyField?
    private var shortcutCaptureField: GlobalShortcutSettingsView.CaptureField?
    private var exceptionsWindowController: RemapOverridesWindowController?
    private var textScale: CGFloat

    init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        menuBarVisibilityChangeHandler: @escaping (Bool) throws -> Void,
        openAccessibilitySettingsHandler: @escaping () -> Void = {}
    ) {
        self.remappingController = remappingController
        self.appPreferencesController = appPreferencesController
        self.globalShortcutController = globalShortcutController
        self.menuBarVisibilityChangeHandler = menuBarVisibilityChangeHandler
        self.openAccessibilitySettingsHandler =
            openAccessibilitySettingsHandler

        globalShortcutSettingsView = GlobalShortcutSettingsView(
            configuration:
                appPreferencesController
                    .preferences
                    .shortcutConfiguration
        )

        let storedScale = UserDefaults.standard.double(
            forKey: TextSizePreference.storageKey
        )

        if storedScale == 0 {
            textScale = TextSizePreference.defaultScale
        } else {
            textScale = Self.clampedTextScale(
                CGFloat(storedScale)
            )
        }

        let window = MainWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 1080,
                height: 780
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "LocalKeyRemapper"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(
            width: 960,
            height: 680
        )
        window.contentMaxSize = NSSize(
            width: 1280,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.center()

        super.init(window: window)

        window.delegate = self
        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureShortcutSettingsCallbacks()
        configureContent()
        synchronizeLaunchBehavior()
        synchronizeRuleRemovalConfirmationPreference()
        synchronizeMenuBarIconVisibility()
        updateRemappingState(
            remappingRuntimeController?.state ?? .disabled
        )
        applyTextScale()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible == false {
            synchronizeLaunchBehavior()
            synchronizeRuleRemovalConfirmationPreference()
            synchronizeMenuBarIconVisibility()
            updateRemappingState(
                remappingRuntimeController?.state ?? .disabled
            )

            globalShortcutSettingsView.load(
                configuration:
                    appPreferencesController
                        .preferences
                        .shortcutConfiguration
            )

            loadConfiguredRules()
        }

        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
    }

    /// Ends local capture before application-level system components stop.
    func prepareForApplicationTermination() {
        endKeyCapture()
        exceptionsWindowController?.close()
        exceptionsWindowController = nil
    }

    /// Increases the Settings interface text size.
    func increaseTextSize() {
        setTextScale(
            textScale + TextSizePreference.step
        )
    }

    /// Decreases the Settings interface text size.
    func decreaseTextSize() {
        setTextScale(
            textScale - TextSizePreference.step
        )
    }

    /// Restores the default Settings interface text size.
    func resetTextSize() {
        setTextScale(
            TextSizePreference.defaultScale
        )
    }

    /// Updates the controls to reflect the real backend state.
    func updateRemappingState(_ state: RemappingState) {
        let canControlRemapping = remappingRuntimeController != nil

        switch state {
        case .disabled:
            remappingSwitch.state = .off
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = true

        case .enabling:
            remappingSwitch.state = .on
            remappingSwitch.isEnabled = false
            accessibilityPermissionStack.isHidden = true

        case .enabled:
            remappingSwitch.state = .on
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = true

        case .permissionRequired:
            remappingSwitch.state = .off
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = false

        case .failed:
            remappingSwitch.state = .off
            remappingSwitch.isEnabled = canControlRemapping
            accessibilityPermissionStack.isHidden = true
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        endKeyCapture()

        let hasRuleChanges = hasUnsavedRuleChanges
        let hasShortcutChanges =
            globalShortcutSettingsView.hasUnsavedChanges

        guard hasRuleChanges || hasShortcutChanges else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Save changes before closing?"

        switch (hasRuleChanges, hasShortcutChanges) {
        case (true, true):
            alert.informativeText =
                "Your remapping rules and global shortcut settings have been modified."

        case (true, false):
            alert.informativeText =
                "Your remapping rules have been modified."

        case (false, true):
            alert.informativeText =
                "Your global shortcut settings have been modified."

        case (false, false):
            alert.informativeText = ""
        }

        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let rulesSaved =
                !hasRuleChanges || persistRules()
            let shortcutsSaved =
                !hasShortcutChanges
                || globalShortcutSettingsView.persistConfiguration()

            return rulesSaved && shortcutsSaved

        case .alertSecondButtonReturn:
            if hasRuleChanges {
                loadConfiguredRules()
            }

            if hasShortcutChanges {
                globalShortcutSettingsView.discardChanges()
            }

            return true

        default:
            return false
        }
    }

    func windowWillClose(_ notification: Notification) {
        endKeyCapture()
        exceptionsWindowController = nil
    }

    private func configureShortcutSettingsCallbacks() {
        globalShortcutSettingsView.onCaptureRequested = {
            [weak self] field in

            self?.beginShortcutCapture(field)
        }

        globalShortcutSettingsView.onCaptureCancellationRequested = {
            [weak self] in

            self?.endKeyCapture()
        }

        globalShortcutSettingsView.onSaveRequested = {
            [weak self] configuration in

            guard let self else {
                return
            }

            try self.globalShortcutController.setConfiguration(
                configuration
            )
        }
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        descriptionLabel.textColor = .secondaryLabelColor
        sourceHeader.textColor = .secondaryLabelColor
        destinationHeader.textColor = .secondaryLabelColor
        behaviorHeader.textColor = .secondaryLabelColor
        exceptionsHeader.textColor = .secondaryLabelColor
        launchBehaviorDescriptionLabel.textColor = .secondaryLabelColor

        configureLaunchBehavior()
        configureRuleRemovalConfirmationPreference()
        configureMenuBarVisibilityPreference()
        configureRulesScrollView()
        configureActionButtons()
        configureRemappingControl()
        configureAccessibilityPermissionNotice()
        configureTextSizeControls()

        actionsStack.setViews(
            [
                addRuleButton,
                saveButton
            ],
            in: .leading
        )

        actionsStack.setViews(
            [
                remappingLabel,
                remappingSwitch,
                textSizeLabel,
                decreaseTextSizeButton,
                resetTextSizeButton,
                increaseTextSizeButton
            ],
            in: .trailing
        )

        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.distribution = .fill
        actionsStack.translatesAutoresizingMaskIntoConstraints = false

        let rulesHeaderView = makeRulesHeaderView()

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                launchBehaviorStack,
                globalShortcutSettingsView,
                confirmRuleRemovalCheckbox,
                rulesHeaderView,
                rulesScrollView,
                actionsStack,
                accessibilityPermissionStack,
                statusLabel,
                showMenuBarIconCheckbox
            ],
            in: .leading
        )

        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        globalShortcutSettingsView.translatesAutoresizingMaskIntoConstraints =
            false

        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate(
            [
                mainStack.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: 28
                ),
                mainStack.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 28
                ),
                mainStack.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -28
                ),
                mainStack.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -28
                ),
                rulesHeaderView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                rulesScrollView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                actionsStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                launchBehaviorStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                globalShortcutSettingsView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                )
            ]
        )
    }

    private func makeRulesHeaderView() -> NSView {
        let headerView = NSView()
        let arrowSpacer = NSView()
        let removeSpacer = NSView()

        let views: [NSView] = [
            sourceHeader,
            arrowSpacer,
            destinationHeader,
            behaviorHeader,
            exceptionsHeader,
            removeSpacer
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(view)
        }

        headerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(
            [
                sourceHeader.leadingAnchor.constraint(
                    equalTo: headerView.leadingAnchor,
                    constant: 18
                ),
                sourceHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                sourceHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),
                arrowSpacer.leadingAnchor.constraint(
                    equalTo: sourceHeader.trailingAnchor,
                    constant: 10
                ),
                arrowSpacer.widthAnchor.constraint(
                    equalToConstant: 18
                ),
                destinationHeader.leadingAnchor.constraint(
                    equalTo: arrowSpacer.trailingAnchor,
                    constant: 10
                ),
                destinationHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                destinationHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),
                behaviorHeader.leadingAnchor.constraint(
                    equalTo: destinationHeader.trailingAnchor,
                    constant: 10
                ),
                behaviorHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                behaviorHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),
                behaviorHeader.widthAnchor.constraint(
                    equalToConstant: 168
                ),
                exceptionsHeader.leadingAnchor.constraint(
                    equalTo: behaviorHeader.trailingAnchor,
                    constant: 10
                ),
                exceptionsHeader.topAnchor.constraint(
                    equalTo: headerView.topAnchor
                ),
                exceptionsHeader.bottomAnchor.constraint(
                    equalTo: headerView.bottomAnchor
                ),
                exceptionsHeader.widthAnchor.constraint(
                    equalToConstant: 116
                ),
                removeSpacer.leadingAnchor.constraint(
                    equalTo: exceptionsHeader.trailingAnchor,
                    constant: 10
                ),
                removeSpacer.trailingAnchor.constraint(
                    equalTo: headerView.trailingAnchor,
                    constant: -18
                ),
                removeSpacer.widthAnchor.constraint(
                    equalToConstant: 82
                ),
                sourceHeader.widthAnchor.constraint(
                    equalTo: destinationHeader.widthAnchor
                ),
                sourceHeader.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 120
                ),
                headerView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 20
                )
            ]
        )

        return headerView
    }

    private func configureMenuBarVisibilityPreference() {
        showMenuBarIconCheckbox.target = self
        showMenuBarIconCheckbox.action = #selector(
            menuBarIconVisibilityChanged
        )
        showMenuBarIconCheckbox.toolTip =
            "Show or hide the optional LocalKeyRemapper menu bar icon."
        showMenuBarIconCheckbox.setContentHuggingPriority(
            .required,
            for: .vertical
        )
    }

    /// Updates the checkbox when the preference changes elsewhere,
    /// such as from the application's native menu.
    func updateMenuBarIconVisibility(_ showsMenuBarIcon: Bool) {
        showMenuBarIconCheckbox.state =
            showsMenuBarIcon ? .on : .off
    }

    private func synchronizeMenuBarIconVisibility() {
        updateMenuBarIconVisibility(
            appPreferencesController.preferences.showsMenuBarIcon
        )
    }

    @objc
    private func menuBarIconVisibilityChanged() {
        let previousVisibility =
            appPreferencesController.preferences.showsMenuBarIcon
        let requestedVisibility =
            showMenuBarIconCheckbox.state == .on

        do {
            try menuBarVisibilityChangeHandler(
                requestedVisibility
            )
        } catch {
            updateMenuBarIconVisibility(
                previousVisibility
            )
            setStatus(
                "The menu bar preference could not be saved.",
                isError: true
            )
        }
    }

    private func configureRuleRemovalConfirmationPreference() {
        confirmRuleRemovalCheckbox.target = self
        confirmRuleRemovalCheckbox.action = #selector(
            ruleRemovalConfirmationPreferenceChanged
        )
        confirmRuleRemovalCheckbox.toolTip =
            "Ask for confirmation before removing a remapping rule."
        confirmRuleRemovalCheckbox.setContentHuggingPriority(
            .required,
            for: .vertical
        )
    }

    private func synchronizeRuleRemovalConfirmationPreference() {
        confirmRuleRemovalCheckbox.state =
            appPreferencesController.preferences.confirmsRuleRemoval
                ? .on
                : .off
    }

    @objc
    private func ruleRemovalConfirmationPreferenceChanged() {
        let previousValue =
            appPreferencesController.preferences.confirmsRuleRemoval
        let requestedValue =
            confirmRuleRemovalCheckbox.state == .on

        guard ruleRemovalConfirmationController
            .shouldApplyPreferenceChange(
                from: previousValue,
                to: requestedValue
            ) else {
            synchronizeRuleRemovalConfirmationPreference()
            return
        }

        do {
            try appPreferencesController.setConfirmsRuleRemoval(
                requestedValue
            )
        } catch {
            synchronizeRuleRemovalConfirmationPreference()
            setStatus(
                "The rule removal confirmation preference could not be saved.",
                isError: true
            )
        }
    }

    private func configureLaunchBehavior() {
        launchBehaviorTitleLabel.setContentHuggingPriority(
            .required,
            for: .vertical
        )
        launchBehaviorDescriptionLabel.setContentHuggingPriority(
            .required,
            for: .vertical
        )

        launchBehaviorControl.segmentStyle = .rounded
        launchBehaviorControl.target = self
        launchBehaviorControl.action = #selector(
            launchBehaviorChanged
        )
        launchBehaviorControl.toolTip =
            "Choose whether remapping starts off, restores its last state, or starts on."

        launchBehaviorStack.setViews(
            [
                launchBehaviorTitleLabel,
                launchBehaviorDescriptionLabel,
                launchBehaviorControl
            ],
            in: .leading
        )
        launchBehaviorStack.orientation = .vertical
        launchBehaviorStack.alignment = .leading
        launchBehaviorStack.spacing = 6

        launchBehaviorControl.translatesAutoresizingMaskIntoConstraints =
            false
        launchBehaviorControl.widthAnchor.constraint(
            equalTo: launchBehaviorStack.widthAnchor
        ).isActive = true
    }

    private func synchronizeLaunchBehavior() {
        launchBehaviorControl.selectedSegment = segmentIndex(
            for: appPreferencesController.preferences.launchBehavior
        )
    }

    @objc
    private func launchBehaviorChanged() {
        let previousBehavior =
            appPreferencesController.preferences.launchBehavior

        guard let requestedBehavior = launchBehavior(
            for: launchBehaviorControl.selectedSegment
        ) else {
            synchronizeLaunchBehavior()
            return
        }

        do {
            try appPreferencesController.setLaunchBehavior(
                requestedBehavior
            )
            refreshChangeState()
        } catch {
            launchBehaviorControl.selectedSegment = segmentIndex(
                for: previousBehavior
            )
            setStatus(
                "The launch behavior could not be saved.",
                isError: true
            )
        }
    }

    private func segmentIndex(
        for launchBehavior: RemappingLaunchBehavior
    ) -> Int {
        switch launchBehavior {
        case .alwaysOff:
            return 0
        case .restoreLastState:
            return 1
        case .alwaysOn:
            return 2
        }
    }

    private func launchBehavior(
        for segmentIndex: Int
    ) -> RemappingLaunchBehavior? {
        switch segmentIndex {
        case 0:
            return .alwaysOff
        case 1:
            return .restoreLastState
        case 2:
            return .alwaysOn
        default:
            return nil
        }
    }

    private func configureActionButtons() {
        addRuleButton.title = "Add Rule"
        addRuleButton.image = NSImage(
            systemSymbolName: "plus",
            accessibilityDescription: "Add Rule"
        )
        addRuleButton.imagePosition = .imageLeading
        addRuleButton.bezelStyle = .rounded
        addRuleButton.target = self
        addRuleButton.action = #selector(addEmptyRule)

        saveButton.title = "Save Rules"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveRules)
    }

    private func configureRemappingControl() {
        remappingLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        remappingSwitch.target = self
        remappingSwitch.action = #selector(
            remappingSwitchChanged
        )
        remappingSwitch.toolTip =
            "Enable or disable keyboard remapping."
        remappingSwitch.setContentHuggingPriority(
            .required,
            for: .horizontal
        )
    }

    @objc
    private func remappingSwitchChanged() {
        guard let remappingRuntimeController else {
            updateRemappingState(.disabled)
            return
        }

        if remappingSwitch.state == .on {
            remappingRuntimeController.enable()
        } else {
            remappingRuntimeController.disable()
        }

        updateRemappingState(
            remappingRuntimeController.state
        )
    }

    private func configureAccessibilityPermissionNotice() {
        accessibilityPermissionLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        openAccessibilitySettingsButton.title =
            "Open Accessibility Settings…"
        openAccessibilitySettingsButton.bezelStyle = .rounded
        openAccessibilitySettingsButton.target = self
        openAccessibilitySettingsButton.action = #selector(
            openAccessibilitySettings
        )

        accessibilityPermissionStack.setViews(
            [
                accessibilityPermissionLabel,
                openAccessibilitySettingsButton
            ],
            in: .leading
        )
        accessibilityPermissionStack.orientation = .horizontal
        accessibilityPermissionStack.alignment = .centerY
        accessibilityPermissionStack.spacing = 8
        accessibilityPermissionStack.isHidden = true
    }

    @objc
    private func openAccessibilitySettings() {
        openAccessibilitySettingsHandler()
    }

    private func configureTextSizeControls() {
        textSizeLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        decreaseTextSizeButton.title = "−"
        decreaseTextSizeButton.bezelStyle = .rounded
        decreaseTextSizeButton.target = self
        decreaseTextSizeButton.action = #selector(
            decreaseTextSizeButtonPressed
        )
        decreaseTextSizeButton.toolTip =
            "Decrease Settings text size."

        resetTextSizeButton.title = "Reset"
        resetTextSizeButton.bezelStyle = .rounded
        resetTextSizeButton.target = self
        resetTextSizeButton.action = #selector(
            resetTextSizeButtonPressed
        )
        resetTextSizeButton.toolTip =
            "Restore the default Settings text size."

        increaseTextSizeButton.title = "+"
        increaseTextSizeButton.bezelStyle = .rounded
        increaseTextSizeButton.target = self
        increaseTextSizeButton.action = #selector(
            increaseTextSizeButtonPressed
        )
        increaseTextSizeButton.toolTip =
            "Increase Settings text size."

        for button in [
            decreaseTextSizeButton,
            resetTextSizeButton,
            increaseTextSizeButton
        ] {
            button.setContentHuggingPriority(
                .required,
                for: .horizontal
            )
        }
    }

    @objc
    private func decreaseTextSizeButtonPressed() {
        decreaseTextSize()
    }

    @objc
    private func resetTextSizeButtonPressed() {
        resetTextSize()
    }

    @objc
    private func increaseTextSizeButtonPressed() {
        increaseTextSize()
    }

    private func configureRulesScrollView() {
        rulesStackView.orientation = .vertical
        rulesStackView.alignment = .leading
        rulesStackView.distribution = .fill
        rulesStackView.translatesAutoresizingMaskIntoConstraints = false

        rulesDocumentView.translatesAutoresizingMaskIntoConstraints = false
        rulesDocumentView.addSubview(rulesStackView)

        rulesScrollView.hasVerticalScroller = true
        rulesScrollView.autohidesScrollers = true
        rulesScrollView.borderType = .bezelBorder
        rulesScrollView.drawsBackground = false
        rulesScrollView.documentView = rulesDocumentView
        rulesScrollView.translatesAutoresizingMaskIntoConstraints = false
        rulesScrollView.setContentHuggingPriority(
            .defaultLow,
            for: .vertical
        )
        rulesScrollView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .vertical
        )

        NSLayoutConstraint.activate(
            [
                rulesStackView.topAnchor.constraint(
                    equalTo: rulesDocumentView.topAnchor,
                    constant: 12
                ),
                rulesStackView.leadingAnchor.constraint(
                    equalTo: rulesDocumentView.leadingAnchor,
                    constant: 12
                ),
                rulesStackView.trailingAnchor.constraint(
                    equalTo: rulesDocumentView.trailingAnchor,
                    constant: -12
                ),
                rulesStackView.bottomAnchor.constraint(
                    equalTo: rulesDocumentView.bottomAnchor,
                    constant: -12
                ),
                rulesDocumentView.widthAnchor.constraint(
                    equalTo: rulesScrollView.contentView.widthAnchor
                ),
                rulesDocumentView.heightAnchor.constraint(
                    greaterThanOrEqualTo:
                        rulesScrollView.contentView.heightAnchor
                ),
                rulesScrollView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant: 140
                )
            ]
        )
    }

    private func loadConfiguredRules() {
        endKeyCapture()
        removeAllRuleRows()

        do {
            let rules = try remappingController.loadConfiguredRules()
            savedRules = rules

            for rule in rules {
                addRuleRow(
                    rule: rule,
                    scrollIntoView: false
                )
            }

            refreshChangeState()
        } catch {
            savedRules = []
            setStatus(
                "The configured rules could not be loaded.",
                isError: true
            )
            saveButton.isEnabled = false
        }
    }

    private func addRuleRow(
        rule: RemapRule? = nil,
        scrollIntoView: Bool = true
    ) {
        let row = RemappingRuleRowView(
            rule: rule
        )

        row.applyTextScale(textScale)

        row.onSourceKeyRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginRuleKeyCapture(
                in: row,
                field: .source
            )
        }

        row.onDestinationKeyRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.beginRuleKeyCapture(
                in: row,
                field: .destination
            )
        }

        row.onExceptionsRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.showExceptions(for: row)
        }

        row.onRemoveRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.requestRuleRemoval(row)
        }

        row.onRuleChanged = {
            [weak self] in

            self?.refreshChangeState()
        }

        ruleRows.append(row)
        rulesStackView.addArrangedSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(
            equalTo: rulesStackView.widthAnchor
        ).isActive = true

        refreshChangeState()

        if scrollIntoView {
            scrollToRuleRow(row)
        }
    }

    private func showExceptions(
        for row: RemappingRuleRowView
    ) {
        endKeyCapture()

        guard exceptionsWindowController == nil,
              let parentWindow = window,
              let rule = row.rule,
              rule.matchingMode == .preserveModifiers else {
            return
        }

        let controller = RemapOverridesWindowController(
            parentWindow: parentWindow,
            rule: rule,
            remappingController: remappingController,
            textScale: textScale,
            onSave: {
                [weak self, weak row] overrides in

                row?.setOverrides(overrides)
                self?.refreshChangeState()
            },
            onClose: {
                [weak self] in

                self?.exceptionsWindowController = nil
            }
        )

        exceptionsWindowController = controller
        controller.showAsSheet()
    }

    private func scrollToRuleRow(
        _ row: RemappingRuleRowView
    ) {
        rulesDocumentView.layoutSubtreeIfNeeded()
        rulesStackView.layoutSubtreeIfNeeded()

        let visibleRect = row.convert(
            row.bounds,
            to: rulesDocumentView
        )

        rulesDocumentView.scrollToVisible(
            visibleRect
        )
    }

    private func requestRuleRemoval(
        _ row: RemappingRuleRowView
    ) {
        let confirmationRequired =
            appPreferencesController
                .preferences
                .confirmsRuleRemoval

        guard ruleRemovalConfirmationController
            .shouldRemoveRule(
                confirmationRequired: confirmationRequired
            ) else {
            return
        }

        removeRuleRow(row)
    }

    private func removeRuleRow(
        _ row: RemappingRuleRowView
    ) {
        if captureRow === row {
            endKeyCapture()
        }

        guard let index = ruleRows.firstIndex(
            where: { $0 === row }
        ) else {
            return
        }

        ruleRows.remove(at: index)
        rulesStackView.removeArrangedSubview(row)
        row.removeFromSuperview()
        refreshChangeState()
    }

    private func removeAllRuleRows() {
        for row in ruleRows {
            rulesStackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        ruleRows.removeAll()
    }

    @objc
    private func addEmptyRule() {
        addRuleRow()
    }

    private func beginRuleKeyCapture(
        in row: RemappingRuleRowView,
        field: RemappingRuleRowView.KeyField
    ) {
        if captureRow === row,
           captureField == field {
            endKeyCapture()
            refreshChangeState()
            return
        }

        endKeyCapture()
        captureRow = row
        captureField = field
        beginCaptureSession()
        row.showCapturePrompt(for: field)

        if row.matchingMode == .preserveModifiers {
            setStatus(
                "Press a physical key. Modifiers are ignored in Preserve Modifiers mode. Click the same field again to cancel.",
                isError: false
            )
        } else {
            setStatus(
                "Press a key combination. Click the same field again to cancel.",
                isError: false
            )
        }
    }

    private func beginShortcutCapture(
        _ field: GlobalShortcutSettingsView.CaptureField
    ) {
        if shortcutCaptureField == field {
            endKeyCapture()
            return
        }

        endKeyCapture()
        shortcutCaptureField = field
        beginCaptureSession()
        globalShortcutSettingsView.beginCapturePrompt(
            for: field
        )
    }

    private func beginCaptureSession() {
        remappingController.beginKeyCapture()
        globalShortcutController.beginShortcutCapture()
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if let shortcutCaptureField {
            if event.keyCode == UInt16(kVK_Escape) {
                endKeyCapture()
                return true
            }

            let combination = keyCombination(from: event)
            globalShortcutSettingsView.setCapturedShortcut(
                combination,
                for: shortcutCaptureField
            )
            endKeyCapture()
            return true
        }

        guard let captureRow,
              let captureField else {
            return false
        }

        let combination = keyCombination(from: event)
        captureRow.setCombination(
            combination,
            for: captureField
        )
        endKeyCapture()
        refreshChangeState()
        return true
    }

    private func keyCombination(
        from event: NSEvent
    ) -> KeyCombination {
        KeyCombination(
            keyCode: CGKeyCode(event.keyCode),
            modifiers: KeyModifiers(
                appKitFlags: event.modifierFlags
            )
        )
    }

    private func endKeyCapture() {
        let hadActiveCapture =
            captureRow != nil || shortcutCaptureField != nil

        guard hadActiveCapture else {
            return
        }

        captureRow?.restoreButtonTitles()
        globalShortcutSettingsView.endCapturePrompt()
        captureRow = nil
        captureField = nil
        shortcutCaptureField = nil

        do {
            try globalShortcutController.endShortcutCapture()
        } catch {
            globalShortcutSettingsView.showCaptureRestorationFailure()
            setStatus(
                "The previous global shortcut could not be restored after key capture.",
                isError: true
            )
        }

        remappingController.endKeyCapture()
    }

    /// Returns all current rules only when every row is complete.
    private var completeCurrentRules: [RemapRule]? {
        let rules = ruleRows.compactMap { $0.rule }

        guard rules.count == ruleRows.count else {
            return nil
        }

        return rules
    }

    /// Indicates whether the rule editor differs from the last
    /// successfully loaded or saved rule collection.
    private var hasUnsavedRuleChanges: Bool {
        guard let currentRules = completeCurrentRules else {
            return true
        }

        return normalizedRules(currentRules)
            != normalizedRules(savedRules)
    }

    /// Sorts rules and their exceptions into a stable order.
    private func normalizedRules(
        _ rules: [RemapRule]
    ) -> [RemapRule] {
        let normalizedRules = rules.map { rule in
            RemapRule(
                source: rule.source,
                destination: rule.destination,
                matchingMode: rule.matchingMode,
                overrides: normalizedOverrides(
                    rule.overrides
                )
            )
        }

        return normalizedRules.sorted { first, second in
            if first.source.keyCode != second.source.keyCode {
                return first.source.keyCode
                    < second.source.keyCode
            }

            if first.source.modifiers.rawValue
                != second.source.modifiers.rawValue {
                return first.source.modifiers.rawValue
                    < second.source.modifiers.rawValue
            }

            if first.matchingMode.rawValue
                != second.matchingMode.rawValue {
                return first.matchingMode.rawValue
                    < second.matchingMode.rawValue
            }

            if first.destination.keyCode
                != second.destination.keyCode {
                return first.destination.keyCode
                    < second.destination.keyCode
            }

            return first.destination.modifiers.rawValue
                < second.destination.modifiers.rawValue
        }
    }

    private func normalizedOverrides(
        _ overrides: [RemapOverride]
    ) -> [RemapOverride] {
        overrides.sorted { first, second in
            if first.source.keyCode != second.source.keyCode {
                return first.source.keyCode
                    < second.source.keyCode
            }

            if first.source.modifiers.rawValue
                != second.source.modifiers.rawValue {
                return first.source.modifiers.rawValue
                    < second.source.modifiers.rawValue
            }

            return actionSortKey(first.action)
                < actionSortKey(second.action)
        }
    }

    private func actionSortKey(
        _ action: RemapAction
    ) -> String {
        switch action {
        case .passThrough:
            return "0"

        case .replaceWith(let destination):
            return "1-\(destination.keyCode)-\(destination.modifiers.rawValue)"
        }
    }

    private func validationSnapshot() -> ValidationSnapshot {
        var invalidRows = Set<ObjectIdentifier>()
        var exactOwners: [
            KeyCombination: [RemappingRuleRowView]
        ] = [:]
        var preservingOwners: [
            CGKeyCode: [RemappingRuleRowView]
        ] = [:]
        var hasIncompleteRule = false
        var hasIdentityRule = false
        var hasDuplicateSource = false

        for row in ruleRows {
            guard let rule = row.rule else {
                hasIncompleteRule = true
                invalidRows.insert(
                    ObjectIdentifier(row)
                )
                continue
            }

            switch rule.matchingMode {
            case .exact:
                exactOwners[
                    rule.source,
                    default: []
                ].append(row)

                if rule.source == rule.destination {
                    hasIdentityRule = true
                    invalidRows.insert(
                        ObjectIdentifier(row)
                    )
                }

            case .preserveModifiers:
                preservingOwners[
                    rule.source.keyCode,
                    default: []
                ].append(row)

                if rule.source.keyCode
                    == rule.destination.keyCode {
                    hasIdentityRule = true
                    invalidRows.insert(
                        ObjectIdentifier(row)
                    )
                }

                for override in rule.overrides {
                    exactOwners[
                        override.source,
                        default: []
                    ].append(row)

                    if case .replaceWith(let destination) =
                        override.action,
                       override.source == destination {
                        hasIdentityRule = true
                        invalidRows.insert(
                            ObjectIdentifier(row)
                        )
                    }
                }
            }
        }

        for owners in exactOwners.values
        where owners.count > 1 {
            hasDuplicateSource = true

            for row in owners {
                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }
        }

        for owners in preservingOwners.values
        where owners.count > 1 {
            hasDuplicateSource = true

            for row in owners {
                invalidRows.insert(
                    ObjectIdentifier(row)
                )
            }
        }

        let issue: EditorValidationIssue?

        if hasDuplicateSource {
            issue = .duplicateSource
        } else if hasIdentityRule {
            issue = .identicalSourceAndDestination
        } else if hasIncompleteRule {
            issue = .incompleteRule
        } else {
            issue = nil
        }

        return ValidationSnapshot(
            issue: issue,
            invalidRows: invalidRows
        )
    }

    private func applyValidationAppearance(
        _ snapshot: ValidationSnapshot
    ) {
        for row in ruleRows {
            let isInvalid = snapshot.invalidRows.contains(
                ObjectIdentifier(row)
            )
            row.setValidationErrorVisible(isInvalid)
        }
    }

    private func refreshChangeState() {
        let snapshot = validationSnapshot()
        applyValidationAppearance(snapshot)

        let hasChanges = hasUnsavedRuleChanges
        saveButton.isEnabled =
            snapshot.issue == nil && hasChanges

        if let issue = snapshot.issue {
            setStatus(
                issue.message,
                isError: true
            )
            return
        }

        if !hasChanges {
            if savedRules.isEmpty {
                setStatus(
                    "No remapping rules are configured.",
                    isError: false
                )
            } else {
                setStatus(
                    "Rules are saved locally on this Mac.",
                    isError: false
                )
            }

            return
        }

        setStatus(
            "You have unsaved rule changes.",
            isError: false
        )
    }

    @objc
    private func saveRules() {
        _ = persistRules()
    }

    @discardableResult
    private func persistRules() -> Bool {
        let snapshot = validationSnapshot()
        applyValidationAppearance(snapshot)

        if let issue = snapshot.issue {
            setStatus(
                issue.message,
                isError: true
            )
            return false
        }

        guard let rules = completeCurrentRules else {
            setStatus(
                "Complete every highlighted rule before saving.",
                isError: true
            )
            return false
        }

        do {
            try remappingController.replaceConfiguredRules(
                rules
            )
            savedRules = rules
            refreshChangeState()
            return true
        } catch let error as RemappingRulesValidationError {
            switch error {
            case .duplicateSourceKey,
                 .duplicateSourceCombination,
                 .duplicatePreservingSourceKey:
                setStatus(
                    "Each source key or key combination can appear only once.",
                    isError: true
                )

            case .identicalSourceAndDestination,
                 .identicalSourceAndDestinationCombination:
                setStatus(
                    "A source and destination combination cannot be identical.",
                    isError: true
                )

            case .invalidModifierPreservingEndpoints:
                setStatus(
                    "A Preserve Modifiers rule must use source and destination keys without modifiers.",
                    isError: true
                )

            case .overridesRequireModifierPreservingRule:
                setStatus(
                    "Custom exceptions can only be added to a Preserve Modifiers rule.",
                    isError: true
                )

            case .overrideSourceKeyMismatch:
                setStatus(
                    "Every exception must use the same physical source key as its parent rule.",
                    isError: true
                )
            }

            return false
        } catch {
            setStatus(
                "The remapping rules could not be saved.",
                isError: true
            )
            return false
        }
    }

    private func setStatus(
        _ message: String,
        isError: Bool
    ) {
        statusLabel.stringValue = message
        statusLabel.textColor =
            isError ? .systemRed : .secondaryLabelColor
    }

    private func setTextScale(
        _ proposedScale: CGFloat
    ) {
        let newScale = Self.clampedTextScale(
            proposedScale
        )

        guard newScale != textScale else {
            return
        }

        textScale = newScale
        UserDefaults.standard.set(
            Double(newScale),
            forKey: TextSizePreference.storageKey
        )
        applyTextScale()
    }

    private func applyTextScale() {
        titleLabel.font = NSFont.systemFont(
            ofSize: 22 * textScale,
            weight: .semibold
        )
        descriptionLabel.font = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )
        sourceHeader.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .medium
        )
        destinationHeader.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .medium
        )
        behaviorHeader.font = destinationHeader.font
        exceptionsHeader.font = destinationHeader.font
        statusLabel.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )

        let actionFont = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        launchBehaviorTitleLabel.font = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .semibold
        )
        launchBehaviorDescriptionLabel.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )
        launchBehaviorControl.font = actionFont
        launchBehaviorStack.spacing = 6 * textScale

        globalShortcutSettingsView.applyTextScale(
            textScale
        )

        confirmRuleRemovalCheckbox.font = actionFont
        addRuleButton.font = actionFont
        saveButton.font = actionFont
        remappingLabel.font = actionFont
        textSizeLabel.font = actionFont
        decreaseTextSizeButton.font = actionFont
        resetTextSizeButton.font = actionFont
        increaseTextSizeButton.font = actionFont
        showMenuBarIconCheckbox.font = actionFont

        rulesStackView.spacing = 10 * textScale
        actionsStack.spacing = 12 * textScale
        mainStack.spacing = 16 * textScale

        for row in ruleRows {
            row.applyTextScale(textScale)
        }

        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    private static func clampedTextScale(
        _ scale: CGFloat
    ) -> CGFloat {
        min(
            max(
                scale,
                TextSizePreference.minimumScale
            ),
            TextSizePreference.maximumScale
        )
    }
}
