//
//  RemappingRuleRowView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import AppKit
import CoreGraphics

/// Displays and edits one remapping rule editor item.
@MainActor
final class RemappingRuleRowView: NSView, NSMenuDelegate {
    @MainActor
    private final class BehaviorMenuItemView: NSView {
        private let checkmarkLabel = NSTextField(labelWithString: "")
        private let titleLabel = NSTextField(labelWithString: "")
        private let examplesLabel = NSTextField(wrappingLabelWithString: "")

        private var trackingAreaReference: NSTrackingArea?
        private var isHovered = false {
            didSet {
                guard oldValue != isHovered else {
                    return
                }

                updateAppearance()
                needsDisplay = true
            }
        }

        var onActivate: (() -> Void)?

        var isSelected = false {
            didSet {
                updateAppearance()
            }
        }

        init(title: String) {
            super.init(
                frame: NSRect(
                    x: 0,
                    y: 0,
                    width: 390,
                    height: 118
                )
            )

            titleLabel.stringValue = title
            configureContent()
            updateAppearance()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Makes the complete custom menu item behave as one clickable area.
        /// Text labels never become separate hit-test targets.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard !isHidden, alphaValue > 0 else {
                return nil
            }

            return bounds.contains(point) ? self : nil
        }

        /// Keeps the normal pointer over the entire menu item instead of
        /// showing an insertion cursor over its text labels.
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .arrow)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            guard isHovered else {
                return
            }

            NSColor.selectedContentBackgroundColor.setFill()

            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 4, dy: 3),
                xRadius: 6,
                yRadius: 6
            ).fill()
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingAreaReference {
                removeTrackingArea(trackingAreaReference)
            }

            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [
                    .activeAlways,
                    .mouseEnteredAndExited,
                    .cursorUpdate
                ],
                owner: self,
                userInfo: nil
            )

            addTrackingArea(trackingArea)
            trackingAreaReference = trackingArea
        }

        override func mouseEntered(with event: NSEvent) {
            NSCursor.arrow.set()
            isHovered = true
        }

        override func cursorUpdate(with event: NSEvent) {
            NSCursor.arrow.set()
        }

        override func mouseExited(with event: NSEvent) {
            isHovered = false
        }

        override func mouseUp(with event: NSEvent) {
            guard bounds.contains(
                convert(event.locationInWindow, from: nil)
            ) else {
                return
            }

            enclosingMenuItem?.menu?.cancelTracking()
            onActivate?()
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateAppearance()
            needsDisplay = true
        }

        func setExamples(_ examples: [String]) {
            examplesLabel.stringValue = examples.joined(separator: "\n")
        }

        func applyTextScale(_ scale: CGFloat) {
            titleLabel.font = NSFont.systemFont(
                ofSize: 14 * scale,
                weight: .semibold
            )

            examplesLabel.font = NSFont.systemFont(
                ofSize: 12 * scale,
                weight: .regular
            )

            checkmarkLabel.font = NSFont.systemFont(
                ofSize: 14 * scale,
                weight: .semibold
            )

            frame.size = NSSize(
                width: 390 * scale,
                height: 118 * scale
            )

            needsLayout = true
        }

        private func configureContent() {
            for label in [
                checkmarkLabel,
                titleLabel,
                examplesLabel
            ] {
                label.isEditable = false
                label.isSelectable = false
                label.isBezeled = false
                label.drawsBackground = false
                label.focusRingType = .none
                label.allowsEditingTextAttributes = false
            }

            checkmarkLabel.alignment = .center
            titleLabel.lineBreakMode = .byTruncatingTail
            examplesLabel.maximumNumberOfLines = 4
            examplesLabel.lineBreakMode = .byTruncatingTail

            let views: [NSView] = [
                checkmarkLabel,
                titleLabel,
                examplesLabel
            ]

            for view in views {
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
            }

            NSLayoutConstraint.activate(
                [
                    checkmarkLabel.leadingAnchor.constraint(
                        equalTo: leadingAnchor,
                        constant: 12
                    ),
                    checkmarkLabel.topAnchor.constraint(
                        equalTo: topAnchor,
                        constant: 12
                    ),
                    checkmarkLabel.widthAnchor.constraint(
                        equalToConstant: 18
                    ),
                    titleLabel.leadingAnchor.constraint(
                        equalTo: checkmarkLabel.trailingAnchor,
                        constant: 8
                    ),
                    titleLabel.trailingAnchor.constraint(
                        equalTo: trailingAnchor,
                        constant: -14
                    ),
                    titleLabel.topAnchor.constraint(
                        equalTo: topAnchor,
                        constant: 10
                    ),
                    examplesLabel.leadingAnchor.constraint(
                        equalTo: titleLabel.leadingAnchor
                    ),
                    examplesLabel.trailingAnchor.constraint(
                        equalTo: titleLabel.trailingAnchor
                    ),
                    examplesLabel.topAnchor.constraint(
                        equalTo: titleLabel.bottomAnchor,
                        constant: 4
                    ),
                    examplesLabel.bottomAnchor.constraint(
                        lessThanOrEqualTo: bottomAnchor,
                        constant: -10
                    )
                ]
            )

            applyTextScale(1.0)
        }

        private func updateAppearance() {
            checkmarkLabel.stringValue = isSelected ? "✓" : ""

            let primaryColor: NSColor
            let secondaryColor: NSColor

            if isHovered {
                primaryColor = .selectedControlTextColor
                secondaryColor = .selectedControlTextColor
            } else {
                primaryColor = .labelColor
                secondaryColor = .secondaryLabelColor
            }

            checkmarkLabel.textColor = primaryColor
            titleLabel.textColor = primaryColor
            examplesLabel.textColor = secondaryColor
        }
    }

    enum KeyField: Equatable {
        case source
        case destination
    }

    var onSourceKeyRequested: (() -> Void)?
    var onDestinationKeyRequested: (() -> Void)?
    var onExceptionsRequested: (() -> Void)?
    var onRemoveRequested: (() -> Void)?

    var onMatchingModeChangeRequested:
        ((RemappingRuleEditorItem) -> Bool)?

    var onMatchingModeChangeRejected:
        ((RemappingRuleEditorItem.MatchingModeTransitionIssue) -> Void)?

    var onRuleChanged: ((RemappingRuleEditorItem) -> Void)?

    private enum LayoutMetrics {
        static let horizontalInset: CGFloat = 6
        static let verticalInset: CGFloat = 4
        static let activeColumnWidth: CGFloat = 88
        static let sourceLeadingSpacing: CGFloat = 6
        static let keyArrowSpacing: CGFloat = 10
        static let arrowWidth: CGFloat = 18

        /// Gives the glyph a wider drawing frame by borrowing only from the
        /// existing empty spacing on both sides of the logical arrow column.
        /// Neighboring controls keep exactly the same positions.
        static let arrowDrawingWidth: CGFloat = 30

        static let destinationBehaviorSpacing: CGFloat = 10
        static let behaviorWidth: CGFloat = 168
        static let behaviorExceptionsSpacing: CGFloat = 10
        static let exceptionsWidth: CGFloat = 116
        static let compactColumnSpacing: CGFloat = 6
        static let reverseColumnWidth: CGFloat = 88
        static let issuesColumnWidth: CGFloat = 72
        static let removeButtonWidth: CGFloat = 82

        /// The fixed width consumed by every column except Source and
        /// Destination. The remaining space is split equally between them.
        static let nonKeyColumnWidth: CGFloat = 708
    }

    private let activationSwitch = NSSwitch()

    private let sourceKeyButton = NSButton()
    private let arrowLabel = NSTextField(labelWithString: "→")
    private let destinationKeyButton = NSButton()
    private let behaviorPopUpButton = NSPopUpButton()

    /// Heavy custom menu previews are created only while the menu is open.
    /// Reusable table rows therefore retain only the native popup itself.
    private var exactBehaviorMenuView: BehaviorMenuItemView?
    private var preserveBehaviorMenuView: BehaviorMenuItemView?

    private let exceptionsButton = NSButton()

    private let bidirectionalSwitch = NSSwitch()

    private let issuesView = RemappingRuleIssuesView()
    private let removeButton = NSButton()

    private var isShowingValidationError = false
    private var textScale: CGFloat = 1.0
    private var hasAppliedTextScale = false

    private var activationSwitchFittingSize = NSSize.zero
    private var bidirectionalSwitchFittingSize = NSSize.zero
    private var behaviorControlHeight: CGFloat = 0
    private var exceptionsControlHeight: CGFloat = 0
    private var removeControlHeight: CGFloat = 0
    private var arrowControlHeight: CGFloat = 0

    private(set) var editorItemID: UUID

    private(set) var isEnabled: Bool
    private(set) var sourceCombination: KeyCombination?
    private(set) var destinationCombination: KeyCombination?
    private(set) var matchingMode: RemapMatchingMode
    private(set) var overrides: [RemapOverride]
    private(set) var isBidirectional: Bool

    private var rememberedExactSourceCombination: KeyCombination?
    private var rememberedExactDestinationCombination: KeyCombination?

    var sourceKeyCode: CGKeyCode? {
        sourceCombination?.keyCode
    }

    var destinationKeyCode: CGKeyCode? {
        destinationCombination?.keyCode
    }

    var editorItem: RemappingRuleEditorItem {
        RemappingRuleEditorItem(
            id: editorItemID,
            sourceCombination: sourceCombination,
            destinationCombination: destinationCombination,
            matchingMode: matchingMode,
            overrides: overrides,
            isEnabled: isEnabled,
            isBidirectional: isBidirectional,
            rememberedExactSourceCombination:
                rememberedExactSourceCombination,
            rememberedExactDestinationCombination:
                rememberedExactDestinationCombination
        )
    }

    var rule: RemapRule? {
        editorItem.rule
    }

    init(item: RemappingRuleEditorItem) {
        editorItemID = item.id
        isEnabled = item.isEnabled
        sourceCombination = item.sourceCombination
        destinationCombination = item.destinationCombination
        matchingMode = item.matchingMode
        overrides = item.overrides
        isBidirectional = item.isBidirectional
        rememberedExactSourceCombination =
            item.rememberedExactSourceCombination
        rememberedExactDestinationCombination =
            item.rememberedExactDestinationCombination

        super.init(frame: .zero)

        configureContent()
        updateControls()
        updateValidationAppearance()
    }

    convenience init(rule: RemapRule? = nil) {
        if let rule {
            self.init(
                item: RemappingRuleEditorItem(rule: rule)
            )
        } else {
            self.init(item: RemappingRuleEditorItem())
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateValidationAppearance()
    }

    override func draw(
        _ dirtyRect: NSRect
    ) {
        super.draw(
            dirtyRect
        )

        guard
            isShowingValidationError
        else {
            return
        }

        let borderInset: CGFloat = 0.75
        let path =
            NSBezierPath(
                roundedRect:
                    bounds.insetBy(
                        dx: borderInset,
                        dy: borderInset
                    ),
                xRadius: 8,
                yRadius: 8
            )

        NSColor.systemRed
            .withAlphaComponent(
                0.08
            )
            .setFill()

        path.fill()

        NSColor.systemRed.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    override func layout() {
        super.layout()
        layoutControls()
    }

    /// Rebinds this existing row hierarchy to another editor item.
    ///
    /// `NSTableView` may recycle an off-screen cell for a different visible
    /// item. Updating the stored value state in place preserves the native
    /// controls and menu hierarchy instead of rebuilding them during scroll.
    func configure(
        with item: RemappingRuleEditorItem
    ) {
        releaseBehaviorMenuPreviewViews()
        resetInteractionHandlersForReuse()

        editorItemID =
            item.id

        applyEditorItem(
            item
        )

        updateControls()
    }

    func setCombination(
        _ combination: KeyCombination,
        for field: KeyField
    ) {
        var updatedItem = editorItem

        switch field {
        case .source:
            updatedItem.setSourceCombination(combination)

        case .destination:
            updatedItem.setDestinationCombination(combination)
        }

        applyEditorItem(updatedItem)
        updateControls()
        onRuleChanged?(editorItem)
    }

    func setOverrides(_ newOverrides: [RemapOverride]) {
        overrides = newOverrides
        updateControls()
        onRuleChanged?(editorItem)
    }

    func showCapturePrompt(for field: KeyField) {
        restoreButtonTitles()

        switch field {
        case .source:
            sourceKeyButton.title = "Press combination…"

        case .destination:
            destinationKeyButton.title = "Press combination…"
        }
    }

    func restoreButtonTitles() {
        sourceKeyButton.title = buttonTitle(for: sourceCombination)
        destinationKeyButton.title = buttonTitle(
            for: destinationCombination
        )
    }

    func setValidationErrorVisible(_ isVisible: Bool) {
        guard isShowingValidationError != isVisible else {
            return
        }

        isShowingValidationError = isVisible
        updateValidationAppearance()
    }

    /// Associates a blocking validation message with this row.
    ///
    /// The message controls only presentation and never changes editor data.
    func setValidationIssueMessage(_ message: String?) {
        issuesView.setValidationMessage(message)
        setValidationErrorVisible(message != nil)
    }

    /// Shows a small informational warning indicator without changing the
    /// row's validation state or editable data.
    func setConfigurationWarning(
        _ warning: KeyCombinationConfigurationWarning?
    ) {
        issuesView.setConfigurationWarning(warning)
    }

    /// Shows any non-blocking configuration warning in the row's yellow
    /// Issues indicator.
    ///
    /// This is used for warnings that are not represented by
    /// `KeyCombinationConfigurationWarning`, such as a Preserve Modifiers rule
    /// sharing its physical key with an application shortcut.
    func setConfigurationWarningMessage(
        _ message: String?
    ) {
        issuesView.setConfigurationWarningMessage(
            message
        )
    }

    func applyTextScale(_ scale: CGFloat) {
        guard
            !hasAppliedTextScale
                || abs(
                    textScale
                        - scale
                ) > 0.0001
        else {
            return
        }

        textScale = scale
        hasAppliedTextScale = true

        let controlFont = NSFont.systemFont(
            ofSize: 14 * scale,
            weight: .regular
        )

        sourceKeyButton.font = controlFont
        destinationKeyButton.font = controlFont

        behaviorPopUpButton.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )

        exactBehaviorMenuView?
            .applyTextScale(
                scale
            )

        preserveBehaviorMenuView?
            .applyTextScale(
                scale
            )

        exceptionsButton.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )

        removeButton.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )

        updateArrowPresentation()

        issuesView.applyTextScale(scale)
        cacheControlFittingSizes()
        needsLayout = true
    }

    private func configureContent() {
        configureActivationSwitch()

        configureKeyButton(
            sourceKeyButton,
            action: #selector(requestSourceKey)
        )

        configureKeyButton(
            destinationKeyButton,
            action: #selector(requestDestinationKey)
        )

        arrowLabel.alignment = .center
        arrowLabel.lineBreakMode = .byClipping
        arrowLabel.maximumNumberOfLines = 1

        configureBehaviorMenu()

        behaviorPopUpButton.toolTip =
            "Choose exact matching or preserve incoming modifiers. Open the menu to preview both behaviors."

        exceptionsButton.title = "Exceptions…"
        exceptionsButton.bezelStyle = .rounded
        exceptionsButton.target = self
        exceptionsButton.action = #selector(requestExceptions)
        exceptionsButton.toolTip =
            "View and edit stored exceptions. They are active only in Preserve Modifiers mode."

        configureBidirectionalSwitch()

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.hasDestructiveAction = true
        removeButton.target = self
        removeButton.action = #selector(requestRemoval)

        let views: [NSView] = [
            activationSwitch,
            sourceKeyButton,
            arrowLabel,
            destinationKeyButton,
            behaviorPopUpButton,
            exceptionsButton,
            bidirectionalSwitch,
            issuesView,
            removeButton
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = true
            view.autoresizingMask = []

            addSubview(
                view
            )
        }

        applyTextScale(textScale)
    }

    private func cacheControlFittingSizes() {
        activationSwitchFittingSize =
            activationSwitch.fittingSize

        bidirectionalSwitchFittingSize =
            bidirectionalSwitch.fittingSize

        behaviorControlHeight =
            behaviorPopUpButton
                .fittingSize
                .height

        exceptionsControlHeight =
            exceptionsButton
                .fittingSize
                .height

        removeControlHeight =
            removeButton
                .fittingSize
                .height

        arrowControlHeight =
            arrowLabel
                .fittingSize
                .height
    }

    private func layoutControls() {
        let controlHeight =
            max(
                0,
                bounds.height
                    - 2
                    * LayoutMetrics
                        .verticalInset
            )

        let keyWidth =
            max(
                0,
                floor(
                    (
                        bounds.width
                            - LayoutMetrics
                                .nonKeyColumnWidth
                    )
                    / 2
                )
            )

        let destinationWidth =
            max(
                0,
                bounds.width
                    - LayoutMetrics
                        .nonKeyColumnWidth
                    - keyWidth
            )

        var x =
            LayoutMetrics
                .horizontalInset

        let activeColumnFrame =
            NSRect(
                x: x,
                y:
                    LayoutMetrics
                        .verticalInset,
                width:
                    LayoutMetrics
                        .activeColumnWidth,
                height:
                    controlHeight
            )

        activationSwitch.frame =
            centeredFrame(
                size:
                    activationSwitchFittingSize,
                in:
                    activeColumnFrame
            )

        x +=
            LayoutMetrics.activeColumnWidth
            + LayoutMetrics.sourceLeadingSpacing

        sourceKeyButton.frame =
            NSRect(
                x: x,
                y:
                    LayoutMetrics
                        .verticalInset,
                width:
                    keyWidth,
                height:
                    controlHeight
            )

        x +=
            keyWidth
            + LayoutMetrics.keyArrowSpacing

        let arrowDrawingWidth =
            LayoutMetrics
                .arrowDrawingWidth

        arrowLabel.frame =
            verticallyCenteredFrame(
                x:
                    x
                    + (
                        LayoutMetrics
                            .arrowWidth
                        - arrowDrawingWidth
                    )
                    / 2,
                width:
                    arrowDrawingWidth,
                preferredHeight:
                    arrowControlHeight,
                availableHeight:
                    controlHeight
            )

        x +=
            LayoutMetrics.arrowWidth
            + LayoutMetrics.keyArrowSpacing

        destinationKeyButton.frame =
            NSRect(
                x: x,
                y:
                    LayoutMetrics
                        .verticalInset,
                width:
                    destinationWidth,
                height:
                    controlHeight
            )

        x +=
            destinationWidth
            + LayoutMetrics
                .destinationBehaviorSpacing

        behaviorPopUpButton.frame =
            verticallyCenteredFrame(
                x: x,
                width:
                    LayoutMetrics
                        .behaviorWidth,
                preferredHeight:
                    behaviorControlHeight,
                availableHeight:
                    controlHeight
            )

        x +=
            LayoutMetrics.behaviorWidth
            + LayoutMetrics
                .behaviorExceptionsSpacing

        exceptionsButton.frame =
            verticallyCenteredFrame(
                x: x,
                width:
                    LayoutMetrics
                        .exceptionsWidth,
                preferredHeight:
                    exceptionsControlHeight,
                availableHeight:
                    controlHeight
            )

        x +=
            LayoutMetrics.exceptionsWidth
            + LayoutMetrics
                .compactColumnSpacing

        let reverseColumnFrame =
            NSRect(
                x: x,
                y:
                    LayoutMetrics
                        .verticalInset,
                width:
                    LayoutMetrics
                        .reverseColumnWidth,
                height:
                    controlHeight
            )

        bidirectionalSwitch.frame =
            centeredFrame(
                size:
                    bidirectionalSwitchFittingSize,
                in:
                    reverseColumnFrame
            )

        x +=
            LayoutMetrics.reverseColumnWidth
            + LayoutMetrics
                .compactColumnSpacing

        issuesView.frame =
            NSRect(
                x: x,
                y:
                    LayoutMetrics
                        .verticalInset,
                width:
                    LayoutMetrics
                        .issuesColumnWidth,
                height:
                    controlHeight
            )

        x +=
            LayoutMetrics.issuesColumnWidth
            + LayoutMetrics
                .compactColumnSpacing

        removeButton.frame =
            verticallyCenteredFrame(
                x: x,
                width:
                    LayoutMetrics
                        .removeButtonWidth,
                preferredHeight:
                    removeControlHeight,
                availableHeight:
                    controlHeight
            )
    }

    private func verticallyCenteredFrame(
        x: CGFloat,
        width: CGFloat,
        preferredHeight: CGFloat,
        availableHeight: CGFloat
    ) -> NSRect {
        let height =
            min(
                max(
                    0,
                    preferredHeight
                ),
                availableHeight
            )

        return NSRect(
            x: x,
            y:
                LayoutMetrics
                    .verticalInset
                + floor(
                    (
                        availableHeight
                            - height
                    )
                    / 2
                ),
            width:
                max(
                    0,
                    width
                ),
            height:
                height
        )
    }

    private func centeredFrame(
        size: NSSize,
        in containerFrame: NSRect
    ) -> NSRect {
        let width =
            min(
                max(
                    0,
                    size.width
                ),
                containerFrame.width
            )

        let height =
            min(
                max(
                    0,
                    size.height
                ),
                containerFrame.height
            )

        return NSRect(
            x:
                containerFrame.midX
                - width / 2,
            y:
                containerFrame.midY
                - height / 2,
            width:
                width,
            height:
                height
        )
    }

    private func configureActivationSwitch() {
        activationSwitch.controlSize = .small
        activationSwitch.target = self
        activationSwitch.action = #selector(
            activationSwitchChanged
        )
        activationSwitch.toolTip =
            "Enable or disable this rule without deleting it."
        activationSwitch.setAccessibilityLabel(
            "Active rule"
        )
        activationSwitch.setAccessibilityHelp(
            "When disabled, this rule, its Reverse direction, and its exceptions do not participate in remapping."
        )
    }

    private func configureKeyButton(
        _ button: NSButton,
        action: Selector
    ) {
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func configureBidirectionalSwitch() {
        bidirectionalSwitch.controlSize = .small
        bidirectionalSwitch.target = self
        bidirectionalSwitch.action = #selector(
            bidirectionalSwitchChanged
        )
        bidirectionalSwitch.toolTip =
            "Also apply this rule in the reverse direction without creating a duplicate rule."
        bidirectionalSwitch.setAccessibilityLabel(
            "Reverse mapping"
        )
        bidirectionalSwitch.setAccessibilityHelp(
            "When enabled, the destination also maps back to the source using the same behavior and mirrored exceptions."
        )
    }

    private func configureBehaviorMenu() {
        behaviorPopUpButton.addItems(
            withTitles: [
                "Exact only",
                "Preserve modifiers"
            ]
        )

        guard
            let exactItem = behaviorPopUpButton.item(at: 0),
            let preserveItem = behaviorPopUpButton.item(at: 1)
        else {
            return
        }

        exactItem.tag = 0
        exactItem.target = self
        exactItem.action = #selector(
            behaviorMenuItemSelected(_:)
        )

        preserveItem.tag = 1
        preserveItem.target = self
        preserveItem.action = #selector(
            behaviorMenuItemSelected(_:)
        )

        behaviorPopUpButton.menu?.delegate =
            self
    }

    func menuWillOpen(
        _ menu: NSMenu
    ) {
        guard
            menu === behaviorPopUpButton.menu
        else {
            return
        }

        ensureBehaviorMenuPreviewViews()
        refreshBehaviorMenuPreviews()
    }

    func menuDidClose(
        _ menu: NSMenu
    ) {
        guard
            menu === behaviorPopUpButton.menu
        else {
            return
        }

        releaseBehaviorMenuPreviewViews()
    }

    private func ensureBehaviorMenuPreviewViews() {
        guard
            exactBehaviorMenuView == nil,
            preserveBehaviorMenuView == nil,
            let exactItem =
                behaviorPopUpButton.item(
                    at: 0
                ),
            let preserveItem =
                behaviorPopUpButton.item(
                    at: 1
                )
        else {
            return
        }

        let exactView =
            BehaviorMenuItemView(
                title:
                    "Exact only"
            )

        let preserveView =
            BehaviorMenuItemView(
                title:
                    "Preserve modifiers"
            )

        exactView.applyTextScale(
            textScale
        )

        preserveView.applyTextScale(
            textScale
        )

        exactView.onActivate = {
            [weak self] in

            self?.selectBehavior(
                .exact
            )
        }

        preserveView.onActivate = {
            [weak self] in

            self?.selectBehavior(
                .preserveModifiers
            )
        }

        exactItem.view =
            exactView

        preserveItem.view =
            preserveView

        exactBehaviorMenuView =
            exactView

        preserveBehaviorMenuView =
            preserveView
    }

    private func releaseBehaviorMenuPreviewViews() {
        behaviorPopUpButton
            .item(
                at: 0
            )?
            .view =
            nil

        behaviorPopUpButton
            .item(
                at: 1
            )?
            .view =
            nil

        exactBehaviorMenuView?
            .onActivate =
            nil

        preserveBehaviorMenuView?
            .onActivate =
            nil

        exactBehaviorMenuView =
            nil

        preserveBehaviorMenuView =
            nil
    }

    private func synchronizeBehaviorControl() {
        switch matchingMode {
        case .exact:
            behaviorPopUpButton.selectItem(at: 0)

        case .preserveModifiers:
            behaviorPopUpButton.selectItem(at: 1)
        }

        exactBehaviorMenuView?
            .isSelected =
            matchingMode
                == .exact

        preserveBehaviorMenuView?
            .isSelected =
            matchingMode
                == .preserveModifiers
    }

    private func updateControls() {
        restoreButtonTitles()
        refreshBehaviorMenuPreviews()

        exceptionsButton.isEnabled =
            sourceCombination != nil
            && destinationCombination != nil

        exceptionsButton.title = overrides.isEmpty
            ? "Exceptions…"
            : "Exceptions (\(overrides.count))"

        activationSwitch.state = isEnabled ? .on : .off
        bidirectionalSwitch.state = isBidirectional ? .on : .off

        updateArrowPresentation()
    }

    /// Keeps both arrow glyphs fully visible while preserving the logical
    /// 18-point column and every neighboring control position.
    ///
    /// The label borrows only from the existing empty spacing on each side.
    /// Its font is then reduced only when the actual AppKit fitting width still
    /// exceeds that wider drawing frame.
    private func updateArrowPresentation() {
        arrowLabel.stringValue =
            isBidirectional
                ? "↔"
                : "→"

        let preferredPointSize =
            20
            * textScale

        // Do not scale this floor upward. At larger application text sizes the
        // glyph may need to remain smaller than surrounding controls in order
        // to fit the fixed column without clipping.
        let minimumPointSize:
            CGFloat =
                10

        let availableWidth =
            max(
                1,
                LayoutMetrics
                    .arrowDrawingWidth
                    - 2
            )

        var pointSize =
            max(
                minimumPointSize,
                preferredPointSize
            )

        var fittingSize =
            NSSize.zero

        while true {
            arrowLabel.font =
                NSFont.systemFont(
                    ofSize:
                        pointSize,
                    weight:
                        .regular
                )

            fittingSize =
                arrowLabel
                    .fittingSize

            if fittingSize.width
                <= availableWidth
                || pointSize
                    <= minimumPointSize
            {
                break
            }

            pointSize =
                max(
                    minimumPointSize,
                    pointSize
                        - 0.5
                )
        }

        arrowControlHeight =
            fittingSize.height

        needsLayout =
            true
    }

    private func updateValidationAppearance() {
        needsDisplay = true
    }

    private func buttonTitle(
        for combination: KeyCombination?
    ) -> String {
        guard let combination else {
            return "Choose Combination…"
        }

        return KeyCombinationDisplayName.name(
            for: combination
        )
    }

    private func refreshBehaviorMenuPreviews() {
        if let exactBehaviorMenuView {
            exactBehaviorMenuView.setExamples(
                behaviorPreviewLines(
                    for:
                        .exact
                )
            )
        }

        if let preserveBehaviorMenuView {
            preserveBehaviorMenuView.setExamples(
                behaviorPreviewLines(
                    for:
                        .preserveModifiers
                )
            )
        }

        synchronizeBehaviorControl()
    }

    private func resetInteractionHandlersForReuse() {
        onSourceKeyRequested =
            nil

        onDestinationKeyRequested =
            nil

        onExceptionsRequested =
            nil

        onRemoveRequested =
            nil

        onMatchingModeChangeRequested =
            nil

        onMatchingModeChangeRejected =
            nil

        onRuleChanged =
            nil
    }

    private func behaviorPreviewLines(
        for mode: RemapMatchingMode
    ) -> [String] {
        let currentEditorItem = editorItem

        if mode == .preserveModifiers,
           currentEditorItem.matchingModeTransitionIssue(
                to: mode
           ) != nil
        {
            return [
                "Unavailable while source or destination contains modifiers.",
                "Remove Fn, Shift, Control, Option, or Command first."
            ]
        }

        guard
            let sourceCombination = currentEditorItem
                .sourceCombinationForPreview(in: mode),
            let destinationCombination = currentEditorItem
                .destinationCombinationForPreview(in: mode)
        else {
            return [
                "Choose source and destination to preview."
            ]
        }

        let previewSources: [KeyCombination]

        switch mode {
        case .exact:
            previewSources = exactPreviewSources(
                configuredSource: sourceCombination
            )

        case .preserveModifiers:
            previewSources = [
                KeyCombination(
                    keyCode: sourceCombination.keyCode
                ),
                KeyCombination(
                    keyCode: sourceCombination.keyCode,
                    modifiers: .shift
                ),
                KeyCombination(
                    keyCode: sourceCombination.keyCode,
                    modifiers: .command
                )
            ]
        }

        var previewLines = previewSources.map {
            previewSource in

            let previewDestination: KeyCombination

            switch mode {
            case .exact:
                previewDestination = previewSource == sourceCombination
                    ? destinationCombination
                    : previewSource

            case .preserveModifiers:
                previewDestination = preservePreviewDestination(
                    for: previewSource,
                    destinationKeyCode:
                        destinationCombination.keyCode
                )
            }

            return
                "\(KeyCombinationDisplayName.name(for: previewSource)) → "
                + KeyCombinationDisplayName.name(
                    for: previewDestination
                )
        }

        if mode == .preserveModifiers {
            let sourceKeyName = KeyCodeDisplayName.name(
                for: sourceCombination.keyCode
            )

            previewLines.append(
                "Modifier + \(sourceKeyName) → Custom action"
            )
        }

        return previewLines
    }

    private func exactPreviewSources(
        configuredSource: KeyCombination
    ) -> [KeyCombination] {
        let candidateSources = [
            configuredSource,
            KeyCombination(
                keyCode: configuredSource.keyCode
            ),
            KeyCombination(
                keyCode: configuredSource.keyCode,
                modifiers: .shift
            ),
            KeyCombination(
                keyCode: configuredSource.keyCode,
                modifiers: .command
            ),
            KeyCombination(
                keyCode: configuredSource.keyCode,
                modifiers: .option
            )
        ]

        var uniqueSources: [KeyCombination] = []

        for candidate in candidateSources
        where !uniqueSources.contains(candidate) {
            uniqueSources.append(candidate)

            if uniqueSources.count == 3 {
                break
            }
        }

        return uniqueSources
    }

    private func preservePreviewDestination(
        for source: KeyCombination,
        destinationKeyCode: CGKeyCode
    ) -> KeyCombination {
        if let activeOverride = overrides.first(
            where: {
                $0.isEnabled
                && $0.source == source
            }
        ) {
            switch activeOverride.action {
            case .passThrough:
                return source

            case .replaceWith(let destination):
                return destination
            }
        }

        return KeyCombination(
            keyCode: destinationKeyCode,
            modifiers: source.modifiers
        )
    }

    private func retargetOverrides(
        to sourceKeyCode: CGKeyCode
    ) {
        overrides = overrides.map {
            remapOverride in

            RemapOverride(
                source: KeyCombination(
                    keyCode: sourceKeyCode,
                    modifiers: remapOverride.source.modifiers
                ),
                action: remapOverride.action,
                isEnabled: remapOverride.isEnabled
            )
        }
    }

    @objc
    private func behaviorMenuItemSelected(
        _ sender: NSMenuItem
    ) {
        selectBehavior(
            sender.tag == 1
                ? .preserveModifiers
                : .exact
        )
    }

    private func selectBehavior(
        _ requestedMode: RemapMatchingMode
    ) {
        guard requestedMode != matchingMode else {
            synchronizeBehaviorControl()
            return
        }

        let currentItem = editorItem

        if let transitionIssue = currentItem
            .matchingModeTransitionIssue(to: requestedMode)
        {
            synchronizeBehaviorControl()
            onMatchingModeChangeRejected?(transitionIssue)
            return
        }

        var candidateItem = currentItem
        candidateItem.setMatchingMode(requestedMode)

        if let onMatchingModeChangeRequested,
           !onMatchingModeChangeRequested(candidateItem)
        {
            synchronizeBehaviorControl()
            return
        }

        applyEditorItem(candidateItem)
        synchronizeBehaviorControl()
        updateControls()
        onRuleChanged?(editorItem)
    }

    private func applyEditorItem(
        _ item: RemappingRuleEditorItem
    ) {
        isEnabled = item.isEnabled
        sourceCombination = item.sourceCombination
        destinationCombination = item.destinationCombination
        matchingMode = item.matchingMode
        overrides = item.overrides
        isBidirectional = item.isBidirectional
        rememberedExactSourceCombination =
            item.rememberedExactSourceCombination
        rememberedExactDestinationCombination =
            item.rememberedExactDestinationCombination
    }

    @objc
    private func activationSwitchChanged() {
        var updatedItem = editorItem
        updatedItem.setEnabled(
            activationSwitch.state == .on
        )

        applyEditorItem(updatedItem)
        updateControls()
        onRuleChanged?(editorItem)
    }

    @objc
    private func bidirectionalSwitchChanged() {
        var updatedItem = editorItem
        updatedItem.setBidirectional(
            bidirectionalSwitch.state == .on
        )

        applyEditorItem(updatedItem)
        updateControls()
        onRuleChanged?(editorItem)
    }

    @objc
    private func requestSourceKey() {
        onSourceKeyRequested?()
    }

    @objc
    private func requestDestinationKey() {
        onDestinationKeyRequested?()
    }

    @objc
    private func requestExceptions() {
        onExceptionsRequested?()
    }

    @objc
    private func requestRemoval() {
        onRemoveRequested?()
    }

    // MARK: - Test support

    var directConstraintCountForTesting: Int {
        constraints.count
    }

    var usesBackingLayerForTesting: Bool {
        wantsLayer
            || layer != nil
    }

    var sourceAndDestinationWidthsForTesting:
        (CGFloat, CGFloat)
    {
        (
            sourceKeyButton.frame.width,
            destinationKeyButton.frame.width
        )
    }

    var orderedControlFramesForTesting: [NSRect] {
        [
            activationSwitch.frame,
            sourceKeyButton.frame,
            arrowLabel.frame,
            destinationKeyButton.frame,
            behaviorPopUpButton.frame,
            exceptionsButton.frame,
            bidirectionalSwitch.frame,
            issuesView.frame,
            removeButton.frame
        ]
    }

    var behaviorPreviewViewCountForTesting: Int {
        [
            exactBehaviorMenuView,
            preserveBehaviorMenuView
        ]
            .compactMap {
                $0
            }
            .count
    }

    var arrowTitleForTesting: String {
        arrowLabel.stringValue
    }

    var arrowFrameForTesting: NSRect {
        arrowLabel.frame
    }

    var arrowFittingSizeForTesting: NSSize {
        arrowLabel.fittingSize
    }

    func openBehaviorMenuForTesting() {
        guard
            let menu =
                behaviorPopUpButton.menu
        else {
            return
        }

        menuWillOpen(
            menu
        )
    }

    func closeBehaviorMenuForTesting() {
        guard
            let menu =
                behaviorPopUpButton.menu
        else {
            return
        }

        menuDidClose(
            menu
        )
    }
}
