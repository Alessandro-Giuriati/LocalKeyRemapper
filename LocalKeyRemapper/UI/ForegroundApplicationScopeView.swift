//
//  ForegroundApplicationScopeView.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 10/11/26.
//

import AppKit

/// Presents the saved Home draft and owns its temporary app-scope window.
@MainActor
final class ForegroundApplicationScopeView: NSStackView {
    private let titleLabel = NSTextField(labelWithString: "Remapping by App")
    private let descriptionLabel = NSTextField(wrappingLabelWithString:
        "Turn remapping on or off automatically when you use selected apps."
    )
    private let summaryLabel = NSTextField(wrappingLabelWithString: "")
    private let configureButton = NSButton(title: "Configure Apps…", target: nil, action: nil)
    private var scope: ForegroundApplicationScope?
    private var activeProfileConflictWarning: String?
    private var editorController: ForegroundApplicationScopeWindowController?
    private var titleFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
    private var descriptionFont = NSFont.systemFont(ofSize: 13)
    private var controlFont = NSFont.systemFont(ofSize: 14)
    private var canSaveHome = false

    var onChange: ((ForegroundApplicationScope) -> Void)?
    var onSave: (() -> Bool)?

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 8
        descriptionLabel.textColor = .secondaryLabelColor
        configureButton.bezelStyle = .rounded
        configureButton.identifier = NSUserInterfaceItemIdentifier("home.foregroundApplicationScope.configure")
        configureButton.target = self
        configureButton.action = #selector(ForegroundApplicationScopeView.openScopeEditor)
        setViews([titleLabel, descriptionLabel, summaryLabel, configureButton], in: .leading)
        NSLayoutConstraint.activate([
            descriptionLabel.widthAnchor.constraint(equalTo: widthAnchor),
            summaryLabel.widthAnchor.constraint(equalTo: widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func applyFonts(title: NSFont, description: NSFont, control: NSFont) {
        titleFont = title
        descriptionFont = description
        controlFont = control
        titleLabel.font = title
        descriptionLabel.font = description
        summaryLabel.font = description
        configureButton.font = control
        editorController?.applyFonts(title: title, description: description, control: control)
    }

    func load(_ scope: ForegroundApplicationScope, activeProfileConflictWarning: String? = nil) {
        if self.activeProfileConflictWarning != activeProfileConflictWarning {
            self.activeProfileConflictWarning = activeProfileConflictWarning
            editorController?.setActiveProfileConflictWarning(activeProfileConflictWarning)
        }

        guard self.scope != scope else {
            return
        }

        self.scope = scope
        let behavior: String
        if scope.allowsOtherApplications {
            behavior = "use manual setting"
        } else if scope.allowsManualActivationForOtherApplications {
            behavior = "allow temporary manual activation"
        } else {
            behavior = "stay off"
        }
        let included = scope.includedApplications.lazy.filter(\.isEnabled).count
        let excluded = scope.excludedApplications.lazy.filter(\.isEnabled).count
        let inactive = scope.includedApplications.count + scope.excludedApplications.count - included - excluded
        let inactiveSummary = inactive > 0 ? " · \(inactive) inactive" : ""
        summaryLabel.stringValue =
            "\(included) included · \(excluded) excluded\(inactiveSummary) · Other apps \(behavior)"
        if scope.validationMessage != nil {
            summaryLabel.stringValue += "\nResolve apps enabled in both groups before saving."
            summaryLabel.textColor = .systemRed
        } else {
            summaryLabel.textColor = .secondaryLabelColor
        }

        editorController?.load(scope)
    }

    func setSaveEnabled(_ enabled: Bool) {
        canSaveHome = enabled
        editorController?.setSaveEnabled(enabled)
    }

    func closeEditor() {
        let controller = editorController
        editorController = nil
        controller?.close()
    }

    @objc
    private func openScopeEditor() {
        guard let scope else {
            return
        }

        if editorController == nil {
            editorController = ForegroundApplicationScopeWindowController(
                scope: scope,
                changeHandler: { [weak self] updated in
                    self?.onChange?(updated)
                },
                saveHandler: { [weak self] in
                    self?.onSave?() ?? false
                },
                closeHandler: { [weak self] in
                    self?.editorController = nil
                }
            )
            editorController?.applyFonts(
                title: titleFont,
                description: descriptionFont,
                control: controlFont
            )
            editorController?.setSaveEnabled(canSaveHome)
            editorController?.setActiveProfileConflictWarning(activeProfileConflictWarning)
        }

        editorController?.showWindow(nil)
        editorController?.window?.makeKeyAndOrderFront(nil)
    }
}
