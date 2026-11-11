//
//  ForegroundApplicationScopeWindowTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 10/11/26.
//

import AppKit
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ForegroundApplicationScopeWindowTests: XCTestCase {
    private let application = ForegroundApplicationScope.Application(
        bundleIdentifier: "com.example.editor",
        displayName: "Editor"
    )

    func testWindowShowsBothListsAndBlocksSavingUntilOverlapIsResolved() throws {
        _ = NSApplication.shared
        var saves = 0
        let controller = ForegroundApplicationScopeWindowController(
            scope: .init(
                includedApplications: [application],
                excludedApplications: [application]
            ),
            changeHandler: { _ in },
            saveHandler: {
                saves += 1
                return true
            },
            closeHandler: {}
        )
        defer { controller.close() }
        controller.setSaveEnabled(true)

        let content = try XCTUnwrap(controller.window?.contentView)
        let tables: [NSTableView] = descendants(in: content)
        XCTAssertEqual(tables.count, 2)
        XCTAssertTrue(tables.allSatisfy { $0.numberOfRows == 1 })
        let buttons: [NSButton] = descendants(in: content)
        let save = try XCTUnwrap(buttons.first { $0.title == "Save Home" })
        XCTAssertFalse(save.isEnabled)

        save.performClick(nil)
        XCTAssertEqual(saves, 0)
        controller.load(.init(includedApplications: [application]))
        XCTAssertTrue(save.isEnabled)
        save.performClick(nil)
        XCTAssertEqual(saves, 1)
    }

    func testRemovingAnExcludedAppPublishesTheResolvedHomeDraft() throws {
        _ = NSApplication.shared
        var published: ForegroundApplicationScope?
        let controller = ForegroundApplicationScopeWindowController(
            scope: .init(
                includedApplications: [application],
                excludedApplications: [application]
            ),
            changeHandler: { published = $0 },
            saveHandler: { true },
            closeHandler: {}
        )
        defer { controller.close() }
        let content = try XCTUnwrap(controller.window?.contentView)
        let tables: [NSTableView] = descendants(in: content)
        let excluded = try XCTUnwrap(tables.first {
            $0.identifier?.rawValue == "scope.excludedApps"
        })
        excluded.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let buttons: [NSButton] = descendants(in: content)
        let remove = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "scope.excludedApps.remove"
        })
        XCTAssertTrue(remove.isEnabled)
        remove.performClick(nil)

        XCTAssertEqual(published?.includedApplications, [application])
        XCTAssertEqual(published?.excludedApplications, [])
        XCTAssertNil(published?.validationMessage)
    }

    func testOtherAppsMenuOffersAndPublishesTheManualActivationChoice() throws {
        _ = NSApplication.shared
        var published: ForegroundApplicationScope?
        let controller = ForegroundApplicationScopeWindowController(
            scope: .unrestricted,
            changeHandler: { published = $0 },
            saveHandler: { true },
            closeHandler: {}
        )
        defer { controller.close() }

        let content = try XCTUnwrap(controller.window?.contentView)
        let menus: [NSPopUpButton] = descendants(in: content)
        let menu = try XCTUnwrap(menus.first { $0.identifier?.rawValue == "scope.otherApps" })
        XCTAssertEqual(menu.itemTitles, [
            "Use Manual Setting", "Keep Remapping Off", "Allow Manual Activation"
        ])

        menu.selectItem(at: 2)
        let action = try XCTUnwrap(menu.action)
        XCTAssertTrue(NSApp.sendAction(action, to: menu.target, from: menu))
        XCTAssertEqual(published?.allowsOtherApplications, false)
        XCTAssertEqual(published?.allowsManualActivationForOtherApplications, true)

        menu.selectItem(at: 1)
        XCTAssertTrue(NSApp.sendAction(action, to: menu.target, from: menu))
        XCTAssertEqual(published?.allowsOtherApplications, false)
        XCTAssertEqual(published?.allowsManualActivationForOtherApplications, false)
    }

    func testActiveProfileWarningRefreshesWithSameScopeAndAllowsSave() throws {
        _ = NSApplication.shared
        let scope = ForegroundApplicationScope(excludedApplications: [application])
        let conflictingProfile = RemappingProfile(
            name: "Editor profile",
            applicationActivation: .init(applications: [application], enablesRemapping: true)
        )
        let otherProfile = RemappingProfile(name: "Other profile")
        let conflicts = ProfileApplicationConflicts(profiles: [conflictingProfile, otherProfile], scope: scope)
        let view = ForegroundApplicationScopeView()
        defer { view.closeEditor() }
        view.load(scope, activeProfileConflictWarning: conflicts.globalWarning(for: conflictingProfile))
        view.setSaveEnabled(true)
        var saved = false
        view.onSave = {
            saved = true
            return true
        }

        let configureButtons: [NSButton] = descendants(in: view)
        let configure = try XCTUnwrap(configureButtons.first {
            $0.identifier?.rawValue == "home.foregroundApplicationScope.configure"
        })
        let existingWindows = Set(NSApp.windows.map { ObjectIdentifier($0) })
        configure.performClick(nil)
        let window = try XCTUnwrap(NSApp.windows.first {
            $0.title == "Remapping by App" && !existingWindows.contains(ObjectIdentifier($0))
        })
        let content = try XCTUnwrap(window.contentView)
        let labels: [NSTextField] = descendants(in: content)
        let warning = try XCTUnwrap(labels.first { $0.identifier?.rawValue == "scope.activeProfileConflict" })
        XCTAssertFalse(warning.isHidden)
        XCTAssertTrue(warning.stringValue.contains(conflictingProfile.name))
        XCTAssertTrue(warning.stringValue.contains(application.displayName))

        let buttons: [NSButton] = descendants(in: content)
        let save = try XCTUnwrap(buttons.first { $0.title == "Save Home" })
        XCTAssertTrue(save.isEnabled)
        save.performClick(nil)
        XCTAssertTrue(saved)

        view.load(scope, activeProfileConflictWarning: conflicts.globalWarning(for: otherProfile))
        XCTAssertTrue(warning.isHidden)
        XCTAssertTrue(save.isEnabled)
    }

    private func descendants<T: NSView>(in root: NSView) -> [T] {
        var result: [T] = []
        if let match = root as? T {
            result.append(match)
        }
        for child in root.subviews {
            let childMatches: [T] = descendants(in: child)
            result.append(contentsOf: childMatches)
        }
        return result
    }
}
