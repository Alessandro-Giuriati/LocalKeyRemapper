//
//  ApplicationSelectionListView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 11/11/26.
//

import AppKit

@MainActor
private final class ApplicationCell: NSTableCellView {
    let nameLabel = NSTextField(labelWithString: "")
    let identifierLabel = NSTextField(labelWithString: "")
    var showsConflict = false {
        didSet {
            if showsConflict != oldValue {
                needsDisplay = true
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameLabel.lineBreakMode = .byTruncatingTail
        identifierLabel.lineBreakMode = .byTruncatingTail
        identifierLabel.textColor = .secondaryLabelColor
        for label in [nameLabel, identifierLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            identifierLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            identifierLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            identifierLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard showsConflict else { return }

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), xRadius: 8, yRadius: 8)
        NSColor.systemRed.withAlphaComponent(0.08).setFill()
        path.fill()
        NSColor.systemRed.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}

@MainActor
final class ApplicationSelectionListView: NSStackView, NSTableViewDataSource, NSTableViewDelegate {
    let heading: NSTextField
    let addButton = NSButton(title: "Add Apps…", target: nil, action: nil)
    let removeButton = NSButton(title: "Remove Selected", target: nil, action: nil)
    private let table = NSTableView()
    private let scrollView = NSScrollView()
    private var applications: [ForegroundApplicationScope.Application] = []
    private var conflictMessages: [String: String] = [:]
    private var controlFont = NSFont.systemFont(ofSize: 14)
    private var detailFont = NSFont.systemFont(ofSize: 12)

    var selectedIdentifiers: Set<String> {
        Set(table.selectedRowIndexes.compactMap { index in
            applications.indices.contains(index) ? applications[index].bundleIdentifier : nil
        })
    }

    init(title: String, identifier: String) {
        heading = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 8
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("application")))
        table.headerView = nil
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.allowsMultipleSelection = true
        table.rowHeight = 46
        table.dataSource = self
        table.delegate = self
        table.identifier = NSUserInterfaceItemIdentifier(identifier)
        table.setAccessibilityLabel(title)
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        addButton.bezelStyle = .rounded
        removeButton.bezelStyle = .rounded
        addButton.identifier = NSUserInterfaceItemIdentifier(identifier + ".add")
        removeButton.identifier = NSUserInterfaceItemIdentifier(identifier + ".remove")
        addButton.setAccessibilityLabel("Add to " + title)
        removeButton.setAccessibilityLabel("Remove from " + title)
        removeButton.isEnabled = false

        let buttons = NSStackView(views: [addButton, removeButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        setViews([heading, scrollView, buttons], in: .leading)
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalTo: widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func load(_ applications: [ForegroundApplicationScope.Application], conflictMessages: [String: String] = [:]) {
        guard self.applications != applications || self.conflictMessages != conflictMessages else {
            return
        }

        let selected = selectedIdentifiers
        self.applications = applications
        self.conflictMessages = conflictMessages
        table.reloadData()
        table.selectRowIndexes(
            IndexSet(applications.indices.filter { selected.contains(applications[$0].bundleIdentifier) }),
            byExtendingSelection: false
        )
        removeButton.isEnabled = !table.selectedRowIndexes.isEmpty
    }

    func applyFonts(title: NSFont, description: NSFont, control: NSFont) {
        heading.font = title
        controlFont = control
        detailFont = description
        addButton.font = control
        removeButton.font = control
        table.rowHeight = ceil(control.pointSize + description.pointSize + 16)
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        applications.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard applications.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("scope.applicationCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? ApplicationCell
            ?? ApplicationCell(frame: .zero)
        cell.identifier = identifier
        let application = applications[row]
        let conflict = conflictMessages[application.bundleIdentifier]
        cell.nameLabel.stringValue = application.displayName
        cell.nameLabel.font = controlFont
        cell.nameLabel.setAccessibilityLabel(
            conflict.map { "\(application.displayName). \($0)" } ?? application.displayName
        )
        cell.identifierLabel.stringValue = application.bundleIdentifier
        cell.identifierLabel.font = detailFont
        cell.showsConflict = conflict != nil
        cell.toolTip = [application.displayName, application.bundleIdentifier, conflict]
            .compactMap { $0 }.joined(separator: "\n")
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeButton.isEnabled = !table.selectedRowIndexes.isEmpty
    }
}
