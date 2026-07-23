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
final class RemappingRuleRowView: NSView {
    @MainActor
    private final class BehaviorMenuItemView:
        NSView
    {
        private let checkmarkLabel =
            NSTextField(
                labelWithString: ""
            )

        private let titleLabel =
            NSTextField(
                labelWithString: ""
            )

        private let examplesLabel =
            NSTextField(
                wrappingLabelWithString: ""
            )

        private var trackingAreaReference:
            NSTrackingArea?

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

        init(
            title: String
        ) {
            super.init(
                frame:
                    NSRect(
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

        required init?(
            coder: NSCoder
        ) {
            fatalError(
                "init(coder:) has not been implemented"
            )
        }

        /// Makes the complete custom menu item behave as one clickable area.
        /// Text labels never become separate hit-test targets.
        override func hitTest(
            _ point: NSPoint
        ) -> NSView? {
            guard !isHidden,
                  alphaValue > 0 else {
                return nil
            }

            return bounds.contains(point)
                ? self
                : nil
        }

        /// Keeps the normal pointer over the entire menu item instead of
        /// showing an insertion cursor over its text labels.
        override func resetCursorRects() {
            addCursorRect(
                bounds,
                cursor: .arrow
            )
        }

        override func draw(
            _ dirtyRect: NSRect
        ) {
            super.draw(dirtyRect)

            guard isHovered else {
                return
            }

            NSColor.selectedContentBackgroundColor
                .setFill()

            NSBezierPath(
                roundedRect:
                    bounds.insetBy(
                        dx: 4,
                        dy: 3
                    ),
                xRadius: 6,
                yRadius: 6
            ).fill()
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
                        .activeAlways,
                        .mouseEnteredAndExited,
                        .cursorUpdate
                    ],
                    owner: self,
                    userInfo: nil
                )

            addTrackingArea(trackingArea)
            trackingAreaReference =
                trackingArea
        }

        override func mouseEntered(
            with event: NSEvent
        ) {
            NSCursor.arrow.set()
            isHovered = true
        }

        override func cursorUpdate(
            with event: NSEvent
        ) {
            NSCursor.arrow.set()
        }

        override func mouseExited(
            with event: NSEvent
        ) {
            isHovered = false
        }

        override func mouseUp(
            with event: NSEvent
        ) {
            guard
                bounds.contains(
                    convert(
                        event.locationInWindow,
                        from: nil
                    )
                )
            else {
                return
            }

            let menu =
                enclosingMenuItem?
                    .menu

            menu?.cancelTracking()
            onActivate?()
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateAppearance()
            needsDisplay = true
        }

        func setExamples(
            _ examples: [String]
        ) {
            examplesLabel.stringValue =
                examples.joined(
                    separator: "\n"
                )
        }

        func applyTextScale(
            _ scale: CGFloat
        ) {
            titleLabel.font =
                NSFont.systemFont(
                    ofSize: 14 * scale,
                    weight: .semibold
                )

            examplesLabel.font =
                NSFont.systemFont(
                    ofSize: 12 * scale,
                    weight: .regular
                )

            checkmarkLabel.font =
                NSFont.systemFont(
                    ofSize: 14 * scale,
                    weight: .semibold
                )

            frame.size =
                NSSize(
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

            checkmarkLabel.alignment =
                .center

            titleLabel.lineBreakMode =
                .byTruncatingTail

            examplesLabel.maximumNumberOfLines =
                4

            examplesLabel.lineBreakMode =
                .byTruncatingTail

            let views: [NSView] = [
                checkmarkLabel,
                titleLabel,
                examplesLabel
            ]

            for view in views {
                view.translatesAutoresizingMaskIntoConstraints =
                    false

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
                        equalTo:
                            checkmarkLabel
                                .trailingAnchor,
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
                        equalTo:
                            titleLabel
                                .leadingAnchor
                    ),

                    examplesLabel.trailingAnchor.constraint(
                        equalTo:
                            titleLabel
                                .trailingAnchor
                    ),

                    examplesLabel.topAnchor.constraint(
                        equalTo:
                            titleLabel
                                .bottomAnchor,
                        constant: 4
                    ),

                    examplesLabel.bottomAnchor.constraint(
                        lessThanOrEqualTo:
                            bottomAnchor,
                        constant: -10
                    )
                ]
            )

            applyTextScale(1.0)
        }

        private func updateAppearance() {
            checkmarkLabel.stringValue =
                isSelected ? "✓" : ""

            let primaryColor: NSColor
            let secondaryColor: NSColor

            if isHovered {
                primaryColor =
                    .selectedControlTextColor

                secondaryColor =
                    .selectedControlTextColor
            } else {
                primaryColor =
                    .labelColor

                secondaryColor =
                    .secondaryLabelColor
            }

            checkmarkLabel.textColor =
                primaryColor

            titleLabel.textColor =
                primaryColor

            examplesLabel.textColor =
                secondaryColor
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
    var onRuleChanged: ((RemappingRuleEditorItem) -> Void)?

    private let sourceKeyButton = NSButton()
    private let arrowLabel = NSTextField(
        labelWithString: "→"
    )
    private let destinationKeyButton = NSButton()
    private let behaviorPopUpButton = NSPopUpButton()

    private let exactBehaviorMenuView =
        BehaviorMenuItemView(
            title: "Exact only"
        )

    private let preserveBehaviorMenuView =
        BehaviorMenuItemView(
            title: "Preserve modifiers"
        )

    private let exceptionsButton = NSButton()
    private let removeButton = NSButton()

    private var rowHeightConstraint: NSLayoutConstraint?
    private var isShowingValidationError = false
    private var textScale: CGFloat = 1.0

    let editorItemID: UUID

    private(set) var sourceCombination: KeyCombination?
    private(set) var destinationCombination: KeyCombination?
    private(set) var matchingMode: RemapMatchingMode
    private(set) var overrides: [RemapOverride]

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
            overrides: overrides
        )
    }

    var rule: RemapRule? {
        editorItem.rule
    }

    init(
        item: RemappingRuleEditorItem
    ) {
        editorItemID = item.id
        sourceCombination = item.sourceCombination
        destinationCombination = item.destinationCombination
        matchingMode = item.matchingMode
        overrides = item.overrides

        super.init(frame: .zero)

        configureContent()
        synchronizeBehaviorControl()
        updateControls()
        updateValidationAppearance()
    }

    convenience init(
        rule: RemapRule? = nil
    ) {
        if let rule {
            self.init(
                item: RemappingRuleEditorItem(
                    rule: rule
                )
            )
        } else {
            self.init(
                item: RemappingRuleEditorItem()
            )
        }
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
        updateValidationAppearance()
    }

    func setCombination(
        _ combination: KeyCombination,
        for field: KeyField
    ) {
        let normalizedCombination: KeyCombination

        if matchingMode == .preserveModifiers {
            normalizedCombination = KeyCombination(
                keyCode: combination.keyCode
            )
        } else {
            normalizedCombination = combination
        }

        switch field {
        case .source:
            let previousKeyCode =
                sourceCombination?.keyCode

            sourceCombination =
                normalizedCombination

            if let previousKeyCode,
               previousKeyCode
                != normalizedCombination.keyCode
            {
                retargetOverrides(
                    to:
                        normalizedCombination.keyCode
                )
            }

        case .destination:
            destinationCombination =
                normalizedCombination
        }

        updateControls()
        onRuleChanged?(editorItem)
    }

    func setOverrides(
        _ newOverrides: [RemapOverride]
    ) {
        overrides = newOverrides
        updateControls()
        onRuleChanged?(editorItem)
    }

    func showCapturePrompt(
        for field: KeyField
    ) {
        restoreButtonTitles()

        switch field {
        case .source:
            sourceKeyButton.title =
                "Press combination…"

        case .destination:
            destinationKeyButton.title =
                "Press combination…"
        }
    }

    func restoreButtonTitles() {
        sourceKeyButton.title =
            buttonTitle(
                for: sourceCombination
            )

        destinationKeyButton.title =
            buttonTitle(
                for:
                    destinationCombination
            )
    }

    func setValidationErrorVisible(
        _ isVisible: Bool
    ) {
        guard
            isShowingValidationError
                != isVisible
        else {
            return
        }

        isShowingValidationError =
            isVisible

        updateValidationAppearance()
    }

    func applyTextScale(
        _ scale: CGFloat
    ) {
        textScale = scale

        let controlFont =
            NSFont.systemFont(
                ofSize: 14 * scale,
                weight: .regular
            )

        sourceKeyButton.font =
            controlFont

        destinationKeyButton.font =
            controlFont

        behaviorPopUpButton.font =
            NSFont.systemFont(
                ofSize: 13 * scale,
                weight: .regular
            )

        exactBehaviorMenuView.applyTextScale(
            scale
        )

        preserveBehaviorMenuView.applyTextScale(
            scale
        )

        exceptionsButton.font =
            NSFont.systemFont(
                ofSize: 13 * scale,
                weight: .regular
            )

        removeButton.font =
            NSFont.systemFont(
                ofSize: 13 * scale,
                weight: .regular
            )

        arrowLabel.font =
            NSFont.systemFont(
                ofSize: 20 * scale,
                weight: .regular
            )

        rowHeightConstraint?.constant =
            42 * scale

        needsLayout = true
    }

    private func configureContent() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        configureKeyButton(
            sourceKeyButton,
            action:
                #selector(requestSourceKey)
        )

        configureKeyButton(
            destinationKeyButton,
            action:
                #selector(
                    requestDestinationKey
                )
        )

        arrowLabel.alignment = .center

        arrowLabel.setContentHuggingPriority(
            .required,
            for: .horizontal
        )

        arrowLabel.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )

        configureBehaviorMenu()

        behaviorPopUpButton.toolTip =
            "Choose exact matching or preserve incoming modifiers. Open the menu to preview both behaviors."

        exceptionsButton.title =
            "Exceptions…"

        exceptionsButton.bezelStyle =
            .rounded

        exceptionsButton.target = self
        exceptionsButton.action =
            #selector(requestExceptions)

        exceptionsButton.toolTip =
            "View and edit stored exceptions. They are active only in Preserve Modifiers mode."

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.hasDestructiveAction =
            true
        removeButton.target = self
        removeButton.action =
            #selector(requestRemoval)

        let views: [NSView] = [
            sourceKeyButton,
            arrowLabel,
            destinationKeyButton,
            behaviorPopUpButton,
            exceptionsButton,
            removeButton
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints =
                false

            addSubview(view)
        }

        let rowHeightConstraint =
            heightAnchor.constraint(
                equalToConstant: 42
            )

        self.rowHeightConstraint =
            rowHeightConstraint

        NSLayoutConstraint.activate(
            [
                sourceKeyButton.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: 6
                ),

                sourceKeyButton.topAnchor.constraint(
                    equalTo: topAnchor,
                    constant: 4
                ),

                sourceKeyButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -4
                ),

                arrowLabel.leadingAnchor.constraint(
                    equalTo:
                        sourceKeyButton
                            .trailingAnchor,
                    constant: 10
                ),

                arrowLabel.centerYAnchor.constraint(
                    equalTo:
                        sourceKeyButton
                            .centerYAnchor
                ),

                destinationKeyButton.leadingAnchor.constraint(
                    equalTo:
                        arrowLabel
                            .trailingAnchor,
                    constant: 10
                ),

                destinationKeyButton.topAnchor.constraint(
                    equalTo: topAnchor,
                    constant: 4
                ),

                destinationKeyButton.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -4
                ),

                behaviorPopUpButton.leadingAnchor.constraint(
                    equalTo:
                        destinationKeyButton
                            .trailingAnchor,
                    constant: 10
                ),

                behaviorPopUpButton.centerYAnchor.constraint(
                    equalTo:
                        destinationKeyButton
                            .centerYAnchor
                ),

                behaviorPopUpButton.widthAnchor.constraint(
                    equalToConstant: 168
                ),

                exceptionsButton.leadingAnchor.constraint(
                    equalTo:
                        behaviorPopUpButton
                            .trailingAnchor,
                    constant: 10
                ),

                exceptionsButton.centerYAnchor.constraint(
                    equalTo:
                        destinationKeyButton
                            .centerYAnchor
                ),

                exceptionsButton.widthAnchor.constraint(
                    equalToConstant: 116
                ),

                removeButton.leadingAnchor.constraint(
                    equalTo:
                        exceptionsButton
                            .trailingAnchor,
                    constant: 10
                ),

                removeButton.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -6
                ),

                removeButton.centerYAnchor.constraint(
                    equalTo:
                        destinationKeyButton
                            .centerYAnchor
                ),

                removeButton.widthAnchor.constraint(
                    equalToConstant: 82
                ),

                sourceKeyButton.widthAnchor.constraint(
                    equalTo:
                        destinationKeyButton
                            .widthAnchor
                ),

                sourceKeyButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        120
                ),

                destinationKeyButton.widthAnchor.constraint(
                    greaterThanOrEqualToConstant:
                        120
                ),

                rowHeightConstraint
            ]
        )

        applyTextScale(textScale)
    }

    private func configureKeyButton(
        _ button: NSButton,
        action: Selector
    ) {
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func configureBehaviorMenu() {
        behaviorPopUpButton.addItems(
            withTitles: [
                "Exact only",
                "Preserve modifiers"
            ]
        )

        guard
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

        exactItem.tag = 0
        exactItem.target = self
        exactItem.action =
            #selector(
                behaviorMenuItemSelected(_:)
            )
        exactItem.view =
            exactBehaviorMenuView

        preserveItem.tag = 1
        preserveItem.target = self
        preserveItem.action =
            #selector(
                behaviorMenuItemSelected(_:)
            )
        preserveItem.view =
            preserveBehaviorMenuView

        exactBehaviorMenuView.onActivate = {
            [weak self] in

            self?.selectBehavior(
                .exact
            )
        }

        preserveBehaviorMenuView.onActivate = {
            [weak self] in

            self?.selectBehavior(
                .preserveModifiers
            )
        }

        refreshBehaviorMenuPreviews()
    }

    private func synchronizeBehaviorControl() {
        switch matchingMode {
        case .exact:
            behaviorPopUpButton.selectItem(
                at: 0
            )

        case .preserveModifiers:
            behaviorPopUpButton.selectItem(
                at: 1
            )
        }

        exactBehaviorMenuView.isSelected =
            matchingMode == .exact

        preserveBehaviorMenuView.isSelected =
            matchingMode
                == .preserveModifiers
    }

    private func updateControls() {
        restoreButtonTitles()
        refreshBehaviorMenuPreviews()

        exceptionsButton.isEnabled =
            sourceCombination != nil
            && destinationCombination != nil

        exceptionsButton.title =
            overrides.isEmpty
                ? "Exceptions…"
                : "Exceptions (\(overrides.count))"
    }

    private func updateValidationAppearance() {
        guard let layer else {
            return
        }

        if isShowingValidationError {
            layer.borderWidth = 1.5
            layer.borderColor =
                NSColor.systemRed.cgColor

            layer.backgroundColor =
                NSColor.systemRed
                    .withAlphaComponent(0.08)
                    .cgColor
        } else {
            layer.borderWidth = 0
            layer.borderColor =
                NSColor.clear.cgColor

            layer.backgroundColor =
                NSColor.clear.cgColor
        }
    }

    private func buttonTitle(
        for combination:
            KeyCombination?
    ) -> String {
        guard let combination else {
            return "Choose Combination…"
        }

        return KeyCombinationDisplayName.name(
            for: combination
        )
    }

    private func refreshBehaviorMenuPreviews() {
        exactBehaviorMenuView.setExamples(
            behaviorPreviewLines(
                for: .exact
            )
        )

        preserveBehaviorMenuView.setExamples(
            behaviorPreviewLines(
                for: .preserveModifiers
            )
        )

        synchronizeBehaviorControl()
    }

    private func behaviorPreviewLines(
        for mode: RemapMatchingMode
    ) -> [String] {
        guard
            let sourceCombination,
            let destinationCombination
        else {
            return [
                "Choose source and destination to preview."
            ]
        }

        let previewSources:
            [KeyCombination]

        switch mode {
        case .exact:
            previewSources =
                exactPreviewSources(
                    configuredSource:
                        sourceCombination
                )

        case .preserveModifiers:
            previewSources = [
                KeyCombination(
                    keyCode:
                        sourceCombination.keyCode
                ),
                KeyCombination(
                    keyCode:
                        sourceCombination.keyCode,
                    modifiers:
                        .shift
                ),
                KeyCombination(
                    keyCode:
                        sourceCombination.keyCode,
                    modifiers:
                        .command
                )
            ]
        }

        var previewLines =
            previewSources.map {
                previewSource in

                let previewDestination:
                    KeyCombination

                switch mode {
                case .exact:
                    previewDestination =
                        previewSource
                            == sourceCombination
                        ? destinationCombination
                        : previewSource

                case .preserveModifiers:
                    previewDestination =
                        preservePreviewDestination(
                            for:
                                previewSource,
                            destinationKeyCode:
                                destinationCombination
                                    .keyCode
                        )
                }

                return
                    "\(KeyCombinationDisplayName.name(for: previewSource)) → "
                    + KeyCombinationDisplayName.name(
                        for:
                            previewDestination
                    )
            }

        if mode == .preserveModifiers {
            let sourceKeyName =
                KeyCodeDisplayName.name(
                    for:
                        sourceCombination.keyCode
                )

            previewLines.append(
                "Modifier + \(sourceKeyName) → Custom action"
            )
        }

        return previewLines
    }

    private func exactPreviewSources(
        configuredSource:
            KeyCombination
    ) -> [KeyCombination] {
        let candidateSources = [
            configuredSource,
            KeyCombination(
                keyCode:
                    configuredSource.keyCode
            ),
            KeyCombination(
                keyCode:
                    configuredSource.keyCode,
                modifiers:
                    .shift
            ),
            KeyCombination(
                keyCode:
                    configuredSource.keyCode,
                modifiers:
                    .command
            ),
            KeyCombination(
                keyCode:
                    configuredSource.keyCode,
                modifiers:
                    .option
            )
        ]

        var uniqueSources:
            [KeyCombination] = []

        for candidate in candidateSources
        where !uniqueSources.contains(
            candidate
        ) {
            uniqueSources.append(
                candidate
            )

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
        if let activeOverride =
            overrides.first(
                where: {
                    $0.isEnabled
                    && $0.source == source
                }
            )
        {
            switch activeOverride.action {
            case .passThrough:
                return source

            case .replaceWith(
                let destination
            ):
                return destination
            }
        }

        return KeyCombination(
            keyCode:
                destinationKeyCode,
            modifiers:
                source.modifiers
        )
    }

    private func retargetOverrides(
        to sourceKeyCode: CGKeyCode
    ) {
        overrides = overrides.map {
            override in

            RemapOverride(
                source:
                    KeyCombination(
                        keyCode:
                            sourceKeyCode,
                        modifiers:
                            override
                                .source
                                .modifiers
                    ),
                action:
                    override.action,
                isEnabled:
                    override.isEnabled
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
        _ requestedMode:
            RemapMatchingMode
    ) {
        guard
            requestedMode != matchingMode
        else {
            synchronizeBehaviorControl()
            return
        }

        let candidateItem =
            editorItem(
                applying:
                    requestedMode
            )

        if let onMatchingModeChangeRequested,
           !onMatchingModeChangeRequested(
                candidateItem
           )
        {
            synchronizeBehaviorControl()
            return
        }

        sourceCombination =
            candidateItem
                .sourceCombination

        destinationCombination =
            candidateItem
                .destinationCombination

        matchingMode =
            candidateItem
                .matchingMode

        overrides =
            candidateItem
                .overrides

        synchronizeBehaviorControl()
        updateControls()
        onRuleChanged?(editorItem)
    }

    private func editorItem(
        applying requestedMode:
            RemapMatchingMode
    ) -> RemappingRuleEditorItem {
        var candidateSource =
            sourceCombination

        var candidateDestination =
            destinationCombination

        if requestedMode
            == .preserveModifiers
        {
            if let sourceCombination {
                candidateSource =
                    KeyCombination(
                        keyCode:
                            sourceCombination
                                .keyCode
                    )
            }

            if let destinationCombination {
                candidateDestination =
                    KeyCombination(
                        keyCode:
                            destinationCombination
                                .keyCode
                    )
            }
        }

        return RemappingRuleEditorItem(
            id: editorItemID,
            sourceCombination:
                candidateSource,
            destinationCombination:
                candidateDestination,
            matchingMode:
                requestedMode,
            overrides:
                overrides
        )
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
}
