//
//  HomeProfilesSectionView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import AppKit

/// A button whose action is bound to one stable profile UUID.
@MainActor
private final class ProfileIDButton: NSButton {
    var profileID: UUID?
}


/// Lays out action buttons with explicit frames instead of Auto Layout.
///
/// `NSTableView` supplies an encapsulated width for every cell. Combining that
/// width with fixed button constraints inside `NSStackView` caused repeated
/// unsatisfiable-constraint warnings and made the leading Open button unreliable
/// at compact widths. This cell owns the simple horizontal geometry directly,
/// so the visible frame and clickable frame are always identical.
@MainActor
private final class ProfileActionsCellView: NSTableCellView {
    private let actionButtons: [NSButton]
    private let actionButtonWidths: [CGFloat]
    private let actionButtonHeights: [CGFloat]
    private let buttonSpacing: CGFloat
    private let leadingPadding: CGFloat

    init(
        buttons: [NSButton],
        widths: [CGFloat],
        spacing: CGFloat,
        leadingPadding: CGFloat
    ) {
        actionButtons = buttons
        actionButtonWidths = widths
        actionButtonHeights = buttons.map { button in
            ceil(
                max(
                    button.cell?.cellSize.height ?? 0,
                    button.fittingSize.height,
                    22
                )
            )
        }
        buttonSpacing = spacing
        self.leadingPadding = leadingPadding

        super.init(frame: .zero)

        for button in actionButtons {
            button.translatesAutoresizingMaskIntoConstraints = true
            button.sizeToFit()
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        var nextX = leadingPadding

        for (index, button) in actionButtons.enumerated() {
            guard actionButtonWidths.indices.contains(index) else {
                continue
            }

            let buttonHeight = min(
                actionButtonHeights[index],
                bounds.height
            )

            button.frame = NSRect(
                x: nextX,
                y: floor((bounds.height - buttonHeight) / 2),
                width: actionButtonWidths[index],
                height: buttonHeight
            )

            nextX += actionButtonWidths[index] + buttonSpacing
        }
    }
}

/// Displays and edits the presentation-facing Home profiles section.
///
/// Profile mutations are delegated exclusively to
/// `HomeConfigurationEditorSession`. Search, sorting, row selection, scrolling,
/// and responsive column presentation remain local UI state and therefore
/// never create Home history or persistent configuration changes.
@MainActor
final class HomeProfilesSectionView:
    NSView,
    NSSearchFieldDelegate,
    NSTableViewDataSource,
    NSTableViewDelegate
{
    var onOpenProfile: ((UUID) -> Void)?

    /// Requests presentation of the profile shortcut editor.
    ///
    /// The section supplies only the stable profile UUID. It does not create
    /// the sheet, capture keyboard input, or modify the Home draft directly.
    var onEditShortcut: ((UUID) -> Void)?

    var onStatusChange: ((String, Bool) -> Void)?
    var onPreferredHeightChange: (() -> Void)?

    private enum Column {
        static let profile = NSUserInterfaceItemIdentifier(
            "home.profiles.profile"
        )
        static let rules = NSUserInterfaceItemIdentifier(
            "home.profiles.rules"
        )
        static let shortcut = NSUserInterfaceItemIdentifier(
            "home.profiles.shortcut"
        )
        static let created = NSUserInterfaceItemIdentifier(
            "home.profiles.created"
        )
        static let actions = NSUserInterfaceItemIdentifier(
            "home.profiles.actions"
        )
    }

    private enum ActionButtonIdentifier {
        static let open = NSUserInterfaceItemIdentifier(
            "home.profiles.action.open"
        )
        static let rename = NSUserInterfaceItemIdentifier(
            "home.profiles.action.rename"
        )
        static let duplicate = NSUserInterfaceItemIdentifier(
            "home.profiles.action.duplicate"
        )
        static let delete = NSUserInterfaceItemIdentifier(
            "home.profiles.action.delete"
        )
    }

    private enum ActionsLayoutMetrics {
        static let buttonSpacing: CGFloat = 5
        static let leadingPadding: CGFloat = 4
        static let trailingPadding: CGFloat = 4

        /// Overlay scrollbars can cover the trailing edge of the table without
        /// reducing the clip view width. Reserve this space inside Actions so
        /// every button remains visible and hit-testable while scrolling.
        static let overlayScrollerSafetyWidth: CGFloat = 18

        /// Minimum clickable width for an image-only action button. AppKit's
        /// `cellSize` can report a much smaller width before a button belongs to
        /// a laid-out window, which previously produced visible symbols whose
        /// real hit area was only a few points wide.
        static let minimumImageOnlyButtonWidth: CGFloat = 32

        /// Stable minimums for the two labeled controls. These values match the
        /// real small rounded AppKit controls used by the table and prevent the
        /// title from collapsing to an ellipsis even when pre-layout intrinsic
        /// measurements are unexpectedly small.
        static let minimumLabeledOpenButtonWidth: CGFloat = 75
        static let minimumLabeledRenameButtonWidth: CGFloat = 88

        /// Additional room required by a rounded small button around its title
        /// and optional symbol. This is deliberately independent from
        /// `NSCell.cellSize`, whose pre-layout result is not reliable here.
        static let titledButtonChromeWidth: CGFloat = 38

        static let imageTitleSpacing: CGFloat = 5

        /// Protects against fractional AppKit control measurements being
        /// rounded down when column widths are assigned.
        static let buttonWidthSafety: CGFloat = 4
    }

    private let editorSession: HomeConfigurationEditorSession?
    private let validator: RemappingProfilesConfigurationValidating

    private var configuration: RemappingProfilesConfiguration
    private var presentationModel = HomeProfilesPresentationModel()
    private var visibleProfiles: [RemappingProfile] = []
    private var persistedRuleCounts: [UUID: Int] = [:]
    private var selectedProfileID: UUID?
    private var textScale: CGFloat = 1.0

    private let dateLocale: Locale
    private let dateCalendar: Calendar
    private let fullDateFormatter: DateFormatter
    private let abbreviatedDateFormatter: DateFormatter
    private let numericDateFormatter: DateFormatter

    private var currentTableLayout: HomeProfilesTableLayout?
    private var cachedTableLayoutMetrics: HomeProfilesTableLayout.Metrics?
    private var isApplyingTableLayout = false

    /// While the user drags a window edge, the table switches once to the
    /// narrowest safe presentation. AppKit then resizes only the Profile column
    /// natively until the drag ends. This avoids repeatedly rebuilding table
    /// cells at every responsive threshold and prevents stale wide columns from
    /// extending beyond the clip view during a fast resize.
    private var isTableLiveResizeActive = false

    private let titleLabel = NSTextField(
        labelWithString: "Profiles"
    )
    private let addButton = NSButton()
    private let titleStack = NSStackView()

    private let descriptionLabel = NSTextField(
        wrappingLabelWithString:
            "Create independent remapping configurations, choose their shortcuts, and select which profile will become active after Home Save."
    )

    private let searchField = NSSearchField()
    private let sortByNameButton = NSButton()
    private let sortByCreationDateButton = NSButton()
    private let searchAndSortStack = NSStackView()

    private let tableView = NSTableView()
    private let tableScrollView = NSScrollView()
    private let emptyResultsLabel = NSTextField(
        labelWithString: "No profiles match the current search."
    )

    private let contentStack = NSStackView()
    private var tableHeightConstraint: NSLayoutConstraint?

    init(
        editorSession: HomeConfigurationEditorSession?,
        initialConfiguration: RemappingProfilesConfiguration,
        validator: RemappingProfilesConfigurationValidating =
            RemappingProfilesConfigurationValidator(),
        dateLocale: Locale = .autoupdatingCurrent,
        dateCalendar: Calendar = .autoupdatingCurrent
    ) {
        self.editorSession = editorSession
        configuration = initialConfiguration
        self.validator = validator
        self.dateLocale = dateLocale
        self.dateCalendar = dateCalendar

        fullDateFormatter = DateFormatter()
        abbreviatedDateFormatter = DateFormatter()
        numericDateFormatter = DateFormatter()

        super.init(frame: .zero)

        configureDateFormatter(
            fullDateFormatter,
            style: .long
        )
        configureDateFormatter(
            abbreviatedDateFormatter,
            style: .medium
        )
        configureDateFormatter(
            numericDateFormatter,
            style: .short
        )

        configureContent()
        load(configuration: initialConfiguration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        guard !isTableLiveResizeActive else {
            return
        }

        applyResponsiveTableLayout()
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()

        beginTableLiveResize()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()

        // The final clip-view width can settle during the last AppKit layout
        // pass. Resolve the normal responsive stage once after that pass.
        window?.contentView?.layoutSubtreeIfNeeded()
        endTableLiveResize()
    }

    /// Replaces the displayed Home draft without changing search or sorting.
    func load(configuration: RemappingProfilesConfiguration) {
        self.configuration = configuration

        if let selectedProfileID,
           configuration.profile(id: selectedProfileID) == nil
        {
            self.selectedProfileID = nil
        }

        reloadPresentation()
    }

    /// Refreshes rule counts after a profile-specific Rules Save.
    ///
    /// This is presentation-only and intentionally does not rewrite the Home
    /// draft or its Undo/Redo history.
    func updatePersistedRuleCounts(
        from persistedConfiguration: RemappingProfilesConfiguration
    ) {
        persistedRuleCounts = Dictionary(
            uniqueKeysWithValues:
                persistedConfiguration.profiles.map { profile in
                    (profile.id, profile.rules.count)
                }
        )

        tableView.reloadData()
    }

    func applyTextScale(_ scale: CGFloat) {
        textScale = scale

        titleLabel.font = NSFont.systemFont(
            ofSize: 14 * scale,
            weight: .semibold
        )
        descriptionLabel.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )
        searchField.font = NSFont.systemFont(
            ofSize: 13 * scale,
            weight: .regular
        )
        sortByNameButton.font = NSFont.systemFont(
            ofSize: 12 * scale,
            weight: .regular
        )
        sortByCreationDateButton.font = sortByNameButton.font
        emptyResultsLabel.font = NSFont.systemFont(
            ofSize: 12 * scale,
            weight: .regular
        )

        tableView.rowHeight = max(34, 36 * scale)
        tableView.headerView?.frame.size.height = max(24, 25 * scale)

        titleStack.spacing = InterfaceLayoutMetrics.scaled(
            6,
            for: scale,
            minimum: 4,
            maximum: 10
        )
        contentStack.spacing = InterfaceLayoutMetrics.scaled(
            5,
            for: scale,
            minimum: 4,
            maximum: 8
        )
        contentStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                4,
                for: scale,
                minimum: 3,
                maximum: 7
            ),
            after: titleStack
        )
        contentStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                6,
                for: scale,
                minimum: 4,
                maximum: 9
            ),
            after: descriptionLabel
        )
        searchAndSortStack.spacing = InterfaceLayoutMetrics.scaled(
            7,
            for: scale,
            minimum: 5,
            maximum: 11
        )

        currentTableLayout = nil
        cachedTableLayoutMetrics = nil

        // A scale change can happen while the previous responsive stage is
        // compact. Since a nil layout presents labeled controls, widen the
        // fallback columns before reloading those cells. The next layout pass
        // immediately resolves the real responsive stage again.
        applySafeFallbackTableLayout()

        updateTableHeight()
        tableView.reloadData()
        needsLayout = true
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleProfiles.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard visibleProfiles.indices.contains(row),
              let tableColumn
        else {
            return nil
        }

        let profile = visibleProfiles[row]

        switch tableColumn.identifier {
        case Column.profile:
            return makeProfileCell(for: profile)
        case Column.rules:
            return makeRulesCell(for: profile)
        case Column.shortcut:
            return makeShortcutCell(for: profile)
        case Column.created:
            return makeCreatedCell(for: profile)
        case Column.actions:
            return makeActionsCell(for: profile)
        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow

        guard visibleProfiles.indices.contains(selectedRow) else {
            selectedProfileID = nil
            return
        }

        selectedProfileID = visibleProfiles[selectedRow].id
    }

    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSSearchField === searchField else {
            return
        }

        presentationModel.searchText = searchField.stringValue
        reloadPresentation()
    }

    // MARK: - Test support

    var visibleProfileIDsForTesting: [UUID] {
        visibleProfiles.map(\.id)
    }

    var selectedProfileIDForTesting: UUID? {
        selectedProfileID
    }

    var visibleRowCapacityForTesting: Int {
        min(max(visibleProfiles.count, 1), 4)
    }

    var usesVerticalScrollingForTesting: Bool {
        tableScrollView.hasVerticalScroller
    }

    var usesHorizontalScrollingForTesting: Bool {
        tableScrollView.hasHorizontalScroller
    }

    var horizontalScrollElasticityForTesting: NSScrollView.Elasticity {
        tableScrollView.horizontalScrollElasticity
    }

    var columnIdentifiersForTesting: [String] {
        tableView.tableColumns.map { $0.identifier.rawValue }
    }

    var currentLayoutStageForTesting: HomeProfilesTableLayout.Stage? {
        currentTableLayout?.stage
    }

    var currentActionsPresentationForTesting:
        HomeProfilesTableLayout.ActionsPresentation?
    {
        currentTableLayout?.actionsPresentation
    }

    var currentShortcutEditPresentationForTesting:
        HomeProfilesTableLayout.ShortcutEditPresentation?
    {
        currentTableLayout?.shortcutEditPresentation
    }

    var currentDatePresentationForTesting:
        HomeProfilesTableLayout.DatePresentation?
    {
        currentTableLayout?.datePresentation
    }

    var currentColumnWidthsForTesting: [CGFloat] {
        tableView.tableColumns.map(\.width)
    }

    var currentTableLayoutWidthForTesting: CGFloat {
        currentTableLayout?.totalWidth ?? 0
    }

    var usesNativeProfileColumnAutoresizingForTesting: Bool {
        guard
            tableView.columnAutoresizingStyle
                == .firstColumnOnlyAutoresizingStyle,
            let profileColumn = tableView.tableColumn(
                withIdentifier: Column.profile
            )
        else {
            return false
        }

        let fixedColumns = [
            Column.rules,
            Column.shortcut,
            Column.created,
            Column.actions
        ].compactMap {
            tableView.tableColumn(
                withIdentifier: $0
            )
        }

        return profileColumn.resizingMask.contains(
            .autoresizingMask
        )
            && fixedColumns.allSatisfy {
                !$0.resizingMask.contains(
                    .autoresizingMask
                )
            }
    }

    func setSearchTextForTesting(_ searchText: String) {
        searchField.stringValue = searchText
        presentationModel.searchText = searchText
        reloadPresentation()
    }

    func toggleSortForTesting(
        _ sortKey: HomeProfilesPresentationModel.SortKey
    ) {
        presentationModel.toggleSort(sortKey)
        reloadPresentation()
    }

    func openVisibleProfileForTesting(at index: Int) {
        guard visibleProfiles.indices.contains(index) else {
            return
        }

        onOpenProfile?(visibleProfiles[index].id)
    }

    func editShortcutForVisibleProfileForTesting(at index: Int) {
        guard editorSession != nil,
              visibleProfiles.indices.contains(index)
        else {
            return
        }

        onEditShortcut?(visibleProfiles[index].id)
    }

    func duplicateVisibleProfileForTesting(at index: Int) {
        guard editorSession != nil,
              visibleProfiles.indices.contains(index)
        else {
            return
        }

        duplicateProfile(id: visibleProfiles[index].id)
    }

    func shortcutTitleForVisibleProfileForTesting(
        at index: Int
    ) -> String? {
        guard visibleProfiles.indices.contains(index) else {
            return nil
        }

        return ProfileShortcutConfigurationPresentation.tableTitle(
            for: visibleProfiles[index].shortcutConfigurationOverride
        )
    }

    func applyTableLayoutForTesting(
        stage: HomeProfilesTableLayout.Stage
    ) {
        let width = HomeProfilesTableLayout.minimumRequiredWidth(
            for: stage,
            metrics: makeTableLayoutMetrics()
        )

        applyResponsiveTableLayout(
            availableWidth: width,
            forceReload: true
        )
    }

    func applyTableAvailableWidthForTesting(
        _ width: CGFloat
    ) {
        applyResponsiveTableLayout(
            availableWidth: width
        )
    }

    func minimumWidthForTableLayoutStageForTesting(
        _ stage: HomeProfilesTableLayout.Stage
    ) -> CGFloat {
        HomeProfilesTableLayout.minimumRequiredWidth(
            for: stage,
            metrics: makeTableLayoutMetrics()
        )
    }

    func createdDateTitleForVisibleProfileForTesting(
        at index: Int
    ) -> String? {
        guard visibleProfiles.indices.contains(index) else {
            return nil
        }

        return formattedCreationDate(
            visibleProfiles[index].createdAt
        )
    }

    func actionsColumnWidthForTesting(
        symbolsOnly: Bool
    ) -> CGFloat {
        requiredActionsColumnWidth(
            symbolsOnly: symbolsOnly
        )
    }

    func openActionButtonWidthForTesting(
        symbolsOnly: Bool
    ) -> CGFloat? {
        guard let profile = configuration.profiles.first else {
            return nil
        }

        guard let button = makeActionButtons(
            for: profile,
            symbolsOnly: symbolsOnly
        ).first else {
            return nil
        }

        return fixedActionButtonWidth(button)
    }

    func renameActionButtonWidthForTesting(
        symbolsOnly: Bool
    ) -> CGFloat? {
        guard let profile = configuration.profiles.first else {
            return nil
        }

        let buttons = makeActionButtons(
            for: profile,
            symbolsOnly: symbolsOnly
        )

        guard buttons.indices.contains(1) else {
            return nil
        }

        return fixedActionButtonWidth(buttons[1])
    }

    func openActionFitsForTesting(
        at index: Int,
        stage: HomeProfilesTableLayout.Stage
    ) -> Bool {
        guard let button = preparedOpenActionButtonForTesting(
            at: index,
            stage: stage
        ) else {
            return false
        }

        let requiredContentWidth = idealActionButtonWidth(button)

        return button.frame.width + 0.5
            >= requiredContentWidth
    }

    @discardableResult
    func performOpenActionClickForTesting(
        at index: Int,
        stage: HomeProfilesTableLayout.Stage
    ) -> Bool {
        guard let button = preparedOpenActionButtonForTesting(
            at: index,
            stage: stage
        ) else {
            return false
        }

        button.performClick(nil)
        return true
    }

    func actionButtonsUseManualFramesForTesting(
        at index: Int,
        stage: HomeProfilesTableLayout.Stage
    ) -> Bool {
        guard visibleProfiles.indices.contains(index) else {
            return false
        }

        applyTableLayoutForTesting(stage: stage)

        guard let cell = makeActionsCell(
            for: visibleProfiles[index]
        ) as? ProfileActionsCellView else {
            return false
        }

        let buttons = cell.subviews.compactMap { $0 as? NSButton }

        return buttons.count == 4
            && buttons.allSatisfy { button in
                !button.constraints.contains { constraint in
                    constraint.firstItem as? NSButton === button
                        && constraint.firstAttribute == .width
                        && constraint.relation == .equal
                }
            }
    }

    func openActionIsHitTestableForTesting(
        at index: Int,
        stage: HomeProfilesTableLayout.Stage
    ) -> Bool {
        guard visibleProfiles.indices.contains(index) else {
            return false
        }

        applyTableLayoutForTesting(stage: stage)

        let cell = makeActionsCell(
            for: visibleProfiles[index]
        )

        cell.frame = NSRect(
            x: 0,
            y: 0,
            width: currentTableLayout?.actionsWidth ?? 0,
            height: tableView.rowHeight
        )
        cell.layoutSubtreeIfNeeded()

        guard let button = descendantButton(
            in: cell,
            identifier: ActionButtonIdentifier.open
        ) else {
            return false
        }

        let centerInCell = button.convert(
            NSPoint(
                x: button.bounds.midX,
                y: button.bounds.midY
            ),
            to: cell
        )

        guard let hitView = cell.hitTest(centerInCell) else {
            return false
        }

        return hitView === button
            || hitView.isDescendant(of: button)
    }

    var isUsingLiveResizeTableLayoutForTesting: Bool {
        isTableLiveResizeActive
    }

    func beginTableLiveResizeForTesting() {
        beginTableLiveResize()
    }

    func endTableLiveResizeForTesting(
        availableWidth: CGFloat
    ) {
        endTableLiveResize(
            availableWidth: availableWidth
        )
    }

    // MARK: - Configuration

    private func configureDateFormatter(
        _ formatter: DateFormatter,
        style: DateFormatter.Style
    ) {
        formatter.locale = dateLocale
        formatter.calendar = dateCalendar
        formatter.timeZone = dateCalendar.timeZone
        formatter.dateStyle = style
        formatter.timeStyle = .none
    }

    private func configureContent() {
        wantsLayer = true

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        addButton.title = ""
        addButton.image = NSImage(
            systemSymbolName: "plus",
            accessibilityDescription: "Add profile"
        )
        addButton.imagePosition = .imageOnly
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addProfile)
        addButton.toolTip = "Add a new empty remapping profile."
        addButton.setAccessibilityLabel("Add profile")
        addButton.isEnabled = editorSession != nil
        addButton.setContentHuggingPriority(.required, for: .horizontal)

        titleStack.setViews(
            [titleLabel, addButton],
            in: .leading
        )
        titleStack.orientation = .horizontal
        titleStack.alignment = .centerY

        descriptionLabel.textColor = .secondaryLabelColor

        searchField.placeholderString = "Search profiles"
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.setAccessibilityLabel("Search profiles")

        configureSortButton(
            sortByNameButton,
            action: #selector(sortByName),
            accessibilityLabel: "Sort profiles by name"
        )
        configureSortButton(
            sortByCreationDateButton,
            action: #selector(sortByCreationDate),
            accessibilityLabel: "Sort profiles by creation date"
        )

        searchField.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        searchAndSortStack.setViews(
            [
                searchField,
                sortByNameButton,
                sortByCreationDateButton
            ],
            in: .leading
        )
        searchAndSortStack.orientation = .horizontal
        searchAndSortStack.alignment = .centerY
        searchAndSortStack.distribution = .fill

        configureTable()

        contentStack.setViews(
            [
                titleStack,
                descriptionLabel,
                searchAndSortStack,
                tableScrollView
            ],
            in: .leading
        )
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStack)

        NSLayoutConstraint.activate(
            [
                contentStack.topAnchor.constraint(equalTo: topAnchor),
                contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
                titleStack.widthAnchor.constraint(
                    lessThanOrEqualTo: contentStack.widthAnchor
                ),
                descriptionLabel.widthAnchor.constraint(
                    equalTo: contentStack.widthAnchor
                ),
                searchAndSortStack.widthAnchor.constraint(
                    equalTo: contentStack.widthAnchor
                ),
                tableScrollView.widthAnchor.constraint(
                    equalTo: contentStack.widthAnchor
                )
            ]
        )

        applyTextScale(1.0)
    }

    private func configureSortButton(
        _ button: NSButton,
        action: Selector,
        accessibilityLabel: String
    ) {
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.setAccessibilityLabel(accessibilityLabel)
        button.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func configureTable() {
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = false
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.autoresizingMask = [.width]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelectedProfile)

        let profileColumn = NSTableColumn(identifier: Column.profile)
        profileColumn.title = "Profile"
        profileColumn.width = 210
        profileColumn.resizingMask = [.autoresizingMask]

        let rulesColumn = NSTableColumn(identifier: Column.rules)
        rulesColumn.title = "Rules"
        rulesColumn.width = 60
        rulesColumn.resizingMask = []

        let shortcutColumn = NSTableColumn(identifier: Column.shortcut)
        shortcutColumn.title = "Shortcut"
        shortcutColumn.width = 165
        shortcutColumn.resizingMask = []

        let createdColumn = NSTableColumn(identifier: Column.created)
        createdColumn.title = "Created"
        createdColumn.width = 110
        createdColumn.resizingMask = []

        let actionsColumn = NSTableColumn(identifier: Column.actions)
        actionsColumn.title = "Actions"
        actionsColumn.width = 205
        actionsColumn.resizingMask = []

        tableView.addTableColumn(profileColumn)
        tableView.addTableColumn(rulesColumn)
        tableView.addTableColumn(shortcutColumn)
        tableView.addTableColumn(createdColumn)
        tableView.addTableColumn(actionsColumn)

        // `load(configuration:)` can reload rows before this view receives its
        // first non-zero layout width. Give labeled cells a safe, internally
        // consistent fallback now so AppKit never has to break the action
        // button width constraints inside the initial 205-point column.
        applySafeFallbackTableLayout()

        tableScrollView.borderType = .bezelBorder
        tableScrollView.drawsBackground = true
        tableScrollView.hasHorizontalScroller = false
        tableScrollView.horizontalScrollElasticity = .none
        tableScrollView.autohidesScrollers = true
        tableScrollView.documentView = tableView
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false

        emptyResultsLabel.textColor = .secondaryLabelColor
        emptyResultsLabel.alignment = .center
        emptyResultsLabel.isHidden = true
        emptyResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        tableScrollView.addSubview(emptyResultsLabel)

        NSLayoutConstraint.activate(
            [
                emptyResultsLabel.centerXAnchor.constraint(
                    equalTo: tableScrollView.centerXAnchor
                ),
                emptyResultsLabel.centerYAnchor.constraint(
                    equalTo: tableScrollView.centerYAnchor,
                    constant: 10
                ),
                emptyResultsLabel.leadingAnchor.constraint(
                    greaterThanOrEqualTo: tableScrollView.leadingAnchor,
                    constant: 12
                ),
                emptyResultsLabel.trailingAnchor.constraint(
                    lessThanOrEqualTo: tableScrollView.trailingAnchor,
                    constant: -12
                )
            ]
        )

        let tableHeightConstraint = tableScrollView.heightAnchor.constraint(
            equalToConstant: 1
        )
        self.tableHeightConstraint = tableHeightConstraint
        tableHeightConstraint.isActive = true
    }

    /// Installs a conflict-free labeled layout for reloads that occur before
    /// the view has a usable clip-view width (notably during initialization and
    /// text-scale changes). A normal layout pass replaces these widths with the
    /// appropriate responsive stage.
    private func applySafeFallbackTableLayout() {
        let metrics = makeTableLayoutMetrics()
        let fallbackWidth = HomeProfilesTableLayout.minimumRequiredWidth(
            for: .abbreviatedDate,
            metrics: metrics
        )
        let layout = HomeProfilesTableLayout.resolved(
            availableWidth: fallbackWidth,
            metrics: metrics
        )

        applyColumnConfiguration(
            layout,
            metrics: metrics
        )
        currentTableLayout = layout
    }

    /// Enters one stable, conflict-free table presentation for the complete
    /// live-resize gesture. The visible table is rebuilt at most once here;
    /// every intermediate pixel is then handled by AppKit's native Profile
    /// column autoresizing without changing fixed columns or row views.
    private func beginTableLiveResize() {
        guard !isTableLiveResizeActive else {
            return
        }

        isTableLiveResizeActive = true

        let metrics = makeTableLayoutMetrics()
        let compactWidth = HomeProfilesTableLayout.minimumRequiredWidth(
            for: .compactDate,
            metrics: metrics
        )
        let compactLayout = HomeProfilesTableLayout.resolved(
            availableWidth: compactWidth,
            metrics: metrics
        )

        guard currentTableLayout?.stage != .compactDate else {
            return
        }

        isApplyingTableLayout = true
        defer { isApplyingTableLayout = false }

        applyColumnConfiguration(
            compactLayout,
            metrics: metrics
        )
        currentTableLayout = compactLayout
        tableView.tile()
        tableScrollView.tile()
        tableView.reloadData()
        restoreSelection()
    }

    /// Restores the presentation appropriate for the final window width after
    /// the user releases the resize handle. This is the only responsive rebuild
    /// performed after the compact live-resize presentation is installed.
    private func endTableLiveResize(
        availableWidth explicitAvailableWidth: CGFloat? = nil
    ) {
        guard isTableLiveResizeActive else {
            return
        }

        isTableLiveResizeActive = false

        let availableWidth = floor(
            explicitAvailableWidth
                ?? tableScrollView.contentView.bounds.width
        )

        guard availableWidth > 0 else {
            needsLayout = true
            return
        }

        applyResponsiveTableLayout(
            availableWidth: availableWidth,
            forceReload: true
        )
        tableView.tile()
        tableScrollView.tile()
    }

    // MARK: - Responsive table layout

    /// Applies only responsive *stage* transitions.
    ///
    /// While the window remains inside one stage, AppKit's native first-column
    /// autoresizing absorbs every intermediate width change in the Profile
    /// column. This avoids rewriting an NSTableColumn on every pixel of a live
    /// resize, which is substantially more expensive than the model calculation
    /// itself because it invalidates all visible table rows and headers.
    private func applyResponsiveTableLayout(
        availableWidth explicitAvailableWidth: CGFloat? = nil,
        forceReload: Bool = false
    ) {
        guard !isApplyingTableLayout else {
            return
        }

        let availableWidth = floor(
            explicitAvailableWidth
                ?? tableScrollView.contentView.bounds.width
        )

        guard availableWidth > 0 else {
            return
        }

        let metrics = makeTableLayoutMetrics()
        let layout = HomeProfilesTableLayout.resolved(
            availableWidth: availableWidth,
            metrics: metrics
        )
        let previousLayout = currentTableLayout
        let stageChanged =
            previousLayout?.stage != layout.stage
        let presentationChanged =
            previousLayout?.actionsPresentation
                != layout.actionsPresentation
            || previousLayout?.shortcutEditPresentation
                != layout.shortcutEditPresentation
            || previousLayout?.datePresentation
                != layout.datePresentation

        // Keep the presentation model current for formatting and tests, but do
        // no table-column work for the many intermediate widths inside a stage.
        currentTableLayout = layout

        guard stageChanged || forceReload else {
            return
        }

        isApplyingTableLayout = true
        defer { isApplyingTableLayout = false }

        applyColumnConfiguration(
            layout,
            metrics: metrics
        )

        if forceReload || presentationChanged {
            tableView.reloadData()
            restoreSelection()
        }
    }

    private func applyColumnConfiguration(
        _ layout: HomeProfilesTableLayout,
        metrics: HomeProfilesTableLayout.Metrics
    ) {
        configureFlexibleProfileColumn(
            width: max(
                metrics.minimumProfileWidth,
                layout.profileWidth
            ),
            minimumWidth: metrics.minimumProfileWidth
        )

        setFixedColumnWidth(
            layout.rulesWidth,
            identifier: Column.rules
        )
        setFixedColumnWidth(
            layout.shortcutWidth,
            identifier: Column.shortcut
        )
        setFixedColumnWidth(
            layout.createdWidth,
            identifier: Column.created
        )
        setFixedColumnWidth(
            layout.actionsWidth,
            identifier: Column.actions
        )
    }

    private func configureFlexibleProfileColumn(
        width: CGFloat,
        minimumWidth: CGFloat
    ) {
        guard let column = tableView.tableColumn(
            withIdentifier: Column.profile
        ) else {
            return
        }

        let normalizedMinimum = max(0, minimumWidth)
        let normalizedWidth = max(
            normalizedMinimum,
            width
        )

        column.resizingMask = [.autoresizingMask]
        column.minWidth = normalizedMinimum
        column.maxWidth = .greatestFiniteMagnitude

        if abs(column.width - normalizedWidth) >= 0.5 {
            column.width = normalizedWidth
        }
    }

    private func setFixedColumnWidth(
        _ width: CGFloat,
        identifier: NSUserInterfaceItemIdentifier
    ) {
        guard let column = tableView.tableColumn(withIdentifier: identifier) else {
            return
        }

        let normalizedWidth = max(0, width)

        column.resizingMask = []

        if abs(column.width - normalizedWidth) < 0.5,
           abs(column.minWidth - normalizedWidth) < 0.5,
           abs(column.maxWidth - normalizedWidth) < 0.5
        {
            return
        }

        column.minWidth = 0
        column.maxWidth = .greatestFiniteMagnitude
        column.width = normalizedWidth
        column.minWidth = normalizedWidth
        column.maxWidth = normalizedWidth
    }

    private func makeTableLayoutMetrics()
        -> HomeProfilesTableLayout.Metrics
    {
        if let cachedTableLayoutMetrics {
            return cachedTableLayoutMetrics
        }

        let bodyFont = NSFont.systemFont(
            ofSize: 12 * textScale,
            weight: .regular
        )
        let headerFont = NSFont.systemFont(
            ofSize: 11 * textScale,
            weight: .regular
        )

        let minimumProfileWidth = InterfaceLayoutMetrics.scaled(
            155,
            for: textScale,
            minimum: 125,
            maximum: 220
        )

        let rulesWidth = max(
            InterfaceLayoutMetrics.scaled(
                60,
                for: textScale,
                minimum: 50,
                maximum: 80
            ),
            measuredTextWidth("Rules", font: headerFont) + 16
        )

        let labeledShortcutWidth = InterfaceLayoutMetrics.scaled(
            165,
            for: textScale,
            minimum: 145,
            maximum: 220
        )
        let symbolShortcutWidth = InterfaceLayoutMetrics.scaled(
            120,
            for: textScale,
            minimum: 105,
            maximum: 155
        )

        let widestFullDateWidth = max(
            InterfaceLayoutMetrics.scaled(
                145,
                for: textScale,
                minimum: 125,
                maximum: 210
            ),
            widestFormattedDateWidth(
                using: fullDateFormatter,
                font: bodyFont,
                includesSafetyCharacter: true
            )
        )

        let abbreviatedDateWidth = max(
            InterfaceLayoutMetrics.scaled(
                110,
                for: textScale,
                minimum: 95,
                maximum: 160
            ),
            widestFormattedDateWidth(
                using: abbreviatedDateFormatter,
                font: bodyFont,
                includesSafetyCharacter: false
            )
        )

        let numericDateWidth = max(
            InterfaceLayoutMetrics.scaled(
                82,
                for: textScale,
                minimum: 72,
                maximum: 120
            ),
            widestFormattedDateWidth(
                using: numericDateFormatter,
                font: bodyFont,
                includesSafetyCharacter: false
            )
        )

        let labeledActionsWidth = max(
            InterfaceLayoutMetrics.scaled(
                205,
                for: textScale,
                minimum: 180,
                maximum: 320
            ),
            requiredActionsColumnWidth(
                symbolsOnly: false
            )
        )
        let symbolActionsWidth = max(
            InterfaceLayoutMetrics.scaled(
                116,
                for: textScale,
                minimum: 104,
                maximum: 190
            ),
            requiredActionsColumnWidth(
                symbolsOnly: true
            )
        )

        let metrics = HomeProfilesTableLayout.Metrics(
            minimumProfileWidth: minimumProfileWidth,
            rulesWidth: rulesWidth,
            labeledShortcutWidth: labeledShortcutWidth,
            symbolShortcutWidth: symbolShortcutWidth,
            widestFullDateWidth: widestFullDateWidth,
            abbreviatedDateWidth: abbreviatedDateWidth,
            numericDateWidth: numericDateWidth,
            labeledActionsWidth: labeledActionsWidth,
            symbolActionsWidth: symbolActionsWidth,
            columnSpacing: tableView.intercellSpacing.width
        )

        cachedTableLayoutMetrics = metrics
        return metrics
    }

    private func widestFormattedDateWidth(
        using formatter: DateFormatter,
        font: NSFont,
        includesSafetyCharacter: Bool
    ) -> CGFloat {
        let widestDateWidth = referenceDatesForAllMonths()
            .map { date in
                measuredTextWidth(
                    formatter.string(from: date),
                    font: font
                )
            }
            .max()
            ?? 0

        let safetyWidth = includesSafetyCharacter
            ? measuredTextWidth("M", font: font)
            : 0

        return ceil(
            widestDateWidth
                + safetyWidth
                + 12
        )
    }

    private func referenceDatesForAllMonths() -> [Date] {
        (1...12).compactMap { month in
            var components = DateComponents()
            components.calendar = dateCalendar
            components.timeZone = dateCalendar.timeZone
            components.year = 2088
            components.month = month
            components.day = 28

            return dateCalendar.date(from: components)
        }
    }

    private func measuredTextWidth(
        _ text: String,
        font: NSFont
    ) -> CGFloat {
        ceil(
            (text as NSString).size(
                withAttributes: [
                    .font: font
                ]
            ).width
        )
    }

    // MARK: - Presentation

    private func reloadPresentation() {
        visibleProfiles = presentationModel.visibleProfiles(
            from: configuration.profiles
        )

        updateSortButtonTitles()
        tableView.reloadData()
        restoreSelection()
        updateTableHeight()
        needsLayout = true
    }

    private func restoreSelection() {
        guard let selectedProfileID,
              let visibleIndex = visibleProfiles.firstIndex(
                  where: { $0.id == selectedProfileID }
              )
        else {
            tableView.deselectAll(nil)
            return
        }

        tableView.selectRowIndexes(
            IndexSet(integer: visibleIndex),
            byExtendingSelection: false
        )
    }

    private func updateTableHeight() {
        let visibleRowCapacity = min(
            max(visibleProfiles.count, 1),
            4
        )
        let headerHeight = tableView.headerView?.frame.height ?? 25

        tableHeightConstraint?.constant = ceil(
            headerHeight
                + CGFloat(visibleRowCapacity) * tableView.rowHeight
                + 3
        )

        tableScrollView.hasVerticalScroller = visibleProfiles.count > 4
        tableScrollView.tile()
        emptyResultsLabel.isHidden = !visibleProfiles.isEmpty
        onPreferredHeightChange?()
    }

    private func updateSortButtonTitles() {
        sortByNameButton.title = sortButtonTitle(
            baseTitle: "Name",
            key: .name
        )
        sortByCreationDateButton.title = sortButtonTitle(
            baseTitle: "Created",
            key: .creationDate
        )
    }

    private func sortButtonTitle(
        baseTitle: String,
        key: HomeProfilesPresentationModel.SortKey
    ) -> String {
        guard presentationModel.sortKey == key else {
            return baseTitle
        }

        let directionSymbol = presentationModel.sortDirection == .ascending
            ? "↑"
            : "↓"

        return "\(baseTitle) \(directionSymbol)"
    }

    private func makeProfileCell(for profile: RemappingProfile) -> NSView {
        let cell = NSTableCellView()

        let activeButton = ProfileIDButton(
            radioButtonWithTitle: "",
            target: self,
            action: #selector(activeProfileChanged)
        )
        activeButton.profileID = profile.id
        activeButton.state = configuration.activeProfileID == profile.id
            ? .on
            : .off
        activeButton.isEnabled = editorSession != nil
        activeButton.toolTip =
            "Set “\(profile.name)” as the active profile after Home Save."
        activeButton.setAccessibilityLabel(
            "Set “\(profile.name)” as active profile"
        )

        let nameLabel = NSTextField(
            labelWithString: profile.name
        )
        nameLabel.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.toolTip = profile.name

        let activeLabel = NSTextField(
            labelWithString:
                configuration.activeProfileID == profile.id
                    ? "Active"
                    : ""
        )
        activeLabel.font = NSFont.systemFont(
            ofSize: 11 * textScale,
            weight: .semibold
        )
        activeLabel.textColor = .secondaryLabelColor
        activeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(
            views: [
                activeButton,
                nameLabel,
                activeLabel
            ]
        )
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(stack)

        NSLayoutConstraint.activate(
            [
                stack.leadingAnchor.constraint(
                    equalTo: cell.leadingAnchor,
                    constant: 6
                ),
                stack.trailingAnchor.constraint(
                    equalTo: cell.trailingAnchor,
                    constant: -6
                ),
                stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ]
        )

        return cell
    }

    private func makeRulesCell(for profile: RemappingProfile) -> NSView {
        let ruleCount = persistedRuleCounts[profile.id]
            ?? profile.rules.count
        let label = NSTextField(
            labelWithString: String(ruleCount)
        )
        label.alignment = .center
        label.font = NSFont.systemFont(
            ofSize: 13 * textScale,
            weight: .regular
        )

        return centeredCell(containing: label)
    }

    private func makeShortcutCell(for profile: RemappingProfile) -> NSView {
        let summary = ProfileShortcutConfigurationPresentation.tableTitle(
            for: profile.shortcutConfigurationOverride
        )

        let summaryLabel = NSTextField(
            labelWithString: summary
        )
        summaryLabel.font = NSFont.systemFont(
            ofSize: 12 * textScale,
            weight: .regular
        )
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.toolTip = shortcutToolTip(for: profile)
        summaryLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        let usesSymbolOnly = currentTableLayout?
            .shortcutEditPresentation == .symbolOnly

        let editButton = actionButton(
            title: usesSymbolOnly ? "" : "Edit…",
            systemImageName: "keyboard",
            accessibilityLabel: "Edit shortcut for “\(profile.name)”",
            toolTip:
                "Edit the shortcut configuration for “\(profile.name)”.",
            selector: #selector(editProfileShortcut),
            profileID: profile.id
        )
        editButton.isEnabled = editorSession != nil

        let stack = NSStackView(
            views: [
                summaryLabel,
                editButton
            ]
        )
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let cell = NSTableCellView()
        cell.addSubview(stack)

        NSLayoutConstraint.activate(
            [
                stack.leadingAnchor.constraint(
                    equalTo: cell.leadingAnchor,
                    constant: 5
                ),
                stack.trailingAnchor.constraint(
                    equalTo: cell.trailingAnchor,
                    constant: -5
                ),
                stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ]
        )

        return cell
    }

    private func shortcutToolTip(for profile: RemappingProfile) -> String {
        guard let override = profile.shortcutConfigurationOverride else {
            return "Uses Default Global Shortcuts."
        }

        return ProfileShortcutConfigurationPresentation.configurationTitle(
            override
        )
    }

    private func makeCreatedCell(for profile: RemappingProfile) -> NSView {
        let label = NSTextField(
            labelWithString: formattedCreationDate(profile.createdAt)
        )
        label.alignment = .center
        label.font = NSFont.systemFont(
            ofSize: 12 * textScale,
            weight: .regular
        )
        label.textColor = .secondaryLabelColor

        return centeredCell(containing: label)
    }

    private func formattedCreationDate(_ date: Date) -> String {
        switch currentTableLayout?.datePresentation ?? .abbreviatedMonth {
        case .fullMonth:
            return fullDateFormatter.string(from: date)
        case .abbreviatedMonth:
            return abbreviatedDateFormatter.string(from: date)
        case .numeric:
            return numericDateFormatter.string(from: date)
        }
    }

    private func makeActionsCell(for profile: RemappingProfile) -> NSView {
        let usesSymbolsOnly = currentTableLayout?
            .actionsPresentation == .symbolsOnly

        let buttons = makeActionButtons(
            for: profile,
            symbolsOnly: usesSymbolsOnly
        )
        let widths = buttons.map(idealActionButtonWidth)

        return ProfileActionsCellView(
            buttons: buttons,
            widths: widths,
            spacing: ActionsLayoutMetrics.buttonSpacing,
            leadingPadding: ActionsLayoutMetrics.leadingPadding
        )
    }

    private func makeActionButtons(
        for profile: RemappingProfile,
        symbolsOnly: Bool
    ) -> [ProfileIDButton] {
        let openButton = actionButton(
            title: symbolsOnly ? "" : "Open",
            systemImageName: "arrow.up.right.square",
            identifier: ActionButtonIdentifier.open,
            accessibilityLabel: "Open rules for “\(profile.name)”",
            toolTip: "Open the Rules window for “\(profile.name)”.",
            selector: #selector(openProfile),
            profileID: profile.id
        )

        let renameButton = actionButton(
            title: symbolsOnly ? "" : "Rename",
            systemImageName: "pencil",
            identifier: ActionButtonIdentifier.rename,
            accessibilityLabel: "Rename “\(profile.name)”",
            toolTip: "Rename “\(profile.name)”.",
            selector: #selector(renameProfile),
            profileID: profile.id
        )
        renameButton.isEnabled = editorSession != nil

        let duplicateButton = actionButton(
            title: "",
            systemImageName: "doc.on.doc",
            identifier: ActionButtonIdentifier.duplicate,
            accessibilityLabel: "Duplicate “\(profile.name)”",
            toolTip:
                "Duplicate “\(profile.name)” with its rules, exceptions, and shortcut settings.",
            selector: #selector(duplicateProfileButtonPressed),
            profileID: profile.id
        )
        duplicateButton.isEnabled = editorSession != nil

        let deleteButton = actionButton(
            title: "",
            systemImageName: "trash",
            identifier: ActionButtonIdentifier.delete,
            accessibilityLabel: "Delete “\(profile.name)”",
            toolTip: deleteToolTip(for: profile),
            selector: #selector(deleteProfile),
            profileID: profile.id
        )
        deleteButton.contentTintColor = .systemRed
        deleteButton.isEnabled = canDelete(profile)

        return [
            openButton,
            renameButton,
            duplicateButton,
            deleteButton
        ]
    }

    private func requiredActionsColumnWidth(
        symbolsOnly: Bool
    ) -> CGFloat {
        let measurementProfile = configuration.profiles.first
            ?? RemappingProfile(
                name: "Measurement"
            )

        let buttons = makeActionButtons(
            for: measurementProfile,
            symbolsOnly: symbolsOnly
        )

        let buttonsWidth = buttons.reduce(CGFloat.zero) {
            partialResult,
            button in

            partialResult
                + fixedActionButtonWidth(button)
        }

        let spacingWidth = ActionsLayoutMetrics.buttonSpacing
            * CGFloat(max(buttons.count - 1, 0))

        return ceil(
            ActionsLayoutMetrics.leadingPadding
                + buttonsWidth
                + spacingWidth
                + ActionsLayoutMetrics.trailingPadding
                + ActionsLayoutMetrics.overlayScrollerSafetyWidth
        )
    }

    private func idealActionButtonWidth(
        _ button: NSButton
    ) -> CGFloat {
        let cellWidth = button.cell?.cellSize.width ?? 0
        let fittingWidth = button.fittingSize.width

        let fallbackWidth: CGFloat

        if button.title.isEmpty {
            fallbackWidth = InterfaceLayoutMetrics.scaled(
                ActionsLayoutMetrics.minimumImageOnlyButtonWidth,
                for: textScale,
                minimum: 30,
                maximum: 48
            )
        } else {
            let font = button.font
                ?? NSFont.systemFont(
                    ofSize: NSFont.smallSystemFontSize * textScale,
                    weight: .regular
                )

            let titleWidth = measuredTextWidth(
                button.title,
                font: font
            )

            let imageWidth = max(
                button.image?.size.width ?? 0,
                14 * textScale
            )

            let chromeWidth = InterfaceLayoutMetrics.scaled(
                ActionsLayoutMetrics.titledButtonChromeWidth,
                for: textScale,
                minimum: 22,
                maximum: 36
            )

            let stableMinimumWidth: CGFloat

            switch button.identifier {
            case ActionButtonIdentifier.open:
                stableMinimumWidth =
                    ActionsLayoutMetrics.minimumLabeledOpenButtonWidth
            case ActionButtonIdentifier.rename:
                stableMinimumWidth =
                    ActionsLayoutMetrics.minimumLabeledRenameButtonWidth
            default:
                stableMinimumWidth = 0
            }

            fallbackWidth = max(
                stableMinimumWidth,
                titleWidth
                    + imageWidth
                    + ActionsLayoutMetrics.imageTitleSpacing
                    + chromeWidth
            )
        }

        return ceil(
            max(
                cellWidth,
                fittingWidth,
                fallbackWidth
            )
                + ActionsLayoutMetrics.buttonWidthSafety
        )
    }

    private func fixedActionButtonWidth(
        _ button: NSButton
    ) -> CGFloat {
        idealActionButtonWidth(button)
    }

    private func preparedOpenActionButtonForTesting(
        at index: Int,
        stage: HomeProfilesTableLayout.Stage
    ) -> NSButton? {
        guard visibleProfiles.indices.contains(index) else {
            return nil
        }

        applyTableLayoutForTesting(stage: stage)

        let cell = makeActionsCell(
            for: visibleProfiles[index]
        )

        cell.frame = NSRect(
            x: 0,
            y: 0,
            width: currentTableLayout?.actionsWidth ?? 0,
            height: tableView.rowHeight
        )
        cell.layoutSubtreeIfNeeded()

        return descendantButton(
            in: cell,
            identifier: ActionButtonIdentifier.open
        )
    }

    private func descendantButton(
        in view: NSView,
        identifier: NSUserInterfaceItemIdentifier
    ) -> NSButton? {
        if let button = view as? NSButton,
           button.identifier == identifier
        {
            return button
        }

        for subview in view.subviews {
            if let button = descendantButton(
                in: subview,
                identifier: identifier
            ) {
                return button
            }
        }

        return nil
    }

    private func centeredCell(containing view: NSView) -> NSView {
        let cell = NSTableCellView()
        view.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(view)

        NSLayoutConstraint.activate(
            [
                view.leadingAnchor.constraint(
                    equalTo: cell.leadingAnchor,
                    constant: 4
                ),
                view.trailingAnchor.constraint(
                    equalTo: cell.trailingAnchor,
                    constant: -4
                ),
                view.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ]
        )

        return cell
    }

    private func actionButton(
        title: String,
        systemImageName: String,
        identifier: NSUserInterfaceItemIdentifier? = nil,
        accessibilityLabel: String,
        toolTip: String,
        selector: Selector,
        profileID: UUID
    ) -> ProfileIDButton {
        let button = ProfileIDButton()
        button.profileID = profileID
        button.identifier = identifier
        button.title = title
        button.image = NSImage(
            systemSymbolName: systemImageName,
            accessibilityDescription: accessibilityLabel
        )
        button.imagePosition = title.isEmpty
            ? .imageOnly
            : .imageLeading
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(
            ofSize: NSFont.smallSystemFontSize * textScale,
            weight: .regular
        )
        button.cell?.lineBreakMode = .byClipping
        button.target = self
        button.action = selector
        button.toolTip = toolTip
        button.setAccessibilityLabel(accessibilityLabel)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        button.translatesAutoresizingMaskIntoConstraints = true

        return button
    }

    private func canDelete(_ profile: RemappingProfile) -> Bool {
        editorSession != nil
            && configuration.profiles.count > 1
            && configuration.activeProfileID != profile.id
    }

    private func deleteToolTip(for profile: RemappingProfile) -> String {
        guard editorSession != nil else {
            return "Profile editing is unavailable."
        }
        guard configuration.profiles.count > 1 else {
            return "The final remaining profile cannot be deleted."
        }
        guard configuration.activeProfileID != profile.id else {
            return "Select another active profile before deleting this profile."
        }

        return "Delete “\(profile.name)” after confirmation."
    }

    // MARK: - Profile actions

    @objc
    private func addProfile() {
        guard let editorSession else {
            return
        }

        do {
            let profile = try editorSession.addProfile()
            selectedProfileID = profile.id
            reloadPresentation()
            onStatusChange?(
                "“\(profile.name)” was added to the Home draft.",
                false
            )
        } catch {
            onStatusChange?(
                "The profile could not be added.",
                true
            )
        }
    }

    @objc
    private func sortByName() {
        presentationModel.toggleSort(.name)
        reloadPresentation()
    }

    @objc
    private func sortByCreationDate() {
        presentationModel.toggleSort(.creationDate)
        reloadPresentation()
    }

    @objc
    private func openSelectedProfile() {
        let row = tableView.clickedRow >= 0
            ? tableView.clickedRow
            : tableView.selectedRow

        guard visibleProfiles.indices.contains(row) else {
            return
        }

        onOpenProfile?(visibleProfiles[row].id)
    }

    @objc
    private func openProfile(_ sender: ProfileIDButton) {
        guard let profileID = sender.profileID else {
            return
        }

        onOpenProfile?(profileID)
    }

    @objc
    private func editProfileShortcut(_ sender: ProfileIDButton) {
        guard editorSession != nil,
              let profileID = sender.profileID,
              configuration.profile(id: profileID) != nil
        else {
            return
        }

        onEditShortcut?(profileID)
    }

    @objc
    private func duplicateProfileButtonPressed(_ sender: ProfileIDButton) {
        guard let profileID = sender.profileID else {
            return
        }

        duplicateProfile(id: profileID)
    }

    private func duplicateProfile(id profileID: UUID) {
        guard let editorSession,
              let sourceProfile = configuration.profile(id: profileID)
        else {
            return
        }

        do {
            let duplicate = try editorSession.duplicateProfile(id: profileID)
            selectedProfileID = duplicate.id
            reloadPresentation()
            onStatusChange?(
                "“\(duplicate.name)” was duplicated from “\(sourceProfile.name)” in the Home draft.",
                false
            )
        } catch {
            reloadPresentation()
            onStatusChange?(
                "The profile could not be duplicated.",
                true
            )
        }
    }

    @objc
    private func activeProfileChanged(_ sender: ProfileIDButton) {
        guard let editorSession,
              let profileID = sender.profileID
        else {
            reloadPresentation()
            return
        }

        do {
            try editorSession.setActiveProfile(profileID)

            if let profile = configuration.profile(id: profileID) {
                onStatusChange?(
                    "“\(profile.name)” will become active after Home Save.",
                    false
                )
            }
        } catch {
            reloadPresentation()
            onStatusChange?(
                "The active profile could not be changed.",
                true
            )
        }
    }

    @objc
    private func renameProfile(_ sender: ProfileIDButton) {
        guard let profileID = sender.profileID,
              let profile = configuration.profile(id: profileID)
        else {
            return
        }

        presentRenameAlert(for: profile)
    }

    private func presentRenameAlert(for profile: RemappingProfile) {
        guard let editorSession else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Rename “\(profile.name)”"
        alert.informativeText =
            "Profile names must be non-empty and unique. Name comparison is case-sensitive."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let nameField = NSTextField(string: profile.name)
        nameField.frame = NSRect(
            x: 0,
            y: 0,
            width: 320,
            height: 24
        )
        nameField.setAccessibilityLabel("Profile name")
        alert.accessoryView = nameField

        while true {
            let response = alert.runModal()

            guard response == .alertFirstButtonReturn else {
                return
            }

            do {
                let normalizedName = try normalizedRename(
                    nameField.stringValue,
                    for: profile.id
                )
                try editorSession.renameProfile(
                    id: profile.id,
                    to: normalizedName
                )
                onStatusChange?(
                    "The profile was renamed to “\(normalizedName)” in the Home draft.",
                    false
                )
                return
            } catch {
                alert.informativeText = profileNameValidationMessage(
                    for: error
                )
                nameField.selectText(nil)
            }
        }
    }

    private func normalizedRename(
        _ name: String,
        for profileID: UUID
    ) throws -> String {
        let normalizedName = try validator.normalizedProfileName(name)
        var proposedConfiguration = configuration

        guard let profileIndex = proposedConfiguration.profiles.firstIndex(
            where: { $0.id == profileID }
        ) else {
            throw HomeConfigurationEditorSessionError.profileNotFound(
                profileID
            )
        }

        proposedConfiguration.profiles[profileIndex].name = normalizedName
        _ = try validator.normalizedConfiguration(proposedConfiguration)

        return normalizedName
    }

    private func profileNameValidationMessage(for error: Error) -> String {
        switch error {
        case RemappingProfileNameValidationError.empty:
            return "Enter a profile name before continuing."
        case RemappingProfileNameValidationError.containsForbiddenCharacter:
            return "Profile names cannot contain line breaks or control characters."
        case let RemappingProfilesConfigurationValidationError
            .duplicateProfileName(name):
            return "A profile named “\(name)” already exists."
        default:
            return "The profile name is invalid. Correct it or choose Cancel."
        }
    }

    @objc
    private func deleteProfile(_ sender: ProfileIDButton) {
        guard let editorSession,
              let profileID = sender.profileID,
              let profile = configuration.profile(id: profileID),
              canDelete(profile)
        else {
            reloadPresentation()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete “\(profile.name)”?"
        alert.informativeText =
            "This will remove the profile and all of its remapping rules and exceptions. You can undo this change until the application is closed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete Profile")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try editorSession.removeProfile(id: profile.id)

            if selectedProfileID == profile.id {
                selectedProfileID = nil
            }

            onStatusChange?(
                "“\(profile.name)” was removed from the Home draft.",
                false
            )
        } catch {
            reloadPresentation()
            onStatusChange?(
                "The profile could not be deleted.",
                true
            )
        }
    }
}
