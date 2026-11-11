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
    private let includedView = ApplicationSelectionListView(title: "Included Apps", identifier: "scope.includedApps")
    private let excludedView = ApplicationSelectionListView(title: "Excluded Apps", identifier: "scope.excludedApps")
    private let otherAppsTitle = NSTextField(labelWithString: "Other Apps")
    private let otherAppsControl = NSPopUpButton(frame: .zero, pullsDown: false)
    private let explanationLabel = NSTextField(wrappingLabelWithString:
        "Included apps and profile app settings can turn remapping on automatically. Excluded apps keep remapping off."
    )
    private let validationLabel = NSTextField(wrappingLabelWithString: "")
    private let activeProfileConflictLabel = NSTextField(wrappingLabelWithString: "")
    private let footerLabel = NSTextField(wrappingLabelWithString: "")
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
        setActiveProfileConflictWarning(nil)
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
        let behaviorDescription: String
        switch otherAppsIndex {
        case 0:
            behaviorDescription = "Other apps follow the global manual switch in Home. Its setting carries across apps."
        case 1:
            behaviorDescription = "Remapping stays off in other apps, even when the global manual switch is on."
        default:
            behaviorDescription = "Remapping starts off in each other app. Turn it on in Home, from the menu bar, or with a shortcut. It turns off when you switch to a different app outside LocalKeyRemapper."
        }
        footerLabel.stringValue = behaviorDescription + " Save Home applies all Home changes."
        refreshValidation()
    }

    func setActiveProfileConflictWarning(_ message: String?) {
        activeProfileConflictLabel.stringValue = message ?? ""
        activeProfileConflictLabel.toolTip = message
        activeProfileConflictLabel.isHidden = message == nil
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
        activeProfileConflictLabel.font = description
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
        activeProfileConflictLabel.identifier = NSUserInterfaceItemIdentifier("scope.activeProfileConflict")
        activeProfileConflictLabel.textColor = .systemOrange
        activeProfileConflictLabel.maximumNumberOfLines = 3
        activeProfileConflictLabel.lineBreakMode = .byTruncatingTail
        otherAppsControl.addItems(withTitles: [
            "Use Manual Setting",
            "Keep Remapping Off",
            "Allow Manual Activation"
        ])
        otherAppsControl.identifier = NSUserInterfaceItemIdentifier("scope.otherApps")
        otherAppsControl.setAccessibilityLabel("Remapping for apps without an explicit remapping rule")
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
            explanationLabel, lists, validationLabel, activeProfileConflictLabel, otherAppsTitle, otherAppsControl, footerLabel, buttons
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
            activeProfileConflictLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
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
