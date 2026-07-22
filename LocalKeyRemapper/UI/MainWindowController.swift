//
//  MainWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A main application window that intercepts a key press only while the user
/// is explicitly recording a global shortcut.
///
/// The handler receives events only from this window. It is not a global
/// keyboard monitor.
@MainActor
private final class MainWindow: NSWindow {
    var flagsChangedHandler: ((NSEvent) -> Void)?
    var keyDownHandler: ((NSEvent) -> Bool)?

    override func sendEvent(
        _ event: NSEvent
    ) {
        if event.type == .flagsChanged {
            flagsChangedHandler?(event)
        }

        if event.type == .keyDown,
           keyDownHandler?(event) == true {
            return
        }

        super.sendEvent(event)
    }
}

/// Manages application-wide controls and preferences.
///
/// Detailed remapping-rule editing is intentionally owned by
/// `RemappingRulesWindowController` so this window remains focused on the
/// overall state of the application.
@MainActor
final class MainWindowController:
    NSWindowController,
    NSWindowDelegate
{
    private let remappingController: RemappingSettingsControlling
    private let appPreferencesController: AppPreferencesControlling
    private let globalShortcutController: GlobalShortcutController
    private let menuBarVisibilityChangeHandler: (Bool) throws -> Void
    private let openAccessibilitySettingsHandler: () -> Void
    private let openRemappingRulesHandler: () -> Void
    private let increaseTextSizeHandler: () -> Void
    private let decreaseTextSizeHandler: () -> Void
    private let resetTextSizeHandler: () -> Void

    private let globalShortcutSettingsView: GlobalShortcutSettingsView

    /// The application controller implements both the settings and runtime
    /// remapping interfaces. Keeping the cast here avoids widening the
    /// settings-only protocol used by tests and other UI components.
    private var remappingRuntimeController: RemappingControlling? {
        remappingController as? RemappingControlling
    }

    private let titleLabel = NSTextField(
        labelWithString: "LocalKeyRemapper"
    )

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Control keyboard remapping and configure application-wide behavior. Detailed rules are managed in their own window."
    )

    private let remappingSectionTitleLabel = NSTextField(
        labelWithString: "Remapping"
    )

    private let remappingSectionDescriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Enable or disable the active remapping configuration."
    )

    private let remappingLabel = NSTextField(
        labelWithString: "Keyboard remapping"
    )

    private let remappingSwitch = NSSwitch()
    private let remappingControlStack = NSStackView()

    private let accessibilityPermissionLabel = NSTextField(
        labelWithString: "Accessibility Permission Required"
    )

    private let openAccessibilitySettingsButton = NSButton()
    private let accessibilityPermissionStack = NSStackView()

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

    private let rulesSectionTitleLabel = NSTextField(
        labelWithString: "Remapping rules"
    )

    private let rulesSectionDescriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Open the dedicated rules window to view, add, edit, remove and save remapping rules and their exceptions."
    )

    private let manageRulesButton = NSButton()
    private let rulesSectionStack = NSStackView()

    private let interfaceSectionTitleLabel = NSTextField(
        labelWithString: "Interface"
    )

    private let showMenuBarIconCheckbox = NSButton(
        checkboxWithTitle: "Show icon in menu bar",
        target: nil,
        action: nil
    )

    private let textSizeLabel = NSTextField(
        labelWithString: "Text size"
    )

    private let decreaseTextSizeButton = NSButton()
    private let resetTextSizeButton = NSButton()
    private let increaseTextSizeButton = NSButton()
    private let textSizeStack = NSStackView()
    private let interfaceStack = NSStackView()

    private let statusLabel = NSTextField(
        wrappingLabelWithString: ""
    )

    private let mainStack = NSStackView()

    private var shortcutCaptureField:
        GlobalShortcutSettingsView.CaptureField?

    private var fnModifierStateTracker =
        FnModifierStateTracker()

    private var textScale: CGFloat

    init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        menuBarVisibilityChangeHandler:
            @escaping (Bool) throws -> Void,
        openAccessibilitySettingsHandler: @escaping () -> Void = {},
        openRemappingRulesHandler: @escaping () -> Void,
        increaseTextSizeHandler: @escaping () -> Void,
        decreaseTextSizeHandler: @escaping () -> Void,
        resetTextSizeHandler: @escaping () -> Void,
        textScale: CGFloat? = nil
    ) {
        self.remappingController = remappingController
        self.appPreferencesController = appPreferencesController
        self.globalShortcutController = globalShortcutController
        self.menuBarVisibilityChangeHandler =
            menuBarVisibilityChangeHandler
        self.openAccessibilitySettingsHandler =
            openAccessibilitySettingsHandler
        self.openRemappingRulesHandler =
            openRemappingRulesHandler
        self.increaseTextSizeHandler =
            increaseTextSizeHandler
        self.decreaseTextSizeHandler =
            decreaseTextSizeHandler
        self.resetTextSizeHandler =
            resetTextSizeHandler
        self.textScale = InterfaceTextScalePreference.clamped(
            textScale ?? InterfaceTextScalePreference.currentScale
        )

        globalShortcutSettingsView = GlobalShortcutSettingsView(
            configuration:
                appPreferencesController
                    .preferences
                    .shortcutConfiguration
        )

        let window = MainWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 780,
                height: 760
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
            width: 680,
            height: 620
        )
        window.contentMaxSize = NSSize(
            width: 980,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.center()

        super.init(window: window)

        window.delegate = self
        window.flagsChangedHandler = { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        window.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        configureShortcutSettingsCallbacks()
        configureContent()
        synchronizeLaunchBehavior()
        synchronizeMenuBarIconVisibility()
        updateRemappingState(
            remappingRuntimeController?.state ?? .disabled
        )
        applyTextScale(
            self.textScale
        )
    }

    /// Compatibility initializer retained for existing tests and call sites.
    convenience init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        menuBarVisibilityChangeHandler:
            @escaping (Bool) throws -> Void,
        openAccessibilitySettingsHandler: @escaping () -> Void = {}
    ) {
        self.init(
            remappingController: remappingController,
            appPreferencesController: appPreferencesController,
            globalShortcutController: globalShortcutController,
            menuBarVisibilityChangeHandler:
                menuBarVisibilityChangeHandler,
            openAccessibilitySettingsHandler:
                openAccessibilitySettingsHandler,
            openRemappingRulesHandler: {},
            increaseTextSizeHandler: {},
            decreaseTextSizeHandler: {},
            resetTextSizeHandler: {}
        )
    }

    /// Compatibility initializer retained while rule editing moves into its
    /// dedicated controller. The supplied session remains owned externally.
    convenience init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        ruleEditorSession: RemappingRuleEditorSession,
        menuBarVisibilityChangeHandler:
            @escaping (Bool) throws -> Void,
        openAccessibilitySettingsHandler: @escaping () -> Void = {}
    ) {
        self.init(
            remappingController: remappingController,
            appPreferencesController: appPreferencesController,
            globalShortcutController: globalShortcutController,
            menuBarVisibilityChangeHandler:
                menuBarVisibilityChangeHandler,
            openAccessibilitySettingsHandler:
                openAccessibilitySettingsHandler,
            openRemappingRulesHandler: {},
            increaseTextSizeHandler: {},
            decreaseTextSizeHandler: {},
            resetTextSizeHandler: {}
        )
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    override func showWindow(
        _ sender: Any?
    ) {
        if window?.isVisible == false {
            synchronizeLaunchBehavior()
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
        }

        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
    }

    /// Ends local shortcut capture before another window starts its own
    /// capture session or before application-level components stop.
    func endActiveCapture() {
        endShortcutCapture()
    }

    func prepareForApplicationTermination() {
        endShortcutCapture()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale = InterfaceTextScalePreference.clamped(
            scale
        )

        titleLabel.font = NSFont.systemFont(
            ofSize: 22 * textScale,
            weight: .semibold
        )
        descriptionLabel.font = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        let sectionTitleFont = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .semibold
        )
        let descriptionFont = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )
        let controlFont = NSFont.systemFont(
            ofSize: 14 * textScale,
            weight: .regular
        )

        remappingSectionTitleLabel.font = sectionTitleFont
        remappingSectionDescriptionLabel.font = descriptionFont
        remappingLabel.font = controlFont
        accessibilityPermissionLabel.font = descriptionFont
        openAccessibilitySettingsButton.font = controlFont

        launchBehaviorTitleLabel.font = sectionTitleFont
        launchBehaviorDescriptionLabel.font = descriptionFont
        launchBehaviorControl.font = controlFont

        rulesSectionTitleLabel.font = sectionTitleFont
        rulesSectionDescriptionLabel.font = descriptionFont
        manageRulesButton.font = controlFont

        interfaceSectionTitleLabel.font = sectionTitleFont
        showMenuBarIconCheckbox.font = controlFont
        textSizeLabel.font = controlFont
        decreaseTextSizeButton.font = controlFont
        resetTextSizeButton.font = controlFont
        increaseTextSizeButton.font = controlFont
        statusLabel.font = descriptionFont

        globalShortcutSettingsView.applyTextScale(
            textScale
        )

        mainStack.spacing = 18 * textScale
        remappingControlStack.spacing = 10 * textScale
        accessibilityPermissionStack.spacing = 8 * textScale
        launchBehaviorStack.spacing = 6 * textScale
        rulesSectionStack.spacing = 8 * textScale
        textSizeStack.spacing = 8 * textScale
        interfaceStack.spacing = 10 * textScale

        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    /// Compatibility methods retained for direct controller use. The
    /// coordinator normally applies the shared scale to every open window.
    func increaseTextSize() {
        applyTextScale(
            InterfaceTextScalePreference.set(
                textScale + InterfaceTextScalePreference.step
            )
        )
    }

    func decreaseTextSize() {
        applyTextScale(
            InterfaceTextScalePreference.set(
                textScale - InterfaceTextScalePreference.step
            )
        )
    }

    func resetTextSize() {
        applyTextScale(
            InterfaceTextScalePreference.reset()
        )
    }

    /// Updates controls to reflect the real backend state.
    func updateRemappingState(
        _ state: RemappingState
    ) {
        let canControlRemapping =
            remappingRuntimeController != nil

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

    /// Updates the checkbox when the preference changes elsewhere, such as
    /// from the application's native menu.
    func updateMenuBarIconVisibility(
        _ showsMenuBarIcon: Bool
    ) {
        showMenuBarIconCheckbox.state =
            showsMenuBarIcon ? .on : .off
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        endShortcutCapture()

        guard globalShortcutSettingsView.hasUnsavedChanges else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Save changes before closing?"
        alert.informativeText =
            "Your global shortcut settings have been modified."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return globalShortcutSettingsView.persistConfiguration()

        case .alertSecondButtonReturn:
            globalShortcutSettingsView.discardChanges()
            return true

        default:
            return false
        }
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        endShortcutCapture()
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        descriptionLabel.textColor = .secondaryLabelColor
        remappingSectionDescriptionLabel.textColor = .secondaryLabelColor
        launchBehaviorDescriptionLabel.textColor = .secondaryLabelColor
        rulesSectionDescriptionLabel.textColor = .secondaryLabelColor
        statusLabel.textColor = .secondaryLabelColor

        configureRemappingSection()
        configureLaunchBehavior()
        configureRulesSection()
        configureMenuBarVisibilityPreference()
        configureTextSizeControls()
        configureAccessibilityPermissionNotice()

        interfaceStack.setViews(
            [
                interfaceSectionTitleLabel,
                showMenuBarIconCheckbox,
                textSizeStack
            ],
            in: .leading
        )
        interfaceStack.orientation = .vertical
        interfaceStack.alignment = .leading

        mainStack.setViews(
            [
                titleLabel,
                descriptionLabel,
                remappingSectionTitleLabel,
                remappingSectionDescriptionLabel,
                remappingControlStack,
                accessibilityPermissionStack,
                launchBehaviorStack,
                globalShortcutSettingsView,
                rulesSectionStack,
                interfaceStack,
                statusLabel
            ],
            in: .leading
        )
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        globalShortcutSettingsView.translatesAutoresizingMaskIntoConstraints =
            false
        launchBehaviorStack.translatesAutoresizingMaskIntoConstraints = false
        remappingControlStack.translatesAutoresizingMaskIntoConstraints = false
        accessibilityPermissionStack.translatesAutoresizingMaskIntoConstraints =
            false
        rulesSectionStack.translatesAutoresizingMaskIntoConstraints = false
        interfaceStack.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

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
                    lessThanOrEqualTo: contentView.bottomAnchor,
                    constant: -28
                ),
                remappingControlStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                accessibilityPermissionStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                launchBehaviorStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                globalShortcutSettingsView.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                rulesSectionStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                interfaceStack.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                ),
                statusLabel.widthAnchor.constraint(
                    equalTo: mainStack.widthAnchor
                )
            ]
        )
    }

    private func configureRemappingSection() {
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

        let spacer = NSView()
        spacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        remappingControlStack.setViews(
            [
                remappingLabel,
                spacer,
                remappingSwitch
            ],
            in: .leading
        )
        remappingControlStack.orientation = .horizontal
        remappingControlStack.alignment = .centerY
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
        accessibilityPermissionStack.isHidden = true
    }

    @objc
    private func openAccessibilitySettings() {
        openAccessibilitySettingsHandler()
    }

    private func configureLaunchBehavior() {
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

        launchBehaviorControl.translatesAutoresizingMaskIntoConstraints = false
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
            setStatus(
                "The launch behavior was saved locally on this Mac.",
                isError: false
            )
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

    private func configureRulesSection() {
        manageRulesButton.title = "Manage Remapping Rules…"
        manageRulesButton.image = NSImage(
            systemSymbolName: "list.bullet.rectangle",
            accessibilityDescription: "Manage Remapping Rules"
        )
        manageRulesButton.imagePosition = .imageLeading
        manageRulesButton.bezelStyle = .rounded
        manageRulesButton.target = self
        manageRulesButton.action = #selector(
            openRemappingRules
        )
        manageRulesButton.toolTip =
            "Open the dedicated remapping rules window."

        rulesSectionStack.setViews(
            [
                rulesSectionTitleLabel,
                rulesSectionDescriptionLabel,
                manageRulesButton
            ],
            in: .leading
        )
        rulesSectionStack.orientation = .vertical
        rulesSectionStack.alignment = .leading
    }

    @objc
    private func openRemappingRules() {
        endShortcutCapture()
        openRemappingRulesHandler()
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
            setStatus(
                "The menu bar preference was saved locally on this Mac.",
                isError: false
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

    private func configureTextSizeControls() {
        decreaseTextSizeButton.title = "−"
        decreaseTextSizeButton.bezelStyle = .rounded
        decreaseTextSizeButton.target = self
        decreaseTextSizeButton.action = #selector(
            decreaseTextSizeButtonPressed
        )
        decreaseTextSizeButton.toolTip =
            "Decrease application text size."

        resetTextSizeButton.title = "Reset"
        resetTextSizeButton.bezelStyle = .rounded
        resetTextSizeButton.target = self
        resetTextSizeButton.action = #selector(
            resetTextSizeButtonPressed
        )
        resetTextSizeButton.toolTip =
            "Restore the default application text size."

        increaseTextSizeButton.title = "+"
        increaseTextSizeButton.bezelStyle = .rounded
        increaseTextSizeButton.target = self
        increaseTextSizeButton.action = #selector(
            increaseTextSizeButtonPressed
        )
        increaseTextSizeButton.toolTip =
            "Increase application text size."

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

        textSizeStack.setViews(
            [
                textSizeLabel,
                decreaseTextSizeButton,
                resetTextSizeButton,
                increaseTextSizeButton
            ],
            in: .leading
        )
        textSizeStack.orientation = .horizontal
        textSizeStack.alignment = .centerY
    }

    @objc
    private func decreaseTextSizeButtonPressed() {
        decreaseTextSizeHandler()
    }

    @objc
    private func resetTextSizeButtonPressed() {
        resetTextSizeHandler()
    }

    @objc
    private func increaseTextSizeButtonPressed() {
        increaseTextSizeHandler()
    }

    private func configureShortcutSettingsCallbacks() {
        globalShortcutSettingsView.onCaptureRequested = {
            [weak self] field in

            self?.beginShortcutCapture(field)
        }

        globalShortcutSettingsView.onCaptureCancellationRequested = {
            [weak self] in

            self?.endShortcutCapture()
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

    private func beginShortcutCapture(
        _ field: GlobalShortcutSettingsView.CaptureField
    ) {
        if shortcutCaptureField == field {
            endShortcutCapture()
            return
        }

        endShortcutCapture()
        shortcutCaptureField = field
        beginCaptureSession()
        globalShortcutSettingsView.beginCapturePrompt(
            for: field
        )
    }

    private func beginCaptureSession() {
        fnModifierStateTracker.synchronize(
            isPressed: PhysicalFnKeyState.isPressed()
        )
        remappingController.beginKeyCapture()
        globalShortcutController.beginShortcutCapture()
    }

    private func handleFlagsChanged(
        _ event: NSEvent
    ) {
        guard shortcutCaptureField != nil,
              event.keyCode == UInt16(kVK_Function) else {
            return
        }

        fnModifierStateTracker.handleFlagsChanged(
            isPressed:
                event.modifierFlags.contains(.function)
        )
    }

    private func handleKeyDown(
        _ event: NSEvent
    ) -> Bool {
        guard let shortcutCaptureField else {
            return false
        }

        if event.keyCode == UInt16(kVK_Escape) {
            endShortcutCapture()
            return true
        }

        let combination = keyCombination(
            from: event
        )
        globalShortcutSettingsView.setCapturedShortcut(
            combination,
            for: shortcutCaptureField
        )
        endShortcutCapture()
        return true
    }

    private func keyCombination(
        from event: NSEvent
    ) -> KeyCombination {
        KeyCombinationInputNormalizer.combination(
            deliveredKeyCode: CGKeyCode(event.keyCode),
            modifiers: KeyModifiers(
                appKitFlags: event.modifierFlags
            ),
            physicalFnIsPressed:
                fnModifierStateTracker.isPressed
        )
    }

    private func endShortcutCapture() {
        guard shortcutCaptureField != nil else {
            return
        }

        globalShortcutSettingsView.endCapturePrompt()
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
        fnModifierStateTracker.reset()
    }

    private func setStatus(
        _ message: String,
        isError: Bool
    ) {
        statusLabel.stringValue = message
        statusLabel.textColor =
            isError ? .systemRed : .secondaryLabelColor
    }
}
