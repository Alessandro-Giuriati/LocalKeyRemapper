//
//  RemappingRulesWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// A reusable rules window that receives local key events only while the user
/// explicitly records a source or destination combination.
///
/// This is not a global keyboard monitor. Runtime remapping continues to be
/// owned by `EventTapManager`, `RemappingEngine`, and `RemappingController`.
@MainActor
private final class RemappingRulesWindow: NSWindow {
    var flagsChangedHandler: ((NSEvent) -> Void)?
    var keyDownHandler: ((NSEvent) -> Bool)?
    var undoHandler: (() -> Void)?
    var redoHandler: (() -> Void)?
    var canUndoHandler: (() -> Bool)?
    var canRedoHandler: (() -> Bool)?

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

    override func validateUserInterfaceItem(
        _ item: NSValidatedUserInterfaceItem
    ) -> Bool {
        if item.action
            == #selector(performRuleEditorUndo(_:))
        {
            return canUndoHandler?() ?? false
        }

        if item.action
            == #selector(performRuleEditorRedo(_:))
        {
            return canRedoHandler?() ?? false
        }

        return super.validateUserInterfaceItem(item)
    }

    @objc
    func performRuleEditorUndo(
        _ sender: Any?
    ) {
        undoHandler?()
    }

    @objc
    func performRuleEditorRedo(
        _ sender: Any?
    ) {
        redoHandler?()
    }
}

/// Keeps scrollable rule content anchored to the top-left corner.
@MainActor
private final class RulesFlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

/// Draws the rules header while preserving normal hit testing for all child
/// controls, including the Issues filters.
@MainActor
private final class InteractiveRulesHeaderView: NSView {

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
                .withAlphaComponent(
                    0.35
                )
                .cgColor

        layer?.borderColor =
            NSColor.separatorColor
                .cgColor
    }
}


/// Presents a sortable Boolean rule column together with one native macOS
/// switch that changes the same state for every rule.
///
/// `NSSwitch` remains binary. When only some rules use the state, the adjacent
/// "Mixed" label represents the aggregate value while the switch remains ready
/// to enable the state for every rule.
@MainActor
private final class RulesToggleHeaderView: NSView {
    enum SelectionState {
        case unavailable
        case disabled
        case mixed
        case enabled
    }

    struct Configuration {
        let title: String
        let sortAccessibilityLabel: String
        let globalAccessibilityLabel: String
        let globalAccessibilityHelp: String
        let unavailableToolTip: String
        let enableAllToolTip: String
        let mixedToolTip: String
        let disableAllToolTip: String
        let mixedLabelToolTip: String

        static let active =
            Configuration(
                title:
                    "Active",
                sortAccessibilityLabel:
                    "Sort by Active",
                globalAccessibilityLabel:
                    "Activate all rules",
                globalAccessibilityHelp:
                    "Activates or deactivates every rule. A Mixed indicator appears when only some rules are active.",
                unavailableToolTip:
                    "Add a rule before changing Active for all rules.",
                enableAllToolTip:
                    "Activate every rule.",
                mixedToolTip:
                    "Only some rules are active. Turn this on to activate every rule.",
                disableAllToolTip:
                    "Deactivate every rule.",
                mixedLabelToolTip:
                    "Some rules are active and others are inactive."
            )

        static let reverse =
            Configuration(
                title:
                    "Reverse",
                sortAccessibilityLabel:
                    "Sort by Reverse",
                globalAccessibilityLabel:
                    "Reverse all rules",
                globalAccessibilityHelp:
                    "Turns bidirectional remapping on or off for every rule. A Mixed indicator appears when only some rules are enabled.",
                unavailableToolTip:
                    "Add a rule before changing Reverse for all rules.",
                enableAllToolTip:
                    "Enable Reverse for every rule.",
                mixedToolTip:
                    "Reverse is enabled for only some rules. Turn this on to enable it for every rule.",
                disableAllToolTip:
                    "Disable Reverse for every rule.",
                mixedLabelToolTip:
                    "Some rules have Reverse enabled and others have it disabled."
            )
    }

    var onSortRequested: (() -> Void)?
    var onGlobalToggleRequested: ((Bool) -> Void)?

    private let configuration:
        Configuration

    private let sortButton =
        SortableHeaderButton(
            frame: .zero
        )

    private let globalSwitch =
        NSSwitch()

    private let mixedLabel =
        NSTextField(
            labelWithString:
                "Mixed"
        )

    private let stateStack =
        NSStackView()

    init(
        configuration:
            Configuration
    ) {
        self.configuration =
            configuration

        super.init(
            frame:
                .zero
        )

        configureContent()
    }

    required init?(
        coder:
            NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    func applyTextScale(
        _ scale:
            CGFloat
    ) {
        sortButton.applyTextScale(
            scale
        )

        mixedLabel.font =
            NSFont.systemFont(
                ofSize:
                    9 * scale,
                weight:
                    .semibold
            )

        stateStack.spacing =
            InterfaceLayoutMetrics.scaled(
                4,
                for:
                    scale,
                minimum:
                    3,
                maximum:
                    6
            )

        needsLayout =
            true
    }

    func setSortState(
        _ state:
            SortableHeaderButton.SortState
    ) {
        sortButton.setSortState(
            state
        )
    }

    /// Synchronizes the aggregate state after every row edit, global change,
    /// Undo, Redo, load, save, insertion, or removal.
    func setSelectionState(
        _ selectionState:
            SelectionState
    ) {
        switch selectionState {
        case .unavailable:
            globalSwitch.state =
                .off

            globalSwitch.isEnabled =
                false

            mixedLabel.isHidden =
                true

            globalSwitch.toolTip =
                configuration
                    .unavailableToolTip

            globalSwitch.setAccessibilityValue(
                "Unavailable"
            )

        case .disabled:
            globalSwitch.state =
                .off

            globalSwitch.isEnabled =
                true

            mixedLabel.isHidden =
                true

            globalSwitch.toolTip =
                configuration
                    .enableAllToolTip

            globalSwitch.setAccessibilityValue(
                "Off for all rules"
            )

        case .mixed:
            globalSwitch.state =
                .off

            globalSwitch.isEnabled =
                true

            mixedLabel.isHidden =
                false

            globalSwitch.toolTip =
                configuration
                    .mixedToolTip

            globalSwitch.setAccessibilityValue(
                "Mixed"
            )

        case .enabled:
            globalSwitch.state =
                .on

            globalSwitch.isEnabled =
                true

            mixedLabel.isHidden =
                true

            globalSwitch.toolTip =
                configuration
                    .disableAllToolTip

            globalSwitch.setAccessibilityValue(
                "On for all rules"
            )
        }
    }

    private func configureContent() {
        sortButton.title =
            configuration.title

        sortButton.target =
            self

        sortButton.action =
            #selector(
                sortRequested
            )

        sortButton.setAccessibilityLabel(
            configuration
                .sortAccessibilityLabel
        )

        globalSwitch.controlSize =
            .small

        globalSwitch.target =
            self

        globalSwitch.action =
            #selector(
                globalSwitchChanged
            )

        globalSwitch.setAccessibilityLabel(
            configuration
                .globalAccessibilityLabel
        )

        globalSwitch.setAccessibilityHelp(
            configuration
                .globalAccessibilityHelp
        )

        globalSwitch
            .setContentHuggingPriority(
                .required,
                for:
                    .horizontal
            )

        globalSwitch
            .setContentCompressionResistancePriority(
                .required,
                for:
                    .horizontal
            )

        mixedLabel.textColor =
            .secondaryLabelColor

        mixedLabel.alignment =
            .center

        mixedLabel.lineBreakMode =
            .byClipping

        mixedLabel.isHidden =
            true

        mixedLabel.toolTip =
            configuration
                .mixedLabelToolTip

        mixedLabel
            .setContentHuggingPriority(
                .required,
                for:
                    .horizontal
            )

        mixedLabel
            .setContentCompressionResistancePriority(
                .required,
                for:
                    .horizontal
            )

        stateStack.setViews(
            [
                mixedLabel,
                globalSwitch
            ],
            in:
                .leading
        )

        stateStack.orientation =
            .horizontal

        stateStack.alignment =
            .centerY

        stateStack.distribution =
            .fill

        sortButton.translatesAutoresizingMaskIntoConstraints =
            false

        stateStack.translatesAutoresizingMaskIntoConstraints =
            false

        addSubview(
            sortButton
        )

        addSubview(
            stateStack
        )

        NSLayoutConstraint.activate(
            [
                sortButton.leadingAnchor.constraint(
                    equalTo:
                        leadingAnchor
                ),

                sortButton.trailingAnchor.constraint(
                    equalTo:
                        trailingAnchor
                ),

                sortButton.topAnchor.constraint(
                    equalTo:
                        topAnchor
                ),

                stateStack.topAnchor.constraint(
                    equalTo:
                        sortButton.bottomAnchor,
                    constant:
                        -1
                ),

                stateStack.centerXAnchor.constraint(
                    equalTo:
                        centerXAnchor
                ),

                stateStack.bottomAnchor.constraint(
                    equalTo:
                        bottomAnchor,
                    constant:
                        -2
                )
            ]
        )

        applyTextScale(
            1.0
        )

        setSelectionState(
            .unavailable
        )
    }

    @objc
    private func sortRequested() {
        onSortRequested?()
    }

    @objc
    private func globalSwitchChanged() {
        onGlobalToggleRequested?(
            globalSwitch.state
                == .on
        )
    }
}


/// Presents editor status as plain secondary text during normal operation and
/// as a full-width red banner when a blocking validation or persistence error
/// is active.
@MainActor
private final class RulesEditorStatusView: NSView {
    private let iconView = NSImageView()

    private let messageLabel =
        NSTextField(
            wrappingLabelWithString: ""
        )

    private let contentStack = NSStackView()

    private var isShowingError = false
    private var textScale: CGFloat = 1.0

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
        updateAppearance()
    }

    convenience init() {
        self.init(
            frame: .zero
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

    func setMessage(
        _ message: String,
        isError: Bool
    ) {
        messageLabel.stringValue =
            message

        isShowingError =
            isError

        updateAppearance()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale =
            InterfaceTextScalePreference.clamped(
                scale
            )

        messageLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * textScale,
                weight:
                    .regular
            )

        iconView.image =
            NSImage(
                systemSymbolName:
                    "xmark.octagon.fill",
                accessibilityDescription:
                    "Validation error"
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize:
                        12 * textScale,
                    weight:
                        .semibold
                )
            )

        contentStack.spacing =
            InterfaceLayoutMetrics.scaled(
                7,
                for:
                    textScale,
                minimum:
                    5,
                maximum:
                    10
            )

        needsLayout =
            true
    }

    private func configureContent() {
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true

        iconView.imageScaling =
            .scaleProportionallyDown

        iconView.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        iconView
            .setContentCompressionResistancePriority(
                .required,
                for:
                    .horizontal
            )

        messageLabel.maximumNumberOfLines =
            2

        messageLabel.lineBreakMode =
            .byWordWrapping

        messageLabel.setContentHuggingPriority(
            .defaultLow,
            for:
                .horizontal
        )

        contentStack.setViews(
            [
                iconView,
                messageLabel
            ],
            in:
                .leading
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
                contentStack.leadingAnchor.constraint(
                    equalTo:
                        leadingAnchor,
                    constant:
                        9
                ),

                contentStack.trailingAnchor.constraint(
                    equalTo:
                        trailingAnchor,
                    constant:
                        -9
                ),

                contentStack.topAnchor.constraint(
                    equalTo:
                        topAnchor,
                    constant:
                        4
                ),

                contentStack.bottomAnchor.constraint(
                    equalTo:
                        bottomAnchor,
                    constant:
                        -4
                ),

                heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        24
                )
            ]
        )
    }

    private func updateAppearance() {
        if isShowingError {
            iconView.isHidden =
                false

            iconView.contentTintColor =
                .systemRed

            messageLabel.textColor =
                .systemRed

            layer?.borderWidth =
                1

            layer?.borderColor =
                NSColor.systemRed
                    .withAlphaComponent(
                        0.45
                    )
                    .cgColor

            layer?.backgroundColor =
                NSColor.systemRed
                    .withAlphaComponent(
                        0.08
                    )
                    .cgColor
        } else {
            iconView.isHidden =
                true

            messageLabel.textColor =
                .secondaryLabelColor

            layer?.borderWidth =
                0

            layer?.borderColor =
                NSColor.clear
                    .cgColor

            layer?.backgroundColor =
                NSColor.clear
                    .cgColor
        }

        setAccessibilityRole(
            .staticText
        )

        setAccessibilityLabel(
            isShowingError
                ? "Remapping rules error"
                : "Remapping rules status"
        )

        setAccessibilityValue(
            messageLabel.stringValue
        )
    }
}

/// Owns the complete remapping-rules interface while the shared
/// `RemappingRuleEditorSession` owns the actual editable data and Undo/Redo
/// history for the lifetime of the application process.
@MainActor
final class RemappingRulesWindowController:
    NSWindowController,
    NSWindowDelegate
{
    private enum EditorValidationIssue {
        case incompleteRule
        case duplicateSource
        case identicalSourceAndDestination
        case shortcutConflict(
            GlobalShortcutAction
        )

        var message: String {
            switch self {
            case .incompleteRule:
                return "Complete every highlighted rule before saving."

            case .duplicateSource:
                return "Each active exact source combination and each Preserve Modifiers source key can appear only once."

            case .identicalSourceAndDestination:
                return "A source and destination key cannot be identical."

            case .shortcutConflict(
                let action
            ):
                let shortcutTitle:
                    String

                switch action {
                case .toggle:
                    shortcutTitle =
                        "Toggle Remapping"

                case .enable:
                    shortcutTitle =
                        "Enable Remapping"

                case .disable:
                    shortcutTitle =
                        "Disable Remapping"
                }

                return "This rule contains an exact mapping that conflicts with the \(shortcutTitle) shortcut. Change the rule, remove the matching exception, or choose a different shortcut before saving."
            }
        }
    }

    private struct ValidationSnapshot {
        let issue: EditorValidationIssue?
        let invalidItemIDs: Set<UUID>

        let messagesByItemID:
            [UUID: String]

        let shortcutWarningItemIDs:
            Set<UUID>

        let shortcutWarningMessagesByItemID:
            [UUID: String]

        let primaryShortcutWarningMessage:
            String?
    }

    private enum FilterField: Equatable {
        case source
        case destination
    }

    private let remappingController: RemappingSettingsControlling
    private let appPreferencesController: AppPreferencesControlling
    private let globalShortcutController: GlobalShortcutController
    private let ruleEditorSession: RemappingRuleEditorSession

    /// Owns presentation-only sorting and filtering state.
    private let presentationModel =
        RemappingRulesPresentationModel()

    private let increaseTextSizeHandler: () -> Void
    private let decreaseTextSizeHandler: () -> Void
    private let resetTextSizeHandler: () -> Void

    private let ruleRemovalConfirmationController =
        RuleRemovalConfirmationController()

    private let titleLabel = NSTextField(
        labelWithString: "Remapping Rules"
    )

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Create, filter, sort, and manage remapping rules and exceptions."
    )

    private let warningBanner =
        ConfigurationWarningBannerView()

    private let confirmRuleRemovalLabel =
        NSTextField(
            labelWithString:
                "Confirm rule removal"
        )

    private let confirmRuleRemovalSwitch =
        NSSwitch()

    private let confirmRuleRemovalStack =
        NSStackView()

    private let activeHeaderView =
        RulesToggleHeaderView(
            configuration:
                .active
        )

    private let sourceHeaderButton =
        SortableHeaderButton(
            frame: .zero
        )

    private let destinationHeaderButton =
        SortableHeaderButton(
            frame: .zero
        )

    private let behaviorHeaderButton =
        SortableHeaderButton(
            frame: .zero
        )

    private let exceptionsHeaderButton =
        SortableHeaderButton(
            frame: .zero
        )

    private let reverseHeaderView =
        RulesToggleHeaderView(
            configuration:
                .reverse
        )

    private let issuesFilterView =
        RemappingRulesIssuesFilterView()

    private let sourceFilterControl =
        KeyCaptureFilterControl(
            fieldTitle: "Source"
        )

    private let destinationFilterControl =
        KeyCaptureFilterControl(
            fieldTitle: "Destination"
        )

    private let clearAllFiltersButton = NSButton()

    private let filterSummaryLabel = NSTextField(
        labelWithString: ""
    )

    private let filterTrailingStack = NSStackView()

    private var filterBarView: NSView?

    private let rulesScrollView = NSScrollView()
    private let rulesDocumentView = RulesFlippedView()
    private let rulesStackView = NSStackView()
    private let rulesFlexibleSpacer = NSView()

    private let addRuleButton = NSButton()
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private let saveButton = NSButton()

    private let textSizeLabel = NSTextField(
        labelWithString: "Text size"
    )

    private let decreaseTextSizeButton = NSButton()
    private let resetTextSizeButton = NSButton()
    private let increaseTextSizeButton = NSButton()

    private let actionsStack = NSStackView()

    private let statusView =
        RulesEditorStatusView()

    private let mainStack = NSStackView()
    private let headerTopRowStack = NSStackView()

    private var mainStackTopConstraint:
        NSLayoutConstraint?

    private var rulesScrollTopConstraint:
        NSLayoutConstraint?

    private var rulesScrollBottomConstraint:
        NSLayoutConstraint?

    private var actionsStatusSpacingConstraint:
        NSLayoutConstraint?

    private var statusBottomConstraint:
        NSLayoutConstraint?

    private var ruleRows: [RemappingRuleRowView] = []

    private var ruleRowsByItemID:
        [UUID: RemappingRuleRowView] = [:]

    private var captureRow: RemappingRuleRowView?

    private var captureField:
        RemappingRuleRowView.KeyField?

    private var captureFilterField:
        FilterField?

    private var exceptionsWindowController:
        RemapOverridesWindowController?

    private var fnModifierStateTracker =
        FnModifierStateTracker()

    private var nonFnModifierStateTracker =
        NonFnModifierStateTracker()

    private var textScale: CGFloat

    init(
        remappingController: RemappingSettingsControlling,
        appPreferencesController: AppPreferencesControlling,
        globalShortcutController: GlobalShortcutController,
        ruleEditorSession: RemappingRuleEditorSession,
        increaseTextSizeHandler: @escaping () -> Void,
        decreaseTextSizeHandler: @escaping () -> Void,
        resetTextSizeHandler: @escaping () -> Void,
        textScale: CGFloat? = nil
    ) {
        self.remappingController =
            remappingController

        self.appPreferencesController =
            appPreferencesController

        self.globalShortcutController =
            globalShortcutController

        self.ruleEditorSession =
            ruleEditorSession

        self.increaseTextSizeHandler =
            increaseTextSizeHandler

        self.decreaseTextSizeHandler =
            decreaseTextSizeHandler

        self.resetTextSizeHandler =
            resetTextSizeHandler

        self.textScale =
            InterfaceTextScalePreference.clamped(
                textScale
                    ?? InterfaceTextScalePreference.currentScale
            )

        let window =
            RemappingRulesWindow(
                contentRect:
                    NSRect(
                        x: 0,
                        y: 0,
                        width: 1220,
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

        window.title = "Remapping Rules"
        window.isReleasedWhenClosed = false

        window.contentMinSize =
            NSSize(
                width: 1160,
                height: 520
            )

        window.contentMaxSize =
            NSSize(
                width: 1540,
                height:
                    CGFloat.greatestFiniteMagnitude
            )

        window.center()

        super.init(
            window: window
        )

        window.delegate = self

        window.flagsChangedHandler = {
            [weak self] event in

            self?.handleFlagsChanged(
                event
            )
        }

        window.keyDownHandler = {
            [weak self] event in

            self?.handleKeyDown(
                event
            ) ?? false
        }

        window.undoHandler = {
            [weak self] in

            self?.undoRuleEditorChange()
        }

        window.redoHandler = {
            [weak self] in

            self?.redoRuleEditorChange()
        }

        window.canUndoHandler = {
            [weak self] in

            self?.canUndoRuleEditorChange
                ?? false
        }

        window.canRedoHandler = {
            [weak self] in

            self?.canRedoRuleEditorChange
                ?? false
        }

        ruleEditorSession.onChange = {
            [weak self] in

            self?.renderRuleEditor()
        }

        configureConfigurationChangeObservation()
        configureContent()
        synchronizeRuleRemovalConfirmationPreference()
        initializeRuleEditorSession()

        applyTextScale(
            self.textScale
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
            synchronizeRuleRemovalConfirmationPreference()
            renderRuleEditor()
        }

        super.showWindow(
            sender
        )

        window?.makeKeyAndOrderFront(
            sender
        )

        NSApplication.shared.activate(
            ignoringOtherApps: true
        )
    }

    /// Ends local capture before another application window starts recording
    /// or before the application terminates.
    func endActiveCapture() {
        endKeyCapture()
    }

    func prepareForApplicationTermination() {
        endKeyCapture()

        NotificationCenter.default.removeObserver(
            self,
            name:
                AppConfigurationNotification
                    .globalShortcutConfigurationDidChange,
            object:
                nil
        )

        exceptionsWindowController?.close()
        exceptionsWindowController = nil
    }

    func windowDidBecomeKey(
        _ notification: Notification
    ) {
        renderRuleEditor()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale =
            InterfaceTextScalePreference.clamped(
                scale
            )

        titleLabel.font =
            NSFont.systemFont(
                ofSize: 22 * textScale,
                weight: .semibold
            )

        descriptionLabel.font =
            NSFont.systemFont(
                ofSize: 14 * textScale,
                weight: .regular
            )

        activeHeaderView.applyTextScale(
            textScale
        )

        sourceHeaderButton.applyTextScale(
            textScale
        )

        destinationHeaderButton.applyTextScale(
            textScale
        )

        behaviorHeaderButton.applyTextScale(
            textScale
        )

        exceptionsHeaderButton.applyTextScale(
            textScale
        )

        reverseHeaderView.applyTextScale(
            textScale
        )

        issuesFilterView.applyTextScale(
            textScale
        )

        sourceFilterControl.applyTextScale(
            textScale
        )

        destinationFilterControl.applyTextScale(
            textScale
        )

        warningBanner.applyTextScale(
            textScale
        )

        let actionFont =
            NSFont.systemFont(
                ofSize: 14 * textScale,
                weight: .regular
            )

        confirmRuleRemovalLabel.font =
            actionFont

        confirmRuleRemovalStack.spacing =
            InterfaceLayoutMetrics.scaled(
                8,
                for:
                    textScale,
                minimum:
                    6,
                maximum:
                    12
            )

        addRuleButton.font =
            actionFont

        undoButton.font =
            actionFont

        redoButton.font =
            actionFont

        saveButton.font =
            actionFont

        textSizeLabel.font =
            actionFont

        decreaseTextSizeButton.font =
            actionFont

        resetTextSizeButton.font =
            actionFont

        increaseTextSizeButton.font =
            actionFont

        clearAllFiltersButton.font =
            NSFont.systemFont(
                ofSize: 13 * textScale,
                weight: .regular
            )

        filterSummaryLabel.font =
            NSFont.systemFont(
                ofSize: 12 * textScale,
                weight: .regular
            )

        statusView.applyTextScale(
            textScale
        )

        rulesStackView.spacing =
            InterfaceLayoutMetrics.scaled(
                10,
                for: textScale,
                minimum: 7,
                maximum: 16
            )

        actionsStack.spacing =
            InterfaceLayoutMetrics.scaled(
                12,
                for: textScale,
                minimum: 8,
                maximum: 18
            )

        applyLayoutMetrics()

        for row in ruleRows {
            row.applyTextScale(
                textScale
            )
        }

        window?.contentView?.needsLayout =
            true

        window?.contentView?
            .layoutSubtreeIfNeeded()
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {
        endKeyCapture()

        guard
            ruleEditorSession
                .hasUnsavedChanges
        else {
            return true
        }

        let alert = NSAlert()

        alert.messageText =
            "Save changes before closing?"

        alert.informativeText =
            "Your remapping rules have been modified."

        alert.alertStyle = .warning

        alert.addButton(
            withTitle: "Save"
        )

        alert.addButton(
            withTitle: "Discard Changes"
        )

        alert.addButton(
            withTitle: "Cancel"
        )

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return persistRules()

        case .alertSecondButtonReturn:
            ruleEditorSession
                .restoreSavedRules()

            return true

        default:
            return false
        }
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        endKeyCapture()
        exceptionsWindowController = nil
    }

    private func configureConfigurationChangeObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector:
                #selector(
                    globalShortcutConfigurationDidChange
                ),
            name:
                AppConfigurationNotification
                    .globalShortcutConfigurationDidChange,
            object:
                nil
        )
    }

    @objc
    private func globalShortcutConfigurationDidChange(
        _ notification: Notification
    ) {
        guard
            window?.isVisible == true
        else {
            return
        }

        renderRuleEditor()
    }

    private func configureContent() {
        guard
            let contentView =
                window?.contentView
        else {
            return
        }

        descriptionLabel.textColor =
            .secondaryLabelColor

        configureSortHeaderButtons()
        configureActiveHeaderView()
        configureReverseHeaderView()
        configureFilterControls()
        configureIssuesFilterView()
        configureRuleRemovalConfirmationPreference()
        configureRulesScrollView()
        configureActionButtons()
        configureTextSizeControls()

        let filterBarView =
            makeFilterBarView()

        self.filterBarView =
            filterBarView

        let rulesHeaderView =
            makeRulesHeaderView()

        configureHeaderTopRow()

        mainStack.setViews(
            [
                headerTopRowStack,
                descriptionLabel,
                warningBanner,
                filterBarView,
                rulesHeaderView
            ],
            in: .leading
        )

        mainStack.orientation =
            .vertical

        mainStack.alignment =
            .leading

        mainStack.translatesAutoresizingMaskIntoConstraints =
            false

        headerTopRowStack.translatesAutoresizingMaskIntoConstraints =
            false

        warningBanner.translatesAutoresizingMaskIntoConstraints =
            false

        rulesScrollView.translatesAutoresizingMaskIntoConstraints =
            false

        actionsStack.translatesAutoresizingMaskIntoConstraints =
            false

        statusView.translatesAutoresizingMaskIntoConstraints =
            false

        contentView.addSubview(
            mainStack
        )

        contentView.addSubview(
            rulesScrollView
        )

        contentView.addSubview(
            actionsStack
        )

        contentView.addSubview(
            statusView
        )

        let mainStackTopConstraint =
            mainStack.topAnchor.constraint(
                equalTo:
                    contentView.topAnchor
            )

        let rulesScrollTopConstraint =
            rulesScrollView.topAnchor.constraint(
                equalTo:
                    mainStack.bottomAnchor
            )

        let rulesScrollBottomConstraint =
            rulesScrollView.bottomAnchor.constraint(
                equalTo:
                    actionsStack.topAnchor
            )

        let actionsStatusSpacingConstraint =
            actionsStack.bottomAnchor.constraint(
                equalTo:
                    statusView.topAnchor
            )

        let statusBottomConstraint =
            statusView.bottomAnchor.constraint(
                equalTo:
                    contentView.bottomAnchor
            )

        self.mainStackTopConstraint =
            mainStackTopConstraint

        self.rulesScrollTopConstraint =
            rulesScrollTopConstraint

        self.rulesScrollBottomConstraint =
            rulesScrollBottomConstraint

        self.actionsStatusSpacingConstraint =
            actionsStatusSpacingConstraint

        self.statusBottomConstraint =
            statusBottomConstraint

        NSLayoutConstraint.activate(
            [
                mainStackTopConstraint,

                mainStack.leadingAnchor.constraint(
                    equalTo:
                        contentView.leadingAnchor,
                    constant: 28
                ),

                mainStack.trailingAnchor.constraint(
                    equalTo:
                        contentView.trailingAnchor,
                    constant: -28
                ),

                headerTopRowStack.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                warningBanner.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                filterBarView.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                rulesHeaderView.widthAnchor.constraint(
                    equalTo:
                        mainStack.widthAnchor
                ),

                rulesScrollTopConstraint,

                rulesScrollView.leadingAnchor.constraint(
                    equalTo:
                        contentView.leadingAnchor,
                    constant: 28
                ),

                rulesScrollView.trailingAnchor.constraint(
                    equalTo:
                        contentView.trailingAnchor,
                    constant: -28
                ),

                rulesScrollBottomConstraint,

                actionsStack.leadingAnchor.constraint(
                    equalTo:
                        contentView.leadingAnchor,
                    constant: 28
                ),

                actionsStack.trailingAnchor.constraint(
                    equalTo:
                        contentView.trailingAnchor,
                    constant: -28
                ),

                actionsStatusSpacingConstraint,

                statusView.leadingAnchor.constraint(
                    equalTo:
                        contentView.leadingAnchor,
                    constant: 28
                ),

                statusView.trailingAnchor.constraint(
                    equalTo:
                        contentView.trailingAnchor,
                    constant: -28
                ),

                statusBottomConstraint
            ]
        )

        applyLayoutMetrics()
    }

    private func configureHeaderTopRow() {
        titleLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        confirmRuleRemovalLabel
            .setContentHuggingPriority(
                .required,
                for:
                    .horizontal
            )

        confirmRuleRemovalSwitch
            .setContentHuggingPriority(
                .required,
                for:
                    .horizontal
            )

        confirmRuleRemovalStack.setViews(
            [
                confirmRuleRemovalLabel,
                confirmRuleRemovalSwitch
            ],
            in:
                .leading
        )

        confirmRuleRemovalStack.orientation =
            .horizontal

        confirmRuleRemovalStack.alignment =
            .centerY

        confirmRuleRemovalStack.distribution =
            .fill

        confirmRuleRemovalStack.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        let spacer = NSView()

        spacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        spacer
            .setContentCompressionResistancePriority(
                .defaultLow,
                for: .horizontal
            )

        headerTopRowStack.setViews(
            [
                titleLabel,
                spacer,
                confirmRuleRemovalStack
            ],
            in: .leading
        )

        headerTopRowStack.orientation =
            .horizontal

        headerTopRowStack.alignment =
            .centerY

        headerTopRowStack.distribution =
            .fill
    }

    private func applyLayoutMetrics() {
        mainStackTopConstraint?.constant =
            InterfaceLayoutMetrics.topContentMargin(
                for: textScale
            )

        mainStack.spacing =
            InterfaceLayoutMetrics.scaled(
                7,
                for: textScale,
                minimum: 5,
                maximum: 11
            )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                5,
                for: textScale,
                minimum: 4,
                maximum: 9
            ),
            after: headerTopRowStack
        )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                9,
                for: textScale,
                minimum: 7,
                maximum: 14
            ),
            after: descriptionLabel
        )

        mainStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                9,
                for: textScale,
                minimum: 7,
                maximum: 14
            ),
            after: warningBanner
        )

        if let filterBarView {
            mainStack.setCustomSpacing(
                InterfaceLayoutMetrics.scaled(
                    6,
                    for: textScale,
                    minimum: 4,
                    maximum: 10
                ),
                after: filterBarView
            )
        }

        rulesScrollTopConstraint?.constant =
            InterfaceLayoutMetrics.scaled(
                7,
                for: textScale,
                minimum: 5,
                maximum: 11
            )

        rulesScrollBottomConstraint?.constant =
            -InterfaceLayoutMetrics.scaled(
                10,
                for: textScale,
                minimum: 7,
                maximum: 15
            )

        actionsStatusSpacingConstraint?.constant =
            -InterfaceLayoutMetrics.scaled(
                5,
                for: textScale,
                minimum: 4,
                maximum: 8
            )

        statusBottomConstraint?.constant =
            -InterfaceLayoutMetrics.scaled(
                12,
                for: textScale,
                minimum: 9,
                maximum: 18
            )
    }

    private func makeFilterBarView() -> NSView {
        let filterBarView = NSView()
        let activeSpacer = NSView()
        let arrowSpacer = NSView()

        let views: [NSView] = [
            activeSpacer,
            sourceFilterControl,
            arrowSpacer,
            destinationFilterControl,
            filterTrailingStack
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            filterBarView.addSubview(
                view
            )
        }

        filterBarView.translatesAutoresizingMaskIntoConstraints =
            false

        NSLayoutConstraint.activate(
            [
                activeSpacer.leadingAnchor.constraint(
                    equalTo:
                        filterBarView.leadingAnchor,
                    constant: 12
                ),

                activeSpacer.widthAnchor.constraint(
                    equalToConstant: 88
                ),

                sourceFilterControl.leadingAnchor.constraint(
                    equalTo:
                        activeSpacer.trailingAnchor,
                    constant: 6
                ),

                sourceFilterControl.topAnchor.constraint(
                    equalTo:
                        filterBarView.topAnchor
                ),

                sourceFilterControl.bottomAnchor.constraint(
                    equalTo:
                        filterBarView.bottomAnchor
                ),

                arrowSpacer.leadingAnchor.constraint(
                    equalTo:
                        sourceFilterControl.trailingAnchor,
                    constant: 10
                ),

                arrowSpacer.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                destinationFilterControl.leadingAnchor.constraint(
                    equalTo:
                        arrowSpacer.trailingAnchor,
                    constant: 10
                ),

                destinationFilterControl.topAnchor.constraint(
                    equalTo:
                        filterBarView.topAnchor
                ),

                destinationFilterControl.bottomAnchor.constraint(
                    equalTo:
                        filterBarView.bottomAnchor
                ),

                filterTrailingStack.leadingAnchor.constraint(
                    equalTo:
                        destinationFilterControl.trailingAnchor,
                    constant: 10
                ),

                filterTrailingStack.trailingAnchor.constraint(
                    equalTo:
                        filterBarView.trailingAnchor,
                    constant: -12
                ),

                filterTrailingStack.centerYAnchor.constraint(
                    equalTo:
                        destinationFilterControl.centerYAnchor
                ),

                filterTrailingStack.widthAnchor.constraint(
                    equalToConstant: 410
                ),

                sourceFilterControl.widthAnchor.constraint(
                    equalTo:
                        destinationFilterControl.widthAnchor
                ),

                sourceFilterControl.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        120
                ),

                filterBarView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        32
                )
            ]
        )

        return filterBarView
    }

    private func configureFilterControls() {
        sourceFilterControl.onCaptureRequested = {
            [weak self] in

            self?.beginFilterKeyCapture(
                .source
            )
        }

        sourceFilterControl.onClearRequested = {
            [weak self] in

            self?.clearSourceFilter()
        }

        destinationFilterControl.onCaptureRequested = {
            [weak self] in

            self?.beginFilterKeyCapture(
                .destination
            )
        }

        destinationFilterControl.onClearRequested = {
            [weak self] in

            self?.clearDestinationFilter()
        }

        clearAllFiltersButton.title =
            "Clear Filters"

        clearAllFiltersButton.image =
            NSImage(
                systemSymbolName:
                    "xmark.circle",
                accessibilityDescription:
                    "Clear all filters"
            )

        clearAllFiltersButton.imagePosition =
            .imageLeading

        clearAllFiltersButton.bezelStyle =
            .rounded

        clearAllFiltersButton.target =
            self

        clearAllFiltersButton.action =
            #selector(
                clearAllFilters
            )

        clearAllFiltersButton.toolTip =
            "Clear Source, Destination, and Issues filters."

        filterSummaryLabel.textColor =
            .secondaryLabelColor

        filterSummaryLabel.alignment =
            .right

        filterSummaryLabel.lineBreakMode =
            .byTruncatingTail

        let flexibleSpacer = NSView()

        flexibleSpacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        flexibleSpacer
            .setContentCompressionResistancePriority(
                .defaultLow,
                for: .horizontal
            )

        filterTrailingStack.setViews(
            [
                flexibleSpacer,
                filterSummaryLabel,
                clearAllFiltersButton
            ],
            in: .leading
        )

        filterTrailingStack.orientation =
            .horizontal

        filterTrailingStack.alignment =
            .centerY

        filterTrailingStack.distribution =
            .fill

        filterTrailingStack.spacing =
            8

        updateFilterControls()
    }

    private func updateFilterControls() {
        sourceFilterControl.setFilterKeyCode(
            presentationModel.sourceFilterKeyCode
        )

        destinationFilterControl.setFilterKeyCode(
            presentationModel.destinationFilterKeyCode
        )

        issuesFilterView.setFilterState(
            validationIsActive:
                presentationModel.showsOnlyValidationIssues,
            warningIsActive:
                presentationModel.showsOnlyConfigurationWarnings
        )

        clearAllFiltersButton.isHidden =
            !presentationModel.hasActiveFilters
    }

    private func updateFilterSummary(
        visibleCount: Int
    ) {
        let totalCount =
            ruleEditorSession.items.count

        if presentationModel.hasActiveFilters {
            filterSummaryLabel.stringValue =
                "\(visibleCount) of \(totalCount) rules"
        } else {
            filterSummaryLabel.stringValue =
                totalCount == 1
                    ? "1 rule"
                    : "\(totalCount) rules"
        }
    }

    private func beginFilterKeyCapture(
        _ field: FilterField
    ) {
        if captureFilterField == field,
           captureRow == nil {
            endKeyCapture()
            refreshChangeState()
            return
        }

        endKeyCapture()

        captureFilterField = field

        beginCaptureSession()

        filterControl(
            for: field
        ).showCapturePrompt()

        updateRuleEditorHistoryControls()

        let fieldName =
            field == .source
                ? "Source"
                : "Destination"

        setStatus(
            "Press a physical key to filter \(fieldName). Modifiers are ignored. Press Escape or click the same filter again to cancel.",
            isError: false
        )
    }

    private func filterControl(
        for field: FilterField
    ) -> KeyCaptureFilterControl {
        switch field {
        case .source:
            return sourceFilterControl

        case .destination:
            return destinationFilterControl
        }
    }

    private func clearSourceFilter() {
        endKeyCapture()
        presentationModel.clearSourceFilter()
        renderRuleEditor()
    }

    private func clearDestinationFilter() {
        endKeyCapture()
        presentationModel.clearDestinationFilter()
        renderRuleEditor()
    }

    private func configureIssuesFilterView() {
        issuesFilterView.onSortRequested = {
            [weak self] in

            self?.applySorting(
                .issues
            )
        }

        issuesFilterView.onValidationFilterToggle = {
            [weak self] in

            self?.toggleValidationIssueFilter()
        }

        issuesFilterView.onWarningFilterToggle = {
            [weak self] in

            self?.toggleConfigurationWarningFilter()
        }
    }

    private func toggleValidationIssueFilter() {
        endKeyCapture()
        presentationModel.toggleValidationIssueFilter()
        renderRuleEditor()
    }

    private func toggleConfigurationWarningFilter() {
        endKeyCapture()
        presentationModel.toggleConfigurationWarningFilter()
        renderRuleEditor()
    }

    @objc
    private func clearAllFilters() {
        endKeyCapture()
        presentationModel.clearAllFilters()
        renderRuleEditor()
    }

    private func makeRulesHeaderView() -> NSView {
        let headerView =
            InteractiveRulesHeaderView(
                frame: .zero
            )

        let arrowSpacer = NSView()
        let removeSpacer = NSView()

        let views: [NSView] = [
            activeHeaderView,
            sourceHeaderButton,
            arrowSpacer,
            destinationHeaderButton,
            behaviorHeaderButton,
            exceptionsHeaderButton,
            reverseHeaderView,
            issuesFilterView,
            removeSpacer
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            headerView.addSubview(
                view
            )
        }

        headerView.translatesAutoresizingMaskIntoConstraints =
            false

        NSLayoutConstraint.activate(
            [
                activeHeaderView.leadingAnchor.constraint(
                    equalTo:
                        headerView.leadingAnchor,
                    constant: 12
                ),

                activeHeaderView.widthAnchor.constraint(
                    equalToConstant: 88
                ),

                activeHeaderView.topAnchor.constraint(
                    equalTo:
                        headerView.topAnchor,
                    constant: 2
                ),

                activeHeaderView.bottomAnchor.constraint(
                    equalTo:
                        headerView.bottomAnchor,
                    constant: -2
                ),

                sourceHeaderButton.leadingAnchor.constraint(
                    equalTo:
                        activeHeaderView.trailingAnchor,
                    constant: 6
                ),

                sourceHeaderButton.topAnchor.constraint(
                    equalTo:
                        headerView.topAnchor,
                    constant: 4
                ),

                sourceHeaderButton.bottomAnchor.constraint(
                    equalTo:
                        headerView.bottomAnchor,
                    constant: -4
                ),

                arrowSpacer.leadingAnchor.constraint(
                    equalTo:
                        sourceHeaderButton
                            .trailingAnchor,
                    constant: 10
                ),

                arrowSpacer.widthAnchor.constraint(
                    equalToConstant: 18
                ),

                destinationHeaderButton.leadingAnchor.constraint(
                    equalTo:
                        arrowSpacer.trailingAnchor,
                    constant: 10
                ),

                destinationHeaderButton.topAnchor.constraint(
                    equalTo:
                        headerView.topAnchor,
                    constant: 4
                ),

                destinationHeaderButton.bottomAnchor.constraint(
                    equalTo:
                        headerView.bottomAnchor,
                    constant: -4
                ),

                behaviorHeaderButton.leadingAnchor.constraint(
                    equalTo:
                        destinationHeaderButton
                            .trailingAnchor,
                    constant: 10
                ),

                behaviorHeaderButton.topAnchor.constraint(
                    equalTo:
                        headerView.topAnchor,
                    constant: 4
                ),

                behaviorHeaderButton.bottomAnchor.constraint(
                    equalTo:
                        headerView.bottomAnchor,
                    constant: -4
                ),

                behaviorHeaderButton.widthAnchor.constraint(
                    equalToConstant: 168
                ),

                exceptionsHeaderButton.leadingAnchor.constraint(
                    equalTo:
                        behaviorHeaderButton
                            .trailingAnchor,
                    constant: 10
                ),

                exceptionsHeaderButton.topAnchor.constraint(
                    equalTo:
                        headerView.topAnchor,
                    constant: 4
                ),

                exceptionsHeaderButton.bottomAnchor.constraint(
                    equalTo:
                        headerView.bottomAnchor,
                    constant: -4
                ),

                exceptionsHeaderButton.widthAnchor.constraint(
                    equalToConstant: 116
                ),

                reverseHeaderView.leadingAnchor.constraint(
                    equalTo:
                        exceptionsHeaderButton
                            .trailingAnchor,
                    constant: 6
                ),

                reverseHeaderView.widthAnchor.constraint(
                    equalToConstant: 88
                ),

                reverseHeaderView.topAnchor.constraint(
                    equalTo:
                        headerView.topAnchor,
                    constant: 2
                ),

                reverseHeaderView.bottomAnchor.constraint(
                    equalTo:
                        headerView.bottomAnchor,
                    constant: -2
                ),

                issuesFilterView.leadingAnchor.constraint(
                    equalTo:
                        reverseHeaderView
                            .trailingAnchor,
                    constant: 6
                ),

                issuesFilterView.widthAnchor.constraint(
                    equalToConstant: 72
                ),

                issuesFilterView.topAnchor.constraint(
                    equalTo:
                        headerView.topAnchor,
                    constant: 4
                ),

                issuesFilterView.bottomAnchor.constraint(
                    equalTo:
                        headerView.bottomAnchor,
                    constant: -4
                ),

                removeSpacer.leadingAnchor.constraint(
                    equalTo:
                        issuesFilterView
                            .trailingAnchor,
                    constant: 6
                ),

                removeSpacer.trailingAnchor.constraint(
                    equalTo:
                        headerView.trailingAnchor,
                    constant: -12
                ),

                removeSpacer.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceHeaderButton.widthAnchor.constraint(
                    equalTo:
                        destinationHeaderButton
                            .widthAnchor
                ),

                sourceHeaderButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        120
                ),

                headerView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        54
                )
            ]
        )

        return headerView
    }

    private func configureSortHeaderButtons() {
        configureSortHeaderButton(
            sourceHeaderButton,
            title: "Source",
            action: #selector(sortBySource)
        )

        configureSortHeaderButton(
            destinationHeaderButton,
            title: "Destination",
            action:
                #selector(sortByDestination)
        )

        configureSortHeaderButton(
            behaviorHeaderButton,
            title: "Modifier behavior",
            action:
                #selector(sortByModifierBehavior)
        )

        configureSortHeaderButton(
            exceptionsHeaderButton,
            title: "Exceptions",
            action:
                #selector(sortByExceptions)
        )

        updateSortHeaderButtons()
    }

    private func configureActiveHeaderView() {
        activeHeaderView.onSortRequested = {
            [weak self] in

            self?.applySorting(
                .active
            )
        }

        activeHeaderView.onGlobalToggleRequested = {
            [weak self] isEnabled in

            self?.setEnabledForAllRules(
                isEnabled
            )
        }
    }

    private func updateActiveHeaderView() {
        let selectionState:
            RulesToggleHeaderView.SelectionState

        switch ruleEditorSession
            .activationSelectionState
        {
        case .unavailable:
            selectionState =
                .unavailable

        case .disabled:
            selectionState =
                .disabled

        case .mixed:
            selectionState =
                .mixed

        case .enabled:
            selectionState =
                .enabled
        }

        activeHeaderView.setSelectionState(
            selectionState
        )
    }

    private func setEnabledForAllRules(
        _ isEnabled: Bool
    ) {
        endKeyCapture()

        ruleEditorSession
            .setEnabledForAll(
                isEnabled
            )
    }

    private func configureReverseHeaderView() {
        reverseHeaderView.onSortRequested = {
            [weak self] in

            self?.applySorting(
                .reverse
            )
        }

        reverseHeaderView.onGlobalToggleRequested = {
            [weak self] isEnabled in

            self?.setBidirectionalForAllRules(
                isEnabled
            )
        }
    }

    private func updateReverseHeaderView() {
        let selectionState:
            RulesToggleHeaderView.SelectionState

        switch ruleEditorSession
            .bidirectionalSelectionState
        {
        case .unavailable:
            selectionState =
                .unavailable

        case .disabled:
            selectionState =
                .disabled

        case .mixed:
            selectionState =
                .mixed

        case .enabled:
            selectionState =
                .enabled
        }

        reverseHeaderView.setSelectionState(
            selectionState
        )
    }

    private func setBidirectionalForAllRules(
        _ isEnabled: Bool
    ) {
        endKeyCapture()

        ruleEditorSession
            .setBidirectionalForAll(
                isEnabled
            )
    }

    private func configureSortHeaderButton(
        _ button: SortableHeaderButton,
        title: String,
        action: Selector
    ) {
        button.title = title
        button.target = self
        button.action = action

        button.setAccessibilityLabel(
            "Sort by \(title)"
        )
    }

    @objc
    private func sortBySource() {
        applySorting(
            .source
        )
    }

    @objc
    private func sortByDestination() {
        applySorting(
            .destination
        )
    }

    @objc
    private func sortByModifierBehavior() {
        applySorting(
            .modifierBehavior
        )
    }

    @objc
    private func sortByExceptions() {
        applySorting(
            .exceptions
        )
    }

    private func applySorting(
        _ column:
            RemappingRulesPresentationModel
                .SortColumn
    ) {
        endKeyCapture()

        presentationModel.selectSortColumn(
            column
        )

        renderRuleEditor()
    }

    private func updateSortHeaderButtons() {
        activeHeaderView.setSortState(
            sortState(
                for: .active
            )
        )

        sourceHeaderButton.setSortState(
            sortState(
                for: .source
            )
        )

        destinationHeaderButton.setSortState(
            sortState(
                for: .destination
            )
        )

        behaviorHeaderButton.setSortState(
            sortState(
                for: .modifierBehavior
            )
        )

        exceptionsHeaderButton.setSortState(
            sortState(
                for: .exceptions
            )
        )

        reverseHeaderView.setSortState(
            sortState(
                for: .reverse
            )
        )

        issuesFilterView.setSortState(
            sortState(
                for: .issues
            )
        )
    }

    private func sortState(
        for column:
            RemappingRulesPresentationModel
                .SortColumn
    ) -> SortableHeaderButton.SortState {
        guard
            let descriptor =
                presentationModel.sortDescriptor,
            descriptor.column == column
        else {
            return .none
        }

        switch descriptor.direction {
        case .ascending:
            return .ascending

        case .descending:
            return .descending
        }
    }

    private func configureRuleRemovalConfirmationPreference() {
        confirmRuleRemovalSwitch.controlSize =
            .small

        // Keep the native macOS switch while making this secondary control
        // slightly more compact than the main remapping switch.
        confirmRuleRemovalSwitch.wantsLayer =
            true

        confirmRuleRemovalSwitch.layer?
            .setAffineTransform(
                CGAffineTransform(
                    scaleX:
                        0.88,
                    y:
                        0.88
                )
            )

        confirmRuleRemovalSwitch.target =
            self

        confirmRuleRemovalSwitch.action =
            #selector(
                ruleRemovalConfirmationPreferenceChanged
            )

        confirmRuleRemovalSwitch.toolTip =
            "Ask for confirmation before removing a remapping rule."

        confirmRuleRemovalSwitch.setAccessibilityLabel(
            "Confirm rule removal"
        )

        confirmRuleRemovalSwitch
            .setContentHuggingPriority(
                .required,
                for:
                    .vertical
            )
    }

    private func synchronizeRuleRemovalConfirmationPreference() {
        confirmRuleRemovalSwitch.state =
            appPreferencesController
                .preferences
                .confirmsRuleRemoval
                    ? .on
                    : .off
    }

    @objc
    private func ruleRemovalConfirmationPreferenceChanged() {
        let previousValue =
            appPreferencesController
                .preferences
                .confirmsRuleRemoval

        let requestedValue =
            confirmRuleRemovalSwitch.state
                == .on

        guard
            ruleRemovalConfirmationController
                .shouldApplyPreferenceChange(
                    from: previousValue,
                    to: requestedValue
                )
        else {
            synchronizeRuleRemovalConfirmationPreference()
            return
        }

        do {
            try appPreferencesController
                .setConfirmsRuleRemoval(
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

    private func configureRulesScrollView() {
        rulesStackView.orientation =
            .vertical

        rulesStackView.alignment =
            .leading

        rulesStackView.distribution =
            .fill

        rulesStackView.translatesAutoresizingMaskIntoConstraints =
            false

        rulesFlexibleSpacer.translatesAutoresizingMaskIntoConstraints =
            false

        rulesFlexibleSpacer
            .setContentHuggingPriority(
                .defaultLow,
                for: .vertical
            )

        rulesFlexibleSpacer
            .setContentCompressionResistancePriority(
                .defaultLow,
                for: .vertical
            )

        rulesStackView.addArrangedSubview(
            rulesFlexibleSpacer
        )

        rulesDocumentView.translatesAutoresizingMaskIntoConstraints =
            false

        rulesDocumentView.addSubview(
            rulesStackView
        )

        rulesScrollView.hasVerticalScroller =
            true

        rulesScrollView.autohidesScrollers =
            true

        rulesScrollView.borderType =
            .bezelBorder

        rulesScrollView.drawsBackground =
            false

        rulesScrollView.documentView =
            rulesDocumentView

        rulesScrollView.translatesAutoresizingMaskIntoConstraints =
            false

        rulesScrollView
            .setContentHuggingPriority(
                .defaultLow,
                for: .vertical
            )

        rulesScrollView
            .setContentCompressionResistancePriority(
                .defaultLow,
                for: .vertical
            )

        NSLayoutConstraint.activate(
            [
                rulesStackView.topAnchor.constraint(
                    equalTo:
                        rulesDocumentView.topAnchor,
                    constant: 12
                ),

                rulesStackView.leadingAnchor.constraint(
                    equalTo:
                        rulesDocumentView
                            .leadingAnchor,
                    constant: 12
                ),

                rulesStackView.trailingAnchor.constraint(
                    equalTo:
                        rulesDocumentView
                            .trailingAnchor,
                    constant: -12
                ),

                rulesStackView.bottomAnchor.constraint(
                    equalTo:
                        rulesDocumentView
                            .bottomAnchor,
                    constant: -12
                ),

                rulesFlexibleSpacer.widthAnchor.constraint(
                    equalTo:
                        rulesStackView.widthAnchor
                ),

                rulesFlexibleSpacer.heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        0
                ),

                rulesDocumentView.widthAnchor.constraint(
                    equalTo:
                        rulesScrollView
                            .contentView
                            .widthAnchor
                ),

                rulesDocumentView.heightAnchor.constraint(
                    greaterThanOrEqualTo:
                        rulesScrollView
                            .contentView
                            .heightAnchor
                ),

                rulesScrollView.heightAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        260
                )
            ]
        )
    }

    private func configureActionButtons() {
        addRuleButton.title =
            "Add Rule"

        addRuleButton.image =
            NSImage(
                systemSymbolName: "plus",
                accessibilityDescription:
                    "Add Rule"
            )

        addRuleButton.imagePosition =
            .imageLeading

        addRuleButton.bezelStyle =
            .rounded

        addRuleButton.target =
            self

        addRuleButton.action =
            #selector(addEmptyRule)

        undoButton.title =
            "Undo"

        undoButton.image =
            NSImage(
                systemSymbolName:
                    "arrow.uturn.backward",
                accessibilityDescription:
                    "Undo"
            )

        undoButton.imagePosition =
            .imageLeading

        undoButton.bezelStyle =
            .rounded

        undoButton.target =
            self

        undoButton.action =
            #selector(undoButtonPressed)

        undoButton.toolTip =
            "Undo the last rule editor change (Command-Z)."

        redoButton.title =
            "Redo"

        redoButton.image =
            NSImage(
                systemSymbolName:
                    "arrow.uturn.forward",
                accessibilityDescription:
                    "Redo"
            )

        redoButton.imagePosition =
            .imageLeading

        redoButton.bezelStyle =
            .rounded

        redoButton.target =
            self

        redoButton.action =
            #selector(redoButtonPressed)

        redoButton.toolTip =
            "Redo the last undone rule editor change (Shift-Command-Z)."

        saveButton.title =
            "Save Rules"

        saveButton.bezelStyle =
            .rounded

        saveButton.keyEquivalent =
            "\r"

        saveButton.target =
            self

        saveButton.action =
            #selector(saveRules)

        let spacer = NSView()

        spacer.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        spacer.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        actionsStack.setViews(
            [
                addRuleButton,
                undoButton,
                redoButton,
                saveButton,
                spacer,
                textSizeLabel,
                decreaseTextSizeButton,
                resetTextSizeButton,
                increaseTextSizeButton
            ],
            in: .leading
        )

        actionsStack.orientation =
            .horizontal

        actionsStack.alignment =
            .centerY

        actionsStack.distribution =
            .fill

        actionsStack.translatesAutoresizingMaskIntoConstraints =
            false

        updateRuleEditorHistoryControls()
    }

    private func configureTextSizeControls() {
        decreaseTextSizeButton.title =
            "−"

        decreaseTextSizeButton.bezelStyle =
            .rounded

        decreaseTextSizeButton.target =
            self

        decreaseTextSizeButton.action =
            #selector(
                decreaseTextSizeButtonPressed
            )

        decreaseTextSizeButton.toolTip =
            "Decrease application text size."

        resetTextSizeButton.title =
            "Reset"

        resetTextSizeButton.bezelStyle =
            .rounded

        resetTextSizeButton.target =
            self

        resetTextSizeButton.action =
            #selector(
                resetTextSizeButtonPressed
            )

        resetTextSizeButton.toolTip =
            "Restore the default application text size."

        increaseTextSizeButton.title =
            "+"

        increaseTextSizeButton.bezelStyle =
            .rounded

        increaseTextSizeButton.target =
            self

        increaseTextSizeButton.action =
            #selector(
                increaseTextSizeButtonPressed
            )

        increaseTextSizeButton.toolTip =
            "Increase application text size."
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

    private func initializeRuleEditorSession() {
        guard
            !ruleEditorSession.isInitialized
        else {
            renderRuleEditor()
            return
        }

        do {
            let rules =
                try remappingController
                    .loadConfiguredRules()

            ruleEditorSession.initialize(
                with: rules
            )
        } catch {
            ruleEditorSession.initialize(
                with: []
            )

            setStatus(
                "The configured rules could not be loaded.",
                isError: true
            )

            saveButton.isEnabled =
                false
        }
    }

    /// Rebuilds only the visual rows from session-owned state. Persistent
    /// rules are never loaded here, so closing and reopening this window
    /// cannot erase Undo or Redo history.
    private func renderRuleEditor() {
        endKeyCapture()
        removeAllRuleRows()
        updateSortHeaderButtons()
        updateActiveHeaderView()
        updateReverseHeaderView()
        updateFilterControls()

        let validationSnapshot =
            validationSnapshot()

        let warningAssessment =
            RemappingConfigurationWarningAssessment(
                items:
                    ruleEditorSession.items
            )

        let visibleItems =
            presentationModel.visibleItems(
                from:
                    ruleEditorSession.items,
                validationIssueItemIDs:
                    validationSnapshot.invalidItemIDs,
                configurationWarningItemIDs:
                    warningAssessment
                        .affectedRuleIDs
                        .union(
                            validationSnapshot
                                .shortcutWarningItemIDs
                        )
            )

        updateFilterSummary(
            visibleCount:
                visibleItems.count
        )

        for item in visibleItems {
            addRuleRow(
                item: item
            )
        }

        refreshChangeState()

        window?.contentView?.needsLayout =
            true
    }

    private func addRuleRow(
        item: RemappingRuleEditorItem
    ) {
        let row =
            RemappingRuleRowView(
                item: item
            )

        row.applyTextScale(
            textScale
        )

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

            self?.showExceptions(
                for: row
            )
        }

        row.onRemoveRequested = {
            [weak self, weak row] in

            guard let row else {
                return
            }

            self?.requestRuleRemoval(
                row
            )
        }

        row.onMatchingModeChangeRejected = {
            [weak self] issue in

            self?.setStatus(
                issue.message,
                isError: true
            )
        }

        row.onRuleChanged = {
            [weak self] updatedItem in

            self?.ruleEditorSession
                .updateItem(
                    updatedItem
                )
        }

        ruleRows.append(
            row
        )

        ruleRowsByItemID[
            item.id
        ] = row

        let insertionIndex =
            max(
                rulesStackView
                    .arrangedSubviews
                    .count - 1,
                0
            )

        rulesStackView.insertArrangedSubview(
            row,
            at: insertionIndex
        )

        row.translatesAutoresizingMaskIntoConstraints =
            false

        row.widthAnchor.constraint(
            equalTo:
                rulesStackView.widthAnchor
        ).isActive = true
    }

    private func showExceptions(
        for row: RemappingRuleRowView
    ) {
        endKeyCapture()

        guard
            exceptionsWindowController == nil,
            let parentWindow = window,
            let rule = row.rule
        else {
            return
        }

        let editorItemID =
            row.editorItemID

        let controller =
            RemapOverridesWindowController(
                parentWindow:
                    parentWindow,
                rule:
                    rule,
                remappingController:
                    remappingController,
                textScale:
                    textScale,
                validateCandidateOverrides: {
                    [weak self] candidateOverrides in

                    self?.validateCandidateOverrides(
                        candidateOverrides,
                        replacingOverridesFor:
                            editorItemID
                    )
                },
                shortcutConfigurationProvider: {
                    [weak self] in

                    self?
                        .globalShortcutController
                        .configuredConfiguration
                    ?? .disabled
                },
                beginGlobalShortcutCapture: {
                    [weak self] in

                    self?
                        .globalShortcutController
                        .beginShortcutCapture()
                },
                endGlobalShortcutCapture: {
                    [weak self] in

                    guard let self else {
                        return
                    }

                    try self
                        .globalShortcutController
                        .endShortcutCapture()
                },
                onSave: {
                    [weak row] overrides in

                    row?.setOverrides(
                        overrides
                    )
                },
                onClose: {
                    [weak self] in

                    self?.exceptionsWindowController =
                        nil

                    self?.updateRuleEditorHistoryControls()
                }
            )

        exceptionsWindowController =
            controller

        updateRuleEditorHistoryControls()

        controller.showAsSheet()
    }

    private func validateCandidateOverrides(
        _ candidateOverrides: [RemapOverride],
        replacingOverridesFor editorItemID: UUID
    ) -> String? {
        var replacedTargetItem =
            false

        let candidateRules =
            ruleEditorSession
                .items
                .compactMap {
                    item -> RemapRule? in

                    var candidateItem =
                        item

                    if candidateItem.id
                        == editorItemID
                    {
                        candidateItem.overrides =
                            candidateOverrides

                        replacedTargetItem =
                            true
                    }

                    return candidateItem.rule
                }

        guard replacedTargetItem else {
            return "The parent remapping rule is no longer available."
        }

        do {
            try RemappingRulesValidator()
                .validate(
                    candidateRules
                )

            return nil
        } catch let error
            as RemappingRulesValidationError
        {
            return candidateOverrideValidationMessage(
                for: error
            )
        } catch {
            return "The candidate exceptions could not be validated."
        }
    }

    private func candidateOverrideValidationMessage(
        for error:
            RemappingRulesValidationError
    ) -> String {
        switch error {
        case .duplicateSourceKey,
             .duplicateSourceCombination:
            return "This exception cannot be enabled because its source combination conflicts with an active exact rule or another enabled exception."

        case .duplicatePreservingSourceKey:
            return "The current rules contain more than one Preserve Modifiers rule for the same source key."

        case .identicalSourceAndDestination,
             .identicalSourceAndDestinationCombination:
            return "An exception cannot replace a source combination with itself."

        case .invalidModifierPreservingEndpoints:
            return "A Preserve Modifiers rule must use source and destination keys without modifiers."

        case .overridesRequireModifierPreservingRule:
            return "Stored exceptions are allowed in both matching modes, but they are active only in Preserve Modifiers."

        case .overrideSourceKeyMismatch:
            return "Every exception must use the same physical source key as its parent rule."
        }
    }

    private func scrollToRuleRow(
        _ row: RemappingRuleRowView
    ) {
        rulesDocumentView
            .layoutSubtreeIfNeeded()

        rulesStackView
            .layoutSubtreeIfNeeded()

        let visibleRect =
            row.convert(
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

        guard
            ruleRemovalConfirmationController
                .shouldRemoveRule(
                    confirmationRequired:
                        confirmationRequired
                )
        else {
            return
        }

        if captureRow === row {
            endKeyCapture()
        }

        ruleEditorSession.removeItem(
            id: row.editorItemID
        )
    }

    private func removeAllRuleRows() {
        for row in ruleRows {
            rulesStackView
                .removeArrangedSubview(
                    row
                )

            row.removeFromSuperview()
        }

        ruleRows.removeAll()
        ruleRowsByItemID.removeAll()
    }

    @objc
    private func addEmptyRule() {
        if presentationModel.hasActiveFilters {
            presentationModel.clearAllFilters()
        }

        let itemID =
            ruleEditorSession
                .insertEmptyItem()

        if let row =
            ruleRowsByItemID[itemID]
        {
            scrollToRuleRow(
                row
            )
        }
    }

    private func beginRuleKeyCapture(
        in row: RemappingRuleRowView,
        field:
            RemappingRuleRowView.KeyField
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

        row.showCapturePrompt(
            for: field
        )

        updateRuleEditorHistoryControls()

        if row.matchingMode
            == .preserveModifiers
        {
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

    private func beginCaptureSession() {
        fnModifierStateTracker.synchronize(
            isPressed:
                PhysicalFnKeyState
                    .isPressed()
        )

        nonFnModifierStateTracker.synchronize(
            currentModifiers:
                KeyModifiers(
                    appKitFlags:
                        NSEvent.modifierFlags
                )
        )

        remappingController
            .beginKeyCapture()

        globalShortcutController
            .beginShortcutCapture()
    }

    private func handleFlagsChanged(
        _ event: NSEvent
    ) {
        guard isCapturingAnyKey else {
            return
        }

        var currentModifiers =
            KeyModifiers(
                appKitFlags:
                    NSEvent.modifierFlags
            )

        currentModifiers.formUnion(
            KeyModifiers(
                appKitFlags:
                    event.modifierFlags
            )
        )

        currentModifiers.remove(
            .fn
        )

        nonFnModifierStateTracker
            .handleFlagsChanged(
                keyCode:
                    CGKeyCode(
                        event.keyCode
                    ),
                currentModifiers:
                    currentModifiers
            )

        guard
            event.keyCode
                == UInt16(kVK_Function)
        else {
            return
        }

        fnModifierStateTracker
            .handleFlagsChanged(
                isPressed:
                    PhysicalFnKeyState
                        .isPressed()
                    || event.modifierFlags
                        .contains(
                            .function
                        )
            )
    }

    private func handleKeyDown(
        _ event: NSEvent
    ) -> Bool {
        guard isCapturingAnyKey else {
            return false
        }

        if event.keyCode
            == UInt16(kVK_Escape)
        {
            endKeyCapture()
            refreshChangeState()

            return true
        }

        let combination =
            keyCombination(
                from: event
            )

        if let captureFilterField {
            switch captureFilterField {
            case .source:
                presentationModel.setSourceFilter(
                    combination
                )

            case .destination:
                presentationModel.setDestinationFilter(
                    combination
                )
            }

            endKeyCapture()
            renderRuleEditor()

            return true
        }

        guard
            let captureRow,
            let captureField
        else {
            endKeyCapture()
            return true
        }

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
        var capturedNonFnModifiers =
            nonFnModifierStateTracker
                .modifiers

        capturedNonFnModifiers.formUnion(
            KeyModifiers(
                appKitFlags:
                    NSEvent.modifierFlags
            )
        )

        capturedNonFnModifiers.remove(
            .fn
        )

        return KeyCombinationInputNormalizer
            .capturedCombination(
                deliveredKeyCode:
                    CGKeyCode(
                        event.keyCode
                    ),
                eventModifiers:
                    KeyModifiers(
                        appKitFlags:
                            event
                                .modifierFlags
                    ),
                capturedNonFnModifiers:
                    capturedNonFnModifiers,
                trackedPhysicalFnIsPressed:
                    fnModifierStateTracker
                        .isPressed
            )
    }

    private var isCapturingAnyKey: Bool {
        captureRow != nil
            || captureFilterField != nil
    }

    private func endKeyCapture() {
        guard isCapturingAnyKey else {
            return
        }

        captureRow?
            .restoreButtonTitles()

        captureRow = nil
        captureField = nil
        captureFilterField = nil

        updateFilterControls()

        do {
            try globalShortcutController
                .endShortcutCapture()
        } catch {
            setStatus(
                "The previous global shortcut could not be restored after key capture.",
                isError: true
            )
        }

        remappingController
            .endKeyCapture()

        fnModifierStateTracker
            .reset()

        nonFnModifierStateTracker
            .reset()

        updateRuleEditorHistoryControls()
    }

    private var canUndoRuleEditorChange:
        Bool
    {
        !isCapturingAnyKey
            && exceptionsWindowController == nil
            && ruleEditorSession.canUndo
    }

    private var canRedoRuleEditorChange:
        Bool
    {
        !isCapturingAnyKey
            && exceptionsWindowController == nil
            && ruleEditorSession.canRedo
    }

    @objc
    private func undoButtonPressed() {
        undoRuleEditorChange()
    }

    @objc
    private func redoButtonPressed() {
        redoRuleEditorChange()
    }

    private func undoRuleEditorChange() {
        guard
            canUndoRuleEditorChange
        else {
            return
        }

        ruleEditorSession.undo()
    }

    private func redoRuleEditorChange() {
        guard
            canRedoRuleEditorChange
        else {
            return
        }

        ruleEditorSession.redo()
    }

    private func updateRuleEditorHistoryControls() {
        undoButton.isEnabled =
            canUndoRuleEditorChange

        redoButton.isEnabled =
            canRedoRuleEditorChange
    }

    private func validationSnapshot()
        -> ValidationSnapshot
    {
        let items =
            ruleEditorSession
                .items

        let assessment =
            RemappingRulesValidationAssessment(
                items:
                    items
            )

        let shortcutConfiguration =
            appPreferencesController
                .preferences
                .shortcutConfiguration

        var shortcutConflicts:
            [
                (
                    itemID: UUID,
                    conflict:
                        RemappingShortcutRuleConflict
                )
            ] = []

        var shortcutWarnings:
            [
                (
                    itemID: UUID,
                    warning:
                        RemappingShortcutRuleWarning
                )
            ] = []

        for (
            ruleIndex,
            item
        ) in items.enumerated() {
            guard
                let rule =
                    item.rule
            else {
                continue
            }

            for registration in
                shortcutConfiguration
                    .registrations
            {
                if RemappingShortcutRuleConflictPolicy
                    .hasBlockingConflict(
                        registration.shortcut,
                        rule:
                            rule
                    )
                {
                    shortcutConflicts.append(
                        (
                            itemID:
                                item.id,
                            conflict:
                                RemappingShortcutRuleConflict(
                                    ruleIndex:
                                        ruleIndex,
                                    action:
                                        registration.action,
                                    shortcut:
                                        registration.shortcut
                                )
                        )
                    )

                    continue
                }

                if RemappingShortcutRuleConflictPolicy
                    .producesPreserveWarning(
                        registration.shortcut,
                        rule:
                            rule
                    )
                {
                    shortcutWarnings.append(
                        (
                            itemID:
                                item.id,
                            warning:
                                RemappingShortcutRuleWarning(
                                    ruleIndex:
                                        ruleIndex,
                                    action:
                                        registration.action,
                                    shortcut:
                                        registration.shortcut
                                )
                        )
                    )
                }
            }
        }

        let issue:
            EditorValidationIssue?

        if let primaryIssue =
            assessment.primaryIssue
        {
            switch primaryIssue {
            case .duplicateSource:
                issue =
                    .duplicateSource

            case .identicalSourceAndDestination:
                issue =
                    .identicalSourceAndDestination

            case .incompleteRule:
                issue =
                    .incompleteRule
            }
        } else if let firstShortcutConflict =
            shortcutConflicts.first
        {
            issue =
                .shortcutConflict(
                    firstShortcutConflict
                        .conflict
                        .action
                )
        } else {
            issue =
                nil
        }

        var messagesByItemID:
            [UUID: String] =
                Dictionary(
                    uniqueKeysWithValues:
                        assessment
                            .invalidItemIDs
                            .compactMap {
                                itemID
                                    -> (UUID, String)? in

                                guard
                                    let message =
                                        assessment.message(
                                            forRuleID:
                                                itemID
                                        )
                                else {
                                    return nil
                                }

                                return (
                                    itemID,
                                    message
                                )
                            }
                )

        for shortcutConflict in
            shortcutConflicts
        {
            let itemID =
                shortcutConflict
                    .itemID

            let conflictMessage =
                shortcutConflict
                    .conflict
                    .message

            if let existingMessage =
                messagesByItemID[
                    itemID
                ],
               !existingMessage.isEmpty
            {
                messagesByItemID[
                    itemID
                ] =
                    existingMessage
                    + "\n"
                    + conflictMessage
            } else {
                messagesByItemID[
                    itemID
                ] =
                    conflictMessage
            }
        }

        let shortcutConflictItemIDs =
            Set(
                shortcutConflicts.map {
                    $0.itemID
                }
            )

        var shortcutWarningMessagesByItemID:
            [UUID: String] = [:]

        for shortcutWarning in
            shortcutWarnings
        {
            let itemID =
                shortcutWarning
                    .itemID

            let warning =
                shortcutWarning
                    .warning

            let shortcutName =
                KeyCombinationDisplayName
                    .name(
                        for:
                            warning.shortcut
                    )

            let warningMessage =
                "\(shortcutName) is reserved for \(warning.shortcutTitle) and will \(warning.reservedBehaviorDescription) instead of being remapped by this Preserve Modifiers rule."

            if let existingMessage =
                shortcutWarningMessagesByItemID[
                    itemID
                ],
               !existingMessage.isEmpty
            {
                shortcutWarningMessagesByItemID[
                    itemID
                ] =
                    existingMessage
                    + "\n"
                    + warningMessage
            } else {
                shortcutWarningMessagesByItemID[
                    itemID
                ] =
                    warningMessage
            }
        }

        let shortcutWarningItemIDs =
            Set(
                shortcutWarnings.map {
                    $0.itemID
                }
            )

        let primaryShortcutWarningMessage:
            String?

        if let firstShortcutWarning =
            shortcutWarnings.first
        {
            let warning =
                firstShortcutWarning
                    .warning

            let shortcutName =
                KeyCombinationDisplayName
                    .name(
                        for:
                            warning.shortcut
                    )

            primaryShortcutWarningMessage =
                "\(shortcutName) is reserved for \(warning.shortcutTitle) and will \(warning.reservedBehaviorDescription) instead of being remapped by the matching Preserve Modifiers rule."
        } else {
            primaryShortcutWarningMessage =
                nil
        }

        return ValidationSnapshot(
            issue:
                issue,
            invalidItemIDs:
                assessment
                    .invalidItemIDs
                    .union(
                        shortcutConflictItemIDs
                    ),
            messagesByItemID:
                messagesByItemID,
            shortcutWarningItemIDs:
                shortcutWarningItemIDs,
            shortcutWarningMessagesByItemID:
                shortcutWarningMessagesByItemID,
            primaryShortcutWarningMessage:
                primaryShortcutWarningMessage
        )
    }

    private func applyValidationAppearance(
        _ snapshot: ValidationSnapshot
    ) {
        for (
            itemID,
            row
        ) in ruleRowsByItemID {
            row.setValidationIssueMessage(
                snapshot.messagesByItemID[
                    itemID
                ]
            )
        }
    }

    private func applyWarningPresentation(
        _ assessment:
            RemappingConfigurationWarningAssessment,
        validationSnapshot:
            ValidationSnapshot
    ) {
        warningBanner.setWarning(
            assessment.warning
        )

        for (
            itemID,
            row
        ) in ruleRowsByItemID {
            var warningMessages:
                [String] = []

            if assessment.affectsRule(
                id:
                    itemID
            ),
               let warning =
                    assessment.warning
            {
                warningMessages.append(
                    warning.message
                )
            }

            if let shortcutWarningMessage =
                validationSnapshot
                    .shortcutWarningMessagesByItemID[
                        itemID
                    ]
            {
                warningMessages.append(
                    shortcutWarningMessage
                )
            }

            row.setConfigurationWarningMessage(
                warningMessages.isEmpty
                    ? nil
                    : warningMessages.joined(
                        separator:
                            "\n"
                    )
            )
        }
    }

    private func refreshChangeState() {
        updateActiveHeaderView()
        updateReverseHeaderView()

        let validationSnapshot =
            validationSnapshot()

        let warningAssessment =
            RemappingConfigurationWarningAssessment(
                items:
                    ruleEditorSession.items
            )

        applyValidationAppearance(
            validationSnapshot
        )

        applyWarningPresentation(
            warningAssessment,
            validationSnapshot:
                validationSnapshot
        )

        updateRuleEditorHistoryControls()

        let hasChanges =
            ruleEditorSession
                .hasUnsavedChanges

        saveButton.isEnabled =
            validationSnapshot.issue == nil
                && hasChanges

        if let issue =
            validationSnapshot.issue
        {
            setStatus(
                issue.message,
                isError: true
            )

            return
        }

        if let shortcutWarningMessage =
            validationSnapshot
                .primaryShortcutWarningMessage
        {
            let statusMessage =
                hasChanges
                    ? "You have unsaved rule changes. "
                        + shortcutWarningMessage
                    : shortcutWarningMessage

            setStatus(
                statusMessage,
                isError:
                    false
            )

            return
        }

        if !hasChanges {
            if ruleEditorSession
                .savedRules
                .isEmpty
            {
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
        let snapshot =
            validationSnapshot()

        applyValidationAppearance(
            snapshot
        )

        if let issue =
            snapshot.issue
        {
            setStatus(
                issue.message,
                isError: true
            )

            return false
        }

        guard
            let rules =
                ruleEditorSession
                    .completeRules
        else {
            setStatus(
                "Complete every highlighted rule before saving.",
                isError: true
            )

            return false
        }

        do {
            try remappingController
                .replaceConfiguredRules(
                    rules
                )

            ruleEditorSession
                .markCurrentRulesAsSaved(
                    rules
                )

            NotificationCenter.default.post(
                name:
                    AppConfigurationNotification
                        .remappingRulesDidChange,
                object:
                    nil
            )

            refreshChangeState()

            return true
        } catch let conflict
            as RemappingShortcutRuleConflict
        {
            setStatus(
                conflict.message,
                isError:
                    true
            )

            return false
        } catch let error
            as RemappingRulesValidationError
        {

            switch error {
            case .duplicateSourceKey,
                 .duplicateSourceCombination,
                 .duplicatePreservingSourceKey:
                setStatus(
                    "Each active source key or key combination can appear only once.",
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
                    "Stored exceptions are allowed in both matching modes, but they are active only in Preserve Modifiers.",
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
        statusView.setMessage(
            message,
            isError:
                isError
        )
    }

}
