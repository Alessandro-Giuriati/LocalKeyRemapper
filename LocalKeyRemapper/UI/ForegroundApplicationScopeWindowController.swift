//
//  ForegroundApplicationScopeWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 10/11/26.
//

import AppKit
import UniformTypeIdentifiers

/// Edits the shared Home draft. Persistence remains owned by Home Save.
@MainActor
final class ForegroundApplicationScopeWindowController: NSWindowController, NSWindowDelegate {
    private final class ApplicationCell: NSTableCellView {
        let nameLabel = NSTextField(labelWithString: "")
        let identifierLabel = NSTextField(labelWithString: "")

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
    }

    private final class ApplicationListView: NSStackView, NSTableViewDataSource, NSTableViewDelegate {
        let heading: NSTextField
        let addButton = NSButton(title: "Add Apps…", target: nil, action: nil)
        let removeButton = NSButton(title: "Remove Selected", target: nil, action: nil)
        private let table = NSTableView()
        private let scrollView = NSScrollView()
        private var applications: [ForegroundApplicationScope.Application] = []
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

        func load(_ applications: [ForegroundApplicationScope.Application]) {
            guard self.applications != applications else {
                return
            }

            let selected = selectedIdentifiers
            self.applications = applications
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
            cell.nameLabel.stringValue = application.displayName
            cell.nameLabel.font = controlFont
            cell.identifierLabel.stringValue = application.bundleIdentifier
            cell.identifierLabel.font = detailFont
            cell.toolTip = application.displayName + "\n" + application.bundleIdentifier
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            removeButton.isEnabled = !table.selectedRowIndexes.isEmpty
        }
    }

    private let includedView = ApplicationListView(title: "Included Apps", identifier: "scope.includedApps")
    private let excludedView = ApplicationListView(title: "Excluded Apps", identifier: "scope.excludedApps")
    private let otherAppsTitle = NSTextField(labelWithString: "Other Apps")
    private let otherAppsControl = NSPopUpButton(frame: .zero, pullsDown: false)
    private let explanationLabel = NSTextField(wrappingLabelWithString:
        "Included apps turn remapping on automatically. Excluded apps turn it off automatically. App rules apply while a window of that app is in front."
    )
    private let validationLabel = NSTextField(wrappingLabelWithString: "")
    private let footerLabel = NSTextField(wrappingLabelWithString:
        "For apps not listed above, Use Manual Setting follows the Home switch. Keep Remapping Off leaves them off. Save Home applies all Home changes."
    )
    private let saveButton = NSButton(title: "Save Home", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private var scope: ForegroundApplicationScope
    private let changeHandler: (ForegroundApplicationScope) -> Void
    private let saveHandler: () -> Bool
    private let closeHandler: () -> Void
    private var openPanel: NSOpenPanel?
    private var canSaveHome = false
    private var isClosed = false

    init(
        scope: ForegroundApplicationScope,
        changeHandler: @escaping (ForegroundApplicationScope) -> Void,
        saveHandler: @escaping () -> Bool,
        closeHandler: @escaping () -> Void
    ) {
        self.scope = scope
        self.changeHandler = changeHandler
        self.saveHandler = saveHandler
        self.closeHandler = closeHandler

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Remapping by App"
        window.contentMinSize = NSSize(width: 680, height: 520)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        configureContent()
        refreshValidation()
        window.center()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func load(_ scope: ForegroundApplicationScope) {
        self.scope = scope
        includedView.load(scope.includedApplications)
        excludedView.load(scope.excludedApplications)
        let otherAppsIndex = scope.allowsOtherApplications
            ? 0
            : (scope.allowsManualActivationForOtherApplications ? 2 : 1)
        otherAppsControl.selectItem(at: otherAppsIndex)
        switch otherAppsIndex {
        case 0:
            footerLabel.stringValue = "Apps not listed above follow the manual setting in Home. Save Home applies all Home changes."
        case 1:
            footerLabel.stringValue = "Apps not listed above keep remapping off, including when the manual setting is on. Save Home applies all Home changes."
        default:
            footerLabel.stringValue = "Use the menu bar or a remapping shortcut to turn it on for the foreground app. Changing apps turns it off. Save Home applies all Home changes."
        }
        refreshValidation()
    }

    func setSaveEnabled(_ enabled: Bool) {
        canSaveHome = enabled
        refreshValidation()
    }

    func applyFonts(title: NSFont, description: NSFont, control: NSFont) {
        includedView.applyFonts(title: title, description: description, control: control)
        excludedView.applyFonts(title: title, description: description, control: control)
        otherAppsTitle.font = title
        otherAppsControl.font = control
        explanationLabel.font = description
        validationLabel.font = description
        footerLabel.font = description
        saveButton.font = control
        doneButton.font = control
    }

    override func close() {
        openPanel?.cancel(nil)
        openPanel = nil
        super.close()
    }

    func windowWillClose(_ notification: Notification) {
        isClosed = true
        openPanel?.cancel(nil)
        openPanel = nil
        closeHandler()
    }

    private func configureContent() {
        guard let content = window?.contentView else {
            return
        }

        explanationLabel.textColor = .secondaryLabelColor
        footerLabel.textColor = .secondaryLabelColor
        validationLabel.textColor = .systemRed
        validationLabel.maximumNumberOfLines = 3
        validationLabel.lineBreakMode = .byTruncatingTail
        otherAppsControl.addItems(withTitles: [
            "Use Manual Setting",
            "Keep Remapping Off",
            "Allow Manual Activation"
        ])
        otherAppsControl.identifier = NSUserInterfaceItemIdentifier("scope.otherApps")
        otherAppsControl.setAccessibilityLabel("Remapping for apps in neither list")
        otherAppsControl.target = self
        otherAppsControl.action = #selector(ForegroundApplicationScopeWindowController.otherAppsBehaviorDidChange)
        includedView.addButton.target = self
        includedView.addButton.action = #selector(ForegroundApplicationScopeWindowController.addIncludedApps)
        excludedView.addButton.target = self
        excludedView.addButton.action = #selector(ForegroundApplicationScopeWindowController.addExcludedApps)
        includedView.removeButton.target = self
        includedView.removeButton.action = #selector(ForegroundApplicationScopeWindowController.removeIncludedApps)
        excludedView.removeButton.target = self
        excludedView.removeButton.action = #selector(ForegroundApplicationScopeWindowController.removeExcludedApps)
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(ForegroundApplicationScopeWindowController.saveHomeDraft)
        doneButton.bezelStyle = .rounded
        doneButton.target = self
        doneButton.action = #selector(ForegroundApplicationScopeWindowController.finishEditing)

        let lists = NSStackView(views: [includedView, excludedView])
        lists.orientation = .horizontal
        lists.alignment = .top
        lists.distribution = .fillEqually
        lists.spacing = 20
        let buttons = NSStackView(views: [saveButton, doneButton])
        buttons.spacing = 10
        let stack = NSStackView(views: [
            explanationLabel, lists, validationLabel, otherAppsTitle, otherAppsControl, footerLabel, buttons
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            lists.widthAnchor.constraint(equalTo: stack.widthAnchor),
            includedView.heightAnchor.constraint(equalTo: excludedView.heightAnchor),
            explanationLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            validationLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footerLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        load(scope)
    }

    private func refreshValidation() {
        let message = scope.validationMessage
        validationLabel.stringValue = message ?? ""
        validationLabel.toolTip = message
        saveButton.isEnabled = canSaveHome && message == nil
    }

    private func publish(_ updated: ForegroundApplicationScope) {
        load(updated)
        changeHandler(updated)
    }

    private func chooseApplications(for list: ForegroundApplicationScope.List) {
        guard let window, openPanel == nil else {
            return
        }

        let panel = NSOpenPanel()
        panel.message = list == .included ? "Choose apps to include." : "Choose apps to exclude."
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        openPanel = panel

        panel.beginSheetModal(for: window) { [weak self, weak panel] response in
            guard let self, let panel, self.openPanel === panel else {
                return
            }

            self.openPanel = nil
            guard response == .OK, !self.isClosed else {
                return
            }

            let applications: [ForegroundApplicationScope.Application] = panel.urls.compactMap { url in
                defer { url.stopAccessingSecurityScopedResource() }
                guard let bundle = Bundle(url: url),
                      let identifier = bundle.bundleIdentifier,
                      !identifier.isEmpty
                else {
                    return nil
                }

                return .init(
                    bundleIdentifier: identifier,
                    displayName: FileManager.default.displayName(atPath: url.path)
                )
            }

            self.publish(self.scope.adding(applications, to: list))
        }
    }

    @objc private func addIncludedApps() { chooseApplications(for: .included) }
    @objc private func addExcludedApps() { chooseApplications(for: .excluded) }

    @objc
    private func removeIncludedApps() {
        let selected = includedView.selectedIdentifiers
        var updated = scope
        updated.includedApplications.removeAll { selected.contains($0.bundleIdentifier) }
        publish(updated)
    }

    @objc
    private func removeExcludedApps() {
        let selected = excludedView.selectedIdentifiers
        var updated = scope
        updated.excludedApplications.removeAll { selected.contains($0.bundleIdentifier) }
        publish(updated)
    }

    @objc
    private func otherAppsBehaviorDidChange() {
        var updated = scope
        let index = otherAppsControl.indexOfSelectedItem
        guard (0...2).contains(index) else {
            return
        }

        updated.allowsOtherApplications = index == 0
        updated.allowsManualActivationForOtherApplications = index == 2
        publish(updated)
    }

    @objc
    private func saveHomeDraft() {
        guard scope.validationMessage == nil else {
            return
        }

        _ = saveHandler()
    }

    @objc private func finishEditing() { close() }
}
