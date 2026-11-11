//
//  ProfileApplicationActivationWindowController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 11/11/26.
//

import AppKit
import UniformTypeIdentifiers

/// A temporary editor for one profile UUID in the shared Home draft.
@MainActor
final class ProfileApplicationActivationWindowController: NSWindowController, NSWindowDelegate {
    let profileID: UUID
    private let applicationList = ApplicationSelectionListView(
        title: "Activate this profile for", identifier: "profile.apps.list"
    )
    private let explanationLabel = NSTextField(wrappingLabelWithString:
        "Enabled apps select this profile automatically when they are in front. Use the switches to pause individual assignments."
    )
    private let remappingCheckbox = NSButton(
        checkboxWithTitle: "Also turn remapping on automatically", target: nil, action: nil
    )
    private let validationLabel = NSTextField(wrappingLabelWithString: "")
    private let globalConflictLabel = NSTextField(wrappingLabelWithString:
        "Remapping stays off for apps marked as globally excluded. Edit Excluded Apps in Remapping by App to change this."
    )
    private let footerLabel = NSTextField(wrappingLabelWithString:
        "Excluded apps stay off. Changes use Home Save and Undo/Redo."
    )
    private let saveButton = NSButton(title: "Save Home", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private var activation: ProfileApplicationActivation
    private var conflicts = ProfileApplicationConflicts()
    private let changeHandler: (ProfileApplicationActivation) throws -> Void
    private let saveHandler: () -> Bool
    private let closeHandler: () -> Void
    private var openPanel: NSOpenPanel?
    private var isClosed = false
    private var canSaveHome = false
    private var validationMessage: String?

    init(
        profile: RemappingProfile,
        changeHandler: @escaping (ProfileApplicationActivation) throws -> Void,
        saveHandler: @escaping () -> Bool,
        closeHandler: @escaping () -> Void
    ) {
        profileID = profile.id
        activation = profile.applicationActivation
        self.changeHandler = changeHandler
        self.saveHandler = saveHandler
        self.closeHandler = closeHandler
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 510),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.contentMinSize = NSSize(width: 560, height: 510)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        configureContent()
        load(profile: profile, validationMessage: nil)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func load(
        profile: RemappingProfile,
        validationMessage: String?,
        conflicts: ProfileApplicationConflicts = .init()
    ) {
        guard profile.id == profileID else { return }
        activation = profile.applicationActivation
        self.conflicts = conflicts
        window?.title = "Apps — \(profile.name)"
        refreshApplicationList()
        remappingCheckbox.state = activation.enablesRemapping ? .on : .off
        self.validationMessage = validationMessage
        validationLabel.stringValue = validationMessage ?? ""
        validationLabel.toolTip = validationMessage
        validationLabel.isHidden = validationMessage == nil
        refreshSaveButton()
    }

    func applyFonts(title: NSFont, description: NSFont, control: NSFont) {
        applicationList.applyFonts(title: title, description: description, control: control)
        explanationLabel.font = description
        footerLabel.font = description
        validationLabel.font = description
        globalConflictLabel.font = description
        remappingCheckbox.font = control
        saveButton.font = control
        doneButton.font = control
        let minimumWidth = max(560, ceil(remappingCheckbox.fittingSize.width) + 48)
        window?.contentMinSize = NSSize(width: minimumWidth, height: max(510, 510 * control.pointSize / 14))
        if let window, let content = window.contentView,
           content.bounds.width < window.contentMinSize.width || content.bounds.height < window.contentMinSize.height {
            window.setContentSize(NSSize(
                width: max(content.bounds.width, window.contentMinSize.width),
                height: max(content.bounds.height, window.contentMinSize.height)
            ))
        }
    }

    func setSaveEnabled(_ enabled: Bool) {
        canSaveHome = enabled
        refreshSaveButton()
    }

    override func close() {
        isClosed = true
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
        guard let content = window?.contentView else { return }
        explanationLabel.textColor = .secondaryLabelColor
        footerLabel.textColor = .secondaryLabelColor
        validationLabel.textColor = .systemRed
        validationLabel.maximumNumberOfLines = 4
        validationLabel.lineBreakMode = .byWordWrapping
        globalConflictLabel.textColor = .secondaryLabelColor
        applicationList.addButton.target = self
        applicationList.addButton.action = #selector(addApps)
        applicationList.removeButton.target = self
        applicationList.removeButton.action = #selector(removeApps)
        applicationList.onActivationChange = { [weak self] applications in
            guard let self else { return }
            var updated = self.activation
            updated.applications = applications
            self.publish(updated)
        }
        remappingCheckbox.identifier = NSUserInterfaceItemIdentifier("profile.apps.enableRemapping")
        remappingCheckbox.target = self
        remappingCheckbox.action = #selector(changeRemapping)
        saveButton.identifier = NSUserInterfaceItemIdentifier("profile.apps.save")
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveHome)
        doneButton.bezelStyle = .rounded
        doneButton.target = self
        doneButton.action = #selector(finishEditing)
        doneButton.keyEquivalent = "\r"

        let buttons = NSStackView(views: [saveButton, doneButton])
        buttons.spacing = 10
        let stack = NSStackView(views: [
            explanationLabel, applicationList, remappingCheckbox, validationLabel, globalConflictLabel, footerLabel, buttons
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
            applicationList.widthAnchor.constraint(equalTo: stack.widthAnchor),
            explanationLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            validationLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            globalConflictLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footerLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func refreshApplicationList() {
        var messages: [String: String] = [:]
        var hasGlobalConflict = false
        for app in activation.enabledApplications {
            let identifier = app.bundleIdentifier
            var reasons: [String] = []
            let profileNames = conflicts.duplicateProfileNames(for: identifier)
            if !profileNames.isEmpty {
                let names = profileNames.map { "“\($0)”" }.joined(separator: ", ")
                reasons.append("This app is assigned to multiple profiles: \(names).")
            }
            if conflicts.conflictsWithGlobalScope(app, in: activation) {
                hasGlobalConflict = true
                reasons.append("This app is globally excluded. Remapping stays off.")
            }
            if !reasons.isEmpty {
                messages[identifier] = reasons.joined(separator: " ")
            }
        }
        applicationList.load(activation.applications, conflictMessages: messages)
        globalConflictLabel.isHidden = !hasGlobalConflict
    }

    private func refreshSaveButton() {
        saveButton.isEnabled = canSaveHome && validationMessage == nil
    }

    private func publish(_ updated: ProfileApplicationActivation) {
        guard !isClosed else { return }
        do {
            try changeHandler(updated)
            activation = updated
            refreshApplicationList()
            remappingCheckbox.state = updated.enablesRemapping ? .on : .off
        } catch {
            validationMessage = error.localizedDescription
            validationLabel.stringValue = error.localizedDescription
            validationLabel.isHidden = false
            remappingCheckbox.state = activation.enablesRemapping ? .on : .off
            refreshSaveButton()
        }
    }

    @objc private func addApps() {
        guard let window, openPanel == nil else { return }
        let panel = NSOpenPanel()
        panel.message = "Choose apps that should activate this profile."
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        openPanel = panel
        panel.beginSheetModal(for: window) { [weak self, weak panel] response in
            guard let self, let panel, self.openPanel === panel else { return }
            self.openPanel = nil
            guard response == .OK, !self.isClosed else { return }
            let applications: [ForegroundApplicationScope.Application] = panel.urls.compactMap { url in
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                guard let identifier = Bundle(url: url)?.bundleIdentifier, !identifier.isEmpty else { return nil }
                return .init(
                    bundleIdentifier: identifier,
                    displayName: FileManager.default.displayName(atPath: url.path)
                )
            }
            self.publish(self.activation.adding(applications))
        }
    }

    @objc private func removeApps() {
        let selected = applicationList.selectedIdentifiers
        var updated = activation
        updated.applications.removeAll { selected.contains($0.bundleIdentifier) }
        publish(updated)
    }

    @objc private func changeRemapping() {
        var updated = activation
        updated.enablesRemapping = remappingCheckbox.state == .on
        publish(updated)
    }

    @objc private func saveHome() {
        guard saveButton.isEnabled else { return }
        _ = saveHandler()
    }

    @objc private func finishEditing() { close() }
}
