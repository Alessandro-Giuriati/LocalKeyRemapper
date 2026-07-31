//
//  HomeProfilesSectionView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import AppKit

/// A button whose action is bound to one stable profile UUID.
@MainActor
private final class ProfileIDButton:
    NSButton
{
    var profileID:
        UUID?
}

/// Displays and edits the presentation-facing Home profiles section.
///
/// Profile mutations are delegated exclusively to
/// `HomeConfigurationEditorSession`. Search, sorting, row selection, and
/// scrolling remain local presentation state and therefore never create Home
/// history or persistent configuration changes.
@MainActor
final class HomeProfilesSectionView:
    NSView,
    NSSearchFieldDelegate,
    NSTableViewDataSource,
    NSTableViewDelegate
{
    var onOpenProfile:
        ((UUID) -> Void)?

    /// Requests presentation of the profile shortcut editor.
    ///
    /// The section supplies only the stable profile UUID. It does not create
    /// the sheet, capture keyboard input, or modify the Home draft directly.
    var onEditShortcut:
        ((UUID) -> Void)?

    var onStatusChange:
        ((String, Bool) -> Void)?

    var onPreferredHeightChange:
        (() -> Void)?

    private enum Column {
        static let profile =
            NSUserInterfaceItemIdentifier(
                "home.profiles.profile"
            )

        static let rules =
            NSUserInterfaceItemIdentifier(
                "home.profiles.rules"
            )

        static let shortcut =
            NSUserInterfaceItemIdentifier(
                "home.profiles.shortcut"
            )

        static let created =
            NSUserInterfaceItemIdentifier(
                "home.profiles.created"
            )

        static let actions =
            NSUserInterfaceItemIdentifier(
                "home.profiles.actions"
            )
    }

    private let editorSession:
        HomeConfigurationEditorSession?

    private let validator:
        RemappingProfilesConfigurationValidating

    private var configuration:
        RemappingProfilesConfiguration

    private var presentationModel =
        HomeProfilesPresentationModel()

    private var visibleProfiles:
        [RemappingProfile] = []

    private var persistedRuleCounts:
        [UUID: Int] = [:]

    private var selectedProfileID:
        UUID?

    private var textScale:
        CGFloat = 1.0

    private let titleLabel =
        NSTextField(
            labelWithString:
                "Profiles"
        )

    private let addButton =
        NSButton()

    private let titleStack =
        NSStackView()

    private let descriptionLabel =
        NSTextField(
            wrappingLabelWithString:
                "Create independent remapping configurations, choose their shortcuts, and select which profile will become active after Home Save."
        )

    private let searchField =
        NSSearchField()

    private let sortByNameButton =
        NSButton()

    private let sortByCreationDateButton =
        NSButton()

    private let searchAndSortStack =
        NSStackView()

    private let tableView =
        NSTableView()

    private let tableScrollView =
        NSScrollView()

    private let emptyResultsLabel =
        NSTextField(
            labelWithString:
                "No profiles match the current search."
        )

    private let contentStack =
        NSStackView()

    private var tableHeightConstraint:
        NSLayoutConstraint?

    private let dateFormatter:
        DateFormatter

    init(
        editorSession:
            HomeConfigurationEditorSession?,
        initialConfiguration:
            RemappingProfilesConfiguration,
        validator:
            RemappingProfilesConfigurationValidating =
                RemappingProfilesConfigurationValidator()
    ) {
        self.editorSession =
            editorSession

        configuration =
            initialConfiguration

        self.validator =
            validator

        dateFormatter =
            DateFormatter()

        super.init(
            frame:
                .zero
        )

        dateFormatter.dateStyle =
            .medium

        dateFormatter.timeStyle =
            .none

        configureContent()

        load(
            configuration:
                initialConfiguration
        )
    }

    required init?(
        coder:
            NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    /// Replaces the displayed Home draft without changing search or sorting.
    func load(
        configuration:
            RemappingProfilesConfiguration
    ) {
        self.configuration =
            configuration

        if let selectedProfileID,
           configuration.profile(
               id:
                   selectedProfileID
           ) == nil
        {
            self.selectedProfileID =
                nil
        }

        reloadPresentation()
    }

    /// Refreshes rule counts after a profile-specific Rules Save.
    ///
    /// This is presentation-only and intentionally does not rewrite the Home
    /// draft or its Undo/Redo history.
    func updatePersistedRuleCounts(
        from persistedConfiguration:
            RemappingProfilesConfiguration
    ) {
        persistedRuleCounts =
            Dictionary(
                uniqueKeysWithValues:
                    persistedConfiguration
                        .profiles
                        .map {
                            profile in

                            (
                                profile.id,
                                profile.rules.count
                            )
                        }
            )

        tableView.reloadData()
    }

    func applyTextScale(
        _ scale:
            CGFloat
    ) {
        textScale =
            scale

        titleLabel.font =
            NSFont.systemFont(
                ofSize:
                    14 * scale,
                weight:
                    .semibold
            )

        descriptionLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * scale,
                weight:
                    .regular
            )

        searchField.font =
            NSFont.systemFont(
                ofSize:
                    13 * scale,
                weight:
                    .regular
            )

        sortByNameButton.font =
            NSFont.systemFont(
                ofSize:
                    12 * scale,
                weight:
                    .regular
            )

        sortByCreationDateButton.font =
            sortByNameButton.font

        emptyResultsLabel.font =
            NSFont.systemFont(
                ofSize:
                    12 * scale,
                weight:
                    .regular
            )

        tableView.rowHeight =
            max(
                34,
                36 * scale
            )

        tableView.headerView?
            .frame
            .size
            .height =
                max(
                    24,
                    25 * scale
                )

        titleStack.spacing =
            InterfaceLayoutMetrics.scaled(
                6,
                for:
                    scale,
                minimum:
                    4,
                maximum:
                    10
            )

        contentStack.spacing =
            InterfaceLayoutMetrics.scaled(
                5,
                for:
                    scale,
                minimum:
                    4,
                maximum:
                    8
            )

        contentStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                4,
                for:
                    scale,
                minimum:
                    3,
                maximum:
                    7
            ),
            after:
                titleStack
        )

        contentStack.setCustomSpacing(
            InterfaceLayoutMetrics.scaled(
                6,
                for:
                    scale,
                minimum:
                    4,
                maximum:
                    9
            ),
            after:
                descriptionLabel
        )

        searchAndSortStack.spacing =
            InterfaceLayoutMetrics.scaled(
                7,
                for:
                    scale,
                minimum:
                    5,
                maximum:
                    11
            )

        updateTableHeight()
        tableView.reloadData()
    }

    func numberOfRows(
        in tableView:
            NSTableView
    ) -> Int {
        visibleProfiles.count
    }

    func tableView(
        _ tableView:
            NSTableView,
        viewFor tableColumn:
            NSTableColumn?,
        row:
            Int
    ) -> NSView? {
        guard
            visibleProfiles.indices.contains(
                row
            ),
            let tableColumn
        else {
            return nil
        }

        let profile =
            visibleProfiles[
                row
            ]

        switch tableColumn.identifier {
        case Column.profile:
            return makeProfileCell(
                for:
                    profile
            )

        case Column.rules:
            return makeRulesCell(
                for:
                    profile
            )

        case Column.shortcut:
            return makeShortcutCell(
                for:
                    profile
            )

        case Column.created:
            return makeCreatedCell(
                for:
                    profile
            )

        case Column.actions:
            return makeActionsCell(
                for:
                    profile
            )

        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(
        _ notification:
            Notification
    ) {
        let selectedRow =
            tableView.selectedRow

        guard
            visibleProfiles.indices.contains(
                selectedRow
            )
        else {
            selectedProfileID =
                nil

            return
        }

        selectedProfileID =
            visibleProfiles[
                selectedRow
            ]
            .id
    }

    func controlTextDidChange(
        _ notification:
            Notification
    ) {
        guard
            notification.object as? NSSearchField
                === searchField
        else {
            return
        }

        presentationModel.searchText =
            searchField.stringValue

        reloadPresentation()
    }

    // MARK: - Test support

    var visibleProfileIDsForTesting:
        [UUID]
    {
        visibleProfiles.map(
            \.id
        )
    }

    var selectedProfileIDForTesting:
        UUID?
    {
        selectedProfileID
    }

    var visibleRowCapacityForTesting:
        Int
    {
        min(
            max(
                visibleProfiles.count,
                1
            ),
            4
        )
    }

    var usesVerticalScrollingForTesting:
        Bool
    {
        tableScrollView
            .hasVerticalScroller
    }

    var columnIdentifiersForTesting:
        [String]
    {
        tableView
            .tableColumns
            .map {
                $0.identifier.rawValue
            }
    }

    func setSearchTextForTesting(
        _ searchText:
            String
    ) {
        searchField.stringValue =
            searchText

        presentationModel.searchText =
            searchText

        reloadPresentation()
    }

    func toggleSortForTesting(
        _ sortKey:
            HomeProfilesPresentationModel.SortKey
    ) {
        presentationModel.toggleSort(
            sortKey
        )

        reloadPresentation()
    }

    func openVisibleProfileForTesting(
        at index:
            Int
    ) {
        guard
            visibleProfiles.indices.contains(
                index
            )
        else {
            return
        }

        onOpenProfile?(
            visibleProfiles[
                index
            ]
            .id
        )
    }

    func editShortcutForVisibleProfileForTesting(
        at index:
            Int
    ) {
        guard
            editorSession != nil,
            visibleProfiles.indices.contains(
                index
            )
        else {
            return
        }

        onEditShortcut?(
            visibleProfiles[
                index
            ]
            .id
        )
    }

    func duplicateVisibleProfileForTesting(
        at index:
            Int
    ) {
        guard
            editorSession != nil,
            visibleProfiles.indices.contains(
                index
            )
        else {
            return
        }

        duplicateProfile(
            id:
                visibleProfiles[
                    index
                ]
                .id
        )
    }

    func shortcutTitleForVisibleProfileForTesting(
        at index:
            Int
    ) -> String? {
        guard
            visibleProfiles.indices.contains(
                index
            )
        else {
            return nil
        }

        return ProfileShortcutConfigurationPresentation
            .tableTitle(
                for:
                    visibleProfiles[
                        index
                    ]
                    .shortcutConfigurationOverride
            )
    }

    private func configureContent() {
        wantsLayer =
            true

        titleLabel.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        addButton.title =
            ""

        addButton.image =
            NSImage(
                systemSymbolName:
                    "plus",
                accessibilityDescription:
                    "Add profile"
            )

        addButton.imagePosition =
            .imageOnly

        addButton.bezelStyle =
            .rounded

        addButton.target =
            self

        addButton.action =
            #selector(
                addProfile
            )

        addButton.toolTip =
            "Add a new empty remapping profile."

        addButton.setAccessibilityLabel(
            "Add profile"
        )

        addButton.isEnabled =
            editorSession != nil

        addButton.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        titleStack.setViews(
            [
                titleLabel,
                addButton
            ],
            in:
                .leading
        )

        titleStack.orientation =
            .horizontal

        titleStack.alignment =
            .centerY

        descriptionLabel.textColor =
            .secondaryLabelColor

        searchField.placeholderString =
            "Search profiles"

        searchField.delegate =
            self

        searchField.sendsSearchStringImmediately =
            true

        searchField.sendsWholeSearchString =
            false

        searchField.setAccessibilityLabel(
            "Search profiles"
        )

        configureSortButton(
            sortByNameButton,
            action:
                #selector(
                    sortByName
                ),
            accessibilityLabel:
                "Sort profiles by name"
        )

        configureSortButton(
            sortByCreationDateButton,
            action:
                #selector(
                    sortByCreationDate
                ),
            accessibilityLabel:
                "Sort profiles by creation date"
        )

        searchField.setContentCompressionResistancePriority(
            .defaultLow,
            for:
                .horizontal
        )

        searchAndSortStack.setViews(
            [
                searchField,
                sortByNameButton,
                sortByCreationDateButton
            ],
            in:
                .leading
        )

        searchAndSortStack.orientation =
            .horizontal

        searchAndSortStack.alignment =
            .centerY

        searchAndSortStack.distribution =
            .fill

        configureTable()

        contentStack.setViews(
            [
                titleStack,
                descriptionLabel,
                searchAndSortStack,
                tableScrollView
            ],
            in:
                .leading
        )

        contentStack.orientation =
            .vertical

        contentStack.alignment =
            .leading

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

                titleStack.widthAnchor.constraint(
                    lessThanOrEqualTo:
                        contentStack.widthAnchor
                ),

                descriptionLabel.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                ),

                searchAndSortStack.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                ),

                tableScrollView.widthAnchor.constraint(
                    equalTo:
                        contentStack.widthAnchor
                )
            ]
        )

        applyTextScale(
            1.0
        )
    }

    private func configureSortButton(
        _ button:
            NSButton,
        action:
            Selector,
        accessibilityLabel:
            String
    ) {
        button.bezelStyle =
            .rounded

        button.target =
            self

        button.action =
            action

        button.setAccessibilityLabel(
            accessibilityLabel
        )

        button.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )
    }

    private func configureTable() {
        tableView.usesAlternatingRowBackgroundColors =
            true

        tableView.allowsMultipleSelection =
            false

        tableView.allowsEmptySelection =
            true

        tableView.allowsColumnReordering =
            false

        tableView.allowsColumnResizing =
            true

        tableView.columnAutoresizingStyle =
            .lastColumnOnlyAutoresizingStyle

        tableView.delegate =
            self

        tableView.dataSource =
            self

        tableView.target =
            self

        tableView.doubleAction =
            #selector(
                openSelectedProfile
            )

        let profileColumn =
            NSTableColumn(
                identifier:
                    Column.profile
            )

        profileColumn.title =
            "Profile"

        profileColumn.minWidth =
            155

        profileColumn.width =
            210

        let rulesColumn =
            NSTableColumn(
                identifier:
                    Column.rules
            )

        rulesColumn.title =
            "Rules"

        rulesColumn.minWidth =
            48

        rulesColumn.width =
            60

        let shortcutColumn =
            NSTableColumn(
                identifier:
                    Column.shortcut
            )

        shortcutColumn.title =
            "Shortcut"

        shortcutColumn.minWidth =
            135

        shortcutColumn.width =
            165

        let createdColumn =
            NSTableColumn(
                identifier:
                    Column.created
            )

        createdColumn.title =
            "Created"

        createdColumn.minWidth =
            90

        createdColumn.width =
            110

        let actionsColumn =
            NSTableColumn(
                identifier:
                    Column.actions
            )

        actionsColumn.title =
            "Actions"

        actionsColumn.minWidth =
            185

        actionsColumn.width =
            205

        tableView.addTableColumn(
            profileColumn
        )

        tableView.addTableColumn(
            rulesColumn
        )

        tableView.addTableColumn(
            shortcutColumn
        )

        tableView.addTableColumn(
            createdColumn
        )

        tableView.addTableColumn(
            actionsColumn
        )

        tableScrollView.borderType =
            .bezelBorder

        tableScrollView.drawsBackground =
            true

        tableScrollView.hasHorizontalScroller =
            false

        tableScrollView.autohidesScrollers =
            true

        tableScrollView.documentView =
            tableView

        tableScrollView.translatesAutoresizingMaskIntoConstraints =
            false

        emptyResultsLabel.textColor =
            .secondaryLabelColor

        emptyResultsLabel.alignment =
            .center

        emptyResultsLabel.isHidden =
            true

        emptyResultsLabel.translatesAutoresizingMaskIntoConstraints =
            false

        tableScrollView.addSubview(
            emptyResultsLabel
        )

        NSLayoutConstraint.activate(
            [
                emptyResultsLabel.centerXAnchor.constraint(
                    equalTo:
                        tableScrollView.centerXAnchor
                ),

                emptyResultsLabel.centerYAnchor.constraint(
                    equalTo:
                        tableScrollView.centerYAnchor,
                    constant:
                        10
                ),

                emptyResultsLabel.leadingAnchor.constraint(
                    greaterThanOrEqualTo:
                        tableScrollView.leadingAnchor,
                    constant:
                        12
                ),

                emptyResultsLabel.trailingAnchor.constraint(
                    lessThanOrEqualTo:
                        tableScrollView.trailingAnchor,
                    constant:
                        -12
                )
            ]
        )

        let tableHeightConstraint =
            tableScrollView.heightAnchor.constraint(
                equalToConstant:
                    1
            )

        self.tableHeightConstraint =
            tableHeightConstraint

        tableHeightConstraint.isActive =
            true
    }

    private func reloadPresentation() {
        visibleProfiles =
            presentationModel.visibleProfiles(
                from:
                    configuration.profiles
            )

        updateSortButtonTitles()
        tableView.reloadData()
        restoreSelection()
        updateTableHeight()
    }

    private func restoreSelection() {
        guard
            let selectedProfileID,
            let visibleIndex =
                visibleProfiles.firstIndex(
                    where: {
                        $0.id
                            == selectedProfileID
                    }
                )
        else {
            tableView.deselectAll(
                nil
            )

            return
        }

        tableView.selectRowIndexes(
            IndexSet(
                integer:
                    visibleIndex
            ),
            byExtendingSelection:
                false
        )
    }

    private func updateTableHeight() {
        let visibleRowCapacity =
            min(
                max(
                    visibleProfiles.count,
                    1
                ),
                4
            )

        let headerHeight =
            tableView.headerView?
                .frame
                .height
                ?? 25

        tableHeightConstraint?
            .constant =
                ceil(
                    headerHeight
                        + CGFloat(
                            visibleRowCapacity
                        )
                        * tableView.rowHeight
                        + 3
                )

        tableScrollView.hasVerticalScroller =
            visibleProfiles.count > 4

        emptyResultsLabel.isHidden =
            !visibleProfiles.isEmpty

        onPreferredHeightChange?()
    }

    private func updateSortButtonTitles() {
        sortByNameButton.title =
            sortButtonTitle(
                baseTitle:
                    "Name",
                key:
                    .name
            )

        sortByCreationDateButton.title =
            sortButtonTitle(
                baseTitle:
                    "Created",
                key:
                    .creationDate
            )
    }

    private func sortButtonTitle(
        baseTitle:
            String,
        key:
            HomeProfilesPresentationModel.SortKey
    ) -> String {
        guard
            presentationModel.sortKey
                == key
        else {
            return baseTitle
        }

        let directionSymbol =
            presentationModel.sortDirection
                == .ascending
                    ? "↑"
                    : "↓"

        return "\(baseTitle) \(directionSymbol)"
    }

    private func makeProfileCell(
        for profile:
            RemappingProfile
    ) -> NSView {
        let cell =
            NSTableCellView()

        let activeButton =
            ProfileIDButton(
                radioButtonWithTitle:
                    "",
                target:
                    self,
                action:
                    #selector(
                        activeProfileChanged
                    )
            )

        activeButton.profileID =
            profile.id

        activeButton.state =
            configuration.activeProfileID
                == profile.id
                    ? .on
                    : .off

        activeButton.isEnabled =
            editorSession != nil

        activeButton.toolTip =
            "Set “\(profile.name)” as the active profile after Home Save."

        activeButton.setAccessibilityLabel(
            "Set “\(profile.name)” as active profile"
        )

        let nameLabel =
            NSTextField(
                labelWithString:
                    profile.name
            )

        nameLabel.font =
            NSFont.systemFont(
                ofSize:
                    13 * textScale,
                weight:
                    .regular
            )

        nameLabel.lineBreakMode =
            .byTruncatingTail

        nameLabel.toolTip =
            profile.name

        let activeLabel =
            NSTextField(
                labelWithString:
                    configuration.activeProfileID
                        == profile.id
                            ? "Active"
                            : ""
            )

        activeLabel.font =
            NSFont.systemFont(
                ofSize:
                    11 * textScale,
                weight:
                    .semibold
            )

        activeLabel.textColor =
            .secondaryLabelColor

        activeLabel.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        let stack =
            NSStackView(
                views: [
                    activeButton,
                    nameLabel,
                    activeLabel
                ]
            )

        stack.orientation =
            .horizontal

        stack.alignment =
            .centerY

        stack.spacing =
            6

        stack.translatesAutoresizingMaskIntoConstraints =
            false

        cell.addSubview(
            stack
        )

        NSLayoutConstraint.activate(
            [
                stack.leadingAnchor.constraint(
                    equalTo:
                        cell.leadingAnchor,
                    constant:
                        6
                ),

                stack.trailingAnchor.constraint(
                    equalTo:
                        cell.trailingAnchor,
                    constant:
                        -6
                ),

                stack.centerYAnchor.constraint(
                    equalTo:
                        cell.centerYAnchor
                )
            ]
        )

        return cell
    }

    private func makeRulesCell(
        for profile:
            RemappingProfile
    ) -> NSView {
        let ruleCount =
            persistedRuleCounts[
                profile.id
            ]
                ?? profile.rules.count

        let label =
            NSTextField(
                labelWithString:
                    String(
                        ruleCount
                    )
            )

        label.alignment =
            .center

        label.font =
            NSFont.systemFont(
                ofSize:
                    13 * textScale,
                weight:
                    .regular
            )

        return centeredCell(
            containing:
                label
        )
    }

    private func makeShortcutCell(
        for profile:
            RemappingProfile
    ) -> NSView {
        let summary =
            ProfileShortcutConfigurationPresentation
                .tableTitle(
                    for:
                        profile
                            .shortcutConfigurationOverride
                )

        let summaryLabel =
            NSTextField(
                labelWithString:
                    summary
            )

        summaryLabel.font =
            NSFont.systemFont(
                ofSize:
                    12 * textScale,
                weight:
                    .regular
            )

        summaryLabel.lineBreakMode =
            .byTruncatingTail

        summaryLabel.toolTip =
            shortcutToolTip(
                for:
                    profile
            )

        summaryLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for:
                .horizontal
        )

        let editButton =
            actionButton(
                title:
                    "Edit…",
                systemImageName:
                    "keyboard",
                accessibilityLabel:
                    "Edit shortcut for “\(profile.name)”",
                toolTip:
                    "Edit the shortcut configuration for “\(profile.name)”.",
                selector:
                    #selector(
                        editProfileShortcut
                    ),
                profileID:
                    profile.id
            )

        editButton.isEnabled =
            editorSession != nil

        let stack =
            NSStackView(
                views: [
                    summaryLabel,
                    editButton
                ]
            )

        stack.orientation =
            .horizontal

        stack.alignment =
            .centerY

        stack.spacing =
            6

        stack.translatesAutoresizingMaskIntoConstraints =
            false

        let cell =
            NSTableCellView()

        cell.addSubview(
            stack
        )

        NSLayoutConstraint.activate(
            [
                stack.leadingAnchor.constraint(
                    equalTo:
                        cell.leadingAnchor,
                    constant:
                        5
                ),

                stack.trailingAnchor.constraint(
                    equalTo:
                        cell.trailingAnchor,
                    constant:
                        -5
                ),

                stack.centerYAnchor.constraint(
                    equalTo:
                        cell.centerYAnchor
                )
            ]
        )

        return cell
    }

    private func shortcutToolTip(
        for profile:
            RemappingProfile
    ) -> String {
        guard
            let override =
                profile
                    .shortcutConfigurationOverride
        else {
            return "Uses Default Global Shortcuts."
        }

        return ProfileShortcutConfigurationPresentation
            .configurationTitle(
                override
            )
    }

    private func makeCreatedCell(
        for profile:
            RemappingProfile
    ) -> NSView {
        let label =
            NSTextField(
                labelWithString:
                    dateFormatter.string(
                        from:
                            profile.createdAt
                    )
            )

        label.alignment =
            .center

        label.font =
            NSFont.systemFont(
                ofSize:
                    12 * textScale,
                weight:
                    .regular
            )

        label.textColor =
            .secondaryLabelColor

        return centeredCell(
            containing:
                label
        )
    }

    private func makeActionsCell(
        for profile:
            RemappingProfile
    ) -> NSView {
        let openButton =
            actionButton(
                title:
                    "Open",
                systemImageName:
                    "arrow.up.right.square",
                accessibilityLabel:
                    "Open rules for “\(profile.name)”",
                toolTip:
                    "Open the Rules window for “\(profile.name)”.",
                selector:
                    #selector(
                        openProfile
                    ),
                profileID:
                    profile.id
            )

        let renameButton =
            actionButton(
                title:
                    "Rename",
                systemImageName:
                    "pencil",
                accessibilityLabel:
                    "Rename “\(profile.name)”",
                toolTip:
                    "Rename “\(profile.name)”.",
                selector:
                    #selector(
                        renameProfile
                    ),
                profileID:
                    profile.id
            )

        renameButton.isEnabled =
            editorSession != nil

        let duplicateButton =
            actionButton(
                title:
                    "",
                systemImageName:
                    "doc.on.doc",
                accessibilityLabel:
                    "Duplicate “\(profile.name)”",
                toolTip:
                    "Duplicate “\(profile.name)” with its rules, exceptions, and shortcut settings.",
                selector:
                    #selector(
                        duplicateProfileButtonPressed
                    ),
                profileID:
                    profile.id
            )

        duplicateButton.imagePosition =
            .imageOnly

        duplicateButton.isEnabled =
            editorSession != nil

        let deleteButton =
            actionButton(
                title:
                    "",
                systemImageName:
                    "trash",
                accessibilityLabel:
                    "Delete “\(profile.name)”",
                toolTip:
                    deleteToolTip(
                        for:
                            profile
                    ),
                selector:
                    #selector(
                        deleteProfile
                    ),
                profileID:
                    profile.id
            )

        deleteButton.imagePosition =
            .imageOnly

        deleteButton.contentTintColor =
            .systemRed

        deleteButton.isEnabled =
            canDelete(
                profile
            )

        let stack =
            NSStackView(
                views: [
                    openButton,
                    renameButton,
                    duplicateButton,
                    deleteButton
                ]
            )

        stack.orientation =
            .horizontal

        stack.alignment =
            .centerY

        stack.spacing =
            5

        stack.translatesAutoresizingMaskIntoConstraints =
            false

        let cell =
            NSTableCellView()

        cell.addSubview(
            stack
        )

        NSLayoutConstraint.activate(
            [
                stack.centerXAnchor.constraint(
                    equalTo:
                        cell.centerXAnchor
                ),

                stack.centerYAnchor.constraint(
                    equalTo:
                        cell.centerYAnchor
                ),

                stack.leadingAnchor.constraint(
                    greaterThanOrEqualTo:
                        cell.leadingAnchor,
                    constant:
                        4
                ),

                stack.trailingAnchor.constraint(
                    lessThanOrEqualTo:
                        cell.trailingAnchor,
                    constant:
                        -4
                )
            ]
        )

        return cell
    }

    private func centeredCell(
        containing view:
            NSView
    ) -> NSView {
        let cell =
            NSTableCellView()

        view.translatesAutoresizingMaskIntoConstraints =
            false

        cell.addSubview(
            view
        )

        NSLayoutConstraint.activate(
            [
                view.leadingAnchor.constraint(
                    equalTo:
                        cell.leadingAnchor,
                    constant:
                        4
                ),

                view.trailingAnchor.constraint(
                    equalTo:
                        cell.trailingAnchor,
                    constant:
                        -4
                ),

                view.centerYAnchor.constraint(
                    equalTo:
                        cell.centerYAnchor
                )
            ]
        )

        return cell
    }

    private func actionButton(
        title:
            String,
        systemImageName:
            String,
        accessibilityLabel:
            String,
        toolTip:
            String,
        selector:
            Selector,
        profileID:
            UUID
    ) -> ProfileIDButton {
        let button =
            ProfileIDButton()

        button.profileID =
            profileID

        button.title =
            title

        button.image =
            NSImage(
                systemSymbolName:
                    systemImageName,
                accessibilityDescription:
                    accessibilityLabel
            )

        button.imagePosition =
            title.isEmpty
                ? .imageOnly
                : .imageLeading

        button.bezelStyle =
            .rounded

        button.controlSize =
            .small

        button.target =
            self

        button.action =
            selector

        button.toolTip =
            toolTip

        button.setAccessibilityLabel(
            accessibilityLabel
        )

        button.setContentHuggingPriority(
            .required,
            for:
                .horizontal
        )

        return button
    }

    private func canDelete(
        _ profile:
            RemappingProfile
    ) -> Bool {
        editorSession != nil
            && configuration.profiles.count > 1
            && configuration.activeProfileID
                != profile.id
    }

    private func deleteToolTip(
        for profile:
            RemappingProfile
    ) -> String {
        guard
            editorSession != nil
        else {
            return "Profile editing is unavailable."
        }

        guard
            configuration.profiles.count > 1
        else {
            return "The final remaining profile cannot be deleted."
        }

        guard
            configuration.activeProfileID
                != profile.id
        else {
            return "Select another active profile before deleting this profile."
        }

        return "Delete “\(profile.name)” after confirmation."
    }

    @objc
    private func addProfile() {
        guard
            let editorSession
        else {
            return
        }

        do {
            let profile =
                try editorSession
                    .addProfile()

            selectedProfileID =
                profile.id

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
        presentationModel.toggleSort(
            .name
        )

        reloadPresentation()
    }

    @objc
    private func sortByCreationDate() {
        presentationModel.toggleSort(
            .creationDate
        )

        reloadPresentation()
    }

    @objc
    private func openSelectedProfile() {
        let row =
            tableView.clickedRow >= 0
                ? tableView.clickedRow
                : tableView.selectedRow

        guard
            visibleProfiles.indices.contains(
                row
            )
        else {
            return
        }

        onOpenProfile?(
            visibleProfiles[
                row
            ]
            .id
        )
    }

    @objc
    private func openProfile(
        _ sender:
            ProfileIDButton
    ) {
        guard
            let profileID =
                sender.profileID
        else {
            return
        }

        onOpenProfile?(
            profileID
        )
    }

    @objc
    private func editProfileShortcut(
        _ sender:
            ProfileIDButton
    ) {
        guard
            editorSession != nil,
            let profileID =
                sender.profileID,
            configuration.profile(
                id:
                    profileID
            ) != nil
        else {
            return
        }

        onEditShortcut?(
            profileID
        )
    }

    @objc
    private func duplicateProfileButtonPressed(
        _ sender:
            ProfileIDButton
    ) {
        guard
            let profileID =
                sender.profileID
        else {
            return
        }

        duplicateProfile(
            id:
                profileID
        )
    }

    private func duplicateProfile(
        id profileID:
            UUID
    ) {
        guard
            let editorSession,
            let sourceProfile =
                configuration.profile(
                    id:
                        profileID
                )
        else {
            return
        }

        do {
            let duplicate =
                try editorSession
                    .duplicateProfile(
                        id:
                            profileID
                    )

            selectedProfileID =
                duplicate.id

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
    private func activeProfileChanged(
        _ sender:
            ProfileIDButton
    ) {
        guard
            let editorSession,
            let profileID =
                sender.profileID
        else {
            reloadPresentation()
            return
        }

        do {
            try editorSession
                .setActiveProfile(
                    profileID
                )

            if let profile =
                configuration.profile(
                    id:
                        profileID
                )
            {
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
    private func renameProfile(
        _ sender:
            ProfileIDButton
    ) {
        guard
            let profileID =
                sender.profileID,
            let profile =
                configuration.profile(
                    id:
                        profileID
                )
        else {
            return
        }

        presentRenameAlert(
            for:
                profile
        )
    }

    private func presentRenameAlert(
        for profile:
            RemappingProfile
    ) {
        guard
            let editorSession
        else {
            return
        }

        let alert =
            NSAlert()

        alert.messageText =
            "Rename “\(profile.name)”"

        alert.informativeText =
            "Profile names must be non-empty and unique. Name comparison is case-sensitive."

        alert.alertStyle =
            .informational

        alert.addButton(
            withTitle:
                "Rename"
        )

        alert.addButton(
            withTitle:
                "Cancel"
        )

        let nameField =
            NSTextField(
                string:
                    profile.name
            )

        nameField.frame =
            NSRect(
                x:
                    0,
                y:
                    0,
                width:
                    320,
                height:
                    24
            )

        nameField.setAccessibilityLabel(
            "Profile name"
        )

        alert.accessoryView =
            nameField

        while true {
            let response =
                alert.runModal()

            guard
                response
                    == .alertFirstButtonReturn
            else {
                return
            }

            do {
                let normalizedName =
                    try normalizedRename(
                        nameField.stringValue,
                        for:
                            profile.id
                    )

                try editorSession
                    .renameProfile(
                        id:
                            profile.id,
                        to:
                            normalizedName
                    )

                onStatusChange?(
                    "The profile was renamed to “\(normalizedName)” in the Home draft.",
                    false
                )

                return
            } catch {
                alert.informativeText =
                    profileNameValidationMessage(
                        for:
                            error
                    )

                nameField.selectText(
                    nil
                )
            }
        }
    }

    private func normalizedRename(
        _ name:
            String,
        for profileID:
            UUID
    ) throws -> String {
        let normalizedName =
            try validator
                .normalizedProfileName(
                    name
                )

        var proposedConfiguration =
            configuration

        guard
            let profileIndex =
                proposedConfiguration
                    .profiles
                    .firstIndex(
                        where: {
                            $0.id
                                == profileID
                        }
                    )
        else {
            throw HomeConfigurationEditorSessionError
                .profileNotFound(
                    profileID
                )
        }

        proposedConfiguration
            .profiles[
                profileIndex
            ]
            .name =
                normalizedName

        _ =
            try validator
                .normalizedConfiguration(
                    proposedConfiguration
                )

        return normalizedName
    }

    private func profileNameValidationMessage(
        for error:
            Error
    ) -> String {
        switch error {
        case RemappingProfileNameValidationError
            .empty:
            return "Enter a profile name before continuing."

        case RemappingProfileNameValidationError
            .containsForbiddenCharacter:
            return "Profile names cannot contain line breaks or control characters."

        case let RemappingProfilesConfigurationValidationError
            .duplicateProfileName(
                name
            ):
            return "A profile named “\(name)” already exists."

        default:
            return "The profile name is invalid. Correct it or choose Cancel."
        }
    }

    @objc
    private func deleteProfile(
        _ sender:
            ProfileIDButton
    ) {
        guard
            let editorSession,
            let profileID =
                sender.profileID,
            let profile =
                configuration.profile(
                    id:
                        profileID
                ),
            canDelete(
                profile
            )
        else {
            reloadPresentation()
            return
        }

        let alert =
            NSAlert()

        alert.messageText =
            "Delete “\(profile.name)”?"

        alert.informativeText =
            "This will remove the profile and all of its remapping rules and exceptions. You can undo this change until the application is closed."

        alert.alertStyle =
            .warning

        alert.addButton(
            withTitle:
                "Delete Profile"
        )

        alert.addButton(
            withTitle:
                "Cancel"
        )

        guard
            alert.runModal()
                == .alertFirstButtonReturn
        else {
            return
        }

        do {
            try editorSession
                .removeProfile(
                    id:
                        profile.id
                )

            if selectedProfileID
                == profile.id
            {
                selectedProfileID =
                    nil
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
