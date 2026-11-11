//
//  ProfileApplicationActivationWindowTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 11/11/26.
//

import AppKit
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileApplicationActivationWindowTests: XCTestCase {
    private let app = ForegroundApplicationScope.Application(bundleIdentifier: "com.example.editor", displayName: "Editor")

    func testCheckboxEditsHomeDraftAndReflectsUndoWithoutSaving() throws {
        _ = NSApplication.shared
        let profile = RemappingProfile(name: "Editor")
        let session = HomeConfigurationEditorSession(snapshot: .init(
            profilesConfiguration: .init(profiles: [profile], activeProfileID: profile.id),
            launchBehavior: .alwaysOff, shortcutConfiguration: .disabled
        ))
        let controller = ProfileApplicationActivationWindowController(
            profile: profile,
            changeHandler: { try session.setApplicationActivation($0, for: profile.id) },
            saveHandler: { XCTFail("An edit must not save Home"); return false }, closeHandler: {}
        )
        defer { session.onChange = nil; controller.close() }
        session.onChange = {
            controller.load(profile: session.draft.profiles[0], validationMessage: nil)
        }
        let checkbox = try button("profile.apps.enableRemapping", in: controller)
        XCTAssertEqual(checkbox.state, .off)
        checkbox.performClick(nil)
        XCTAssertTrue(session.draft.profiles[0].applicationActivation.enablesRemapping)
        XCTAssertEqual(session.savedSnapshot.profiles[0].applicationActivation, .disabled)
        session.undo()
        XCTAssertEqual(checkbox.state, .off)
        session.redo()
        XCTAssertEqual(checkbox.state, .on)
    }

    func testRemovingSelectedAppPublishesAnIndependentSelection() throws {
        _ = NSApplication.shared
        let profile = RemappingProfile(name: "Editor", applicationActivation: .init(applications: [app], enablesRemapping: true))
        var published: ProfileApplicationActivation?
        let controller = ProfileApplicationActivationWindowController(
            profile: profile, changeHandler: { published = $0 }, saveHandler: { false }, closeHandler: {}
        )
        defer { controller.close() }
        let content = try XCTUnwrap(controller.window?.contentView)
        let tables: [NSTableView] = descendants(in: content)
        let table = try XCTUnwrap(tables.first)
        XCTAssertEqual(table.numberOfRows, 1)
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try button("profile.apps.list.remove", in: controller).performClick(nil)
        XCTAssertEqual(published?.applications, [])
        XCTAssertEqual(published?.enablesRemapping, true)
        XCTAssertEqual(table.numberOfRows, 0)
        XCTAssertEqual(profile.applicationActivation.applications, [app])
    }

    func testSaveReflectsHomeValidationAndProfileRename() throws {
        _ = NSApplication.shared
        var profile = RemappingProfile(name: "Editor")
        var saves = 0
        let controller = ProfileApplicationActivationWindowController(
            profile: profile, changeHandler: { _ in }, saveHandler: { saves += 1; return true }, closeHandler: {}
        )
        defer { controller.close() }
        controller.setSaveEnabled(true)
        let save = try button("profile.apps.save", in: controller)
        XCTAssertTrue(save.isEnabled)
        controller.load(profile: profile, validationMessage: "The app is assigned to two profiles.")
        XCTAssertFalse(save.isEnabled)
        profile.name = "Renamed"
        controller.load(profile: profile, validationMessage: nil)
        XCTAssertEqual(controller.window?.title, "Apps — Renamed")
        save.performClick(nil)
        XCTAssertEqual(saves, 1)
        controller.setSaveEnabled(false)
        XCTAssertFalse(save.isEnabled)
    }

    func testGlobalConflictClearsWhenAutomaticRemappingIsUncheckedButDuplicateAssignmentsRemain() throws {
        _ = NSApplication.shared
        var profile = RemappingProfile(
            name: "Editor",
            applicationActivation: .init(applications: [app], enablesRemapping: true)
        )
        let scope = ForegroundApplicationScope(excludedApplications: [app])
        let conflicts = ProfileApplicationConflicts(profiles: [profile], scope: scope)
        let controller = ProfileApplicationActivationWindowController(
            profile: profile, changeHandler: { _ in }, saveHandler: { true }, closeHandler: {}
        )
        defer { controller.close() }
        controller.setSaveEnabled(true)
        controller.load(profile: profile, validationMessage: nil, conflicts: conflicts)
        let content = try XCTUnwrap(controller.window?.contentView)
        let tables: [NSTableView] = descendants(in: content)
        let table = try XCTUnwrap(tables.first)
        let conflictingCell = try XCTUnwrap(table.view(atColumn: 0, row: 0, makeIfNecessary: true))
        XCTAssertTrue(conflicts.affects(profile.applicationActivation))
        XCTAssertTrue(conflictingCell.toolTip?.contains("globally excluded") == true)
        XCTAssertTrue(try button("profile.apps.save", in: controller).isEnabled)

        profile.applicationActivation.enablesRemapping = false
        controller.load(profile: profile, validationMessage: nil, conflicts: conflicts)
        let clearedCell = try XCTUnwrap(table.view(atColumn: 0, row: 0, makeIfNecessary: true))
        XCTAssertFalse(conflicts.affects(profile.applicationActivation))
        XCTAssertEqual(clearedCell.toolTip, "\(app.displayName)\n\(app.bundleIdentifier)")

        let otherProfile = RemappingProfile(name: "Other editor", applicationActivation: profile.applicationActivation)
        let profiles = [profile, otherProfile]
        let duplicates = ProfileApplicationConflicts(profiles: profiles, scope: scope)
        controller.load(
            profile: profile,
            validationMessage: ProfileApplicationActivation.validationMessage(for: profiles),
            conflicts: duplicates
        )
        let duplicateCell = try XCTUnwrap(table.view(atColumn: 0, row: 0, makeIfNecessary: true))
        XCTAssertTrue(profiles.allSatisfy { duplicates.affects($0.applicationActivation) })
        XCTAssertTrue(duplicateCell.toolTip?.contains("assigned to multiple profiles") == true)
        XCTAssertFalse(try button("profile.apps.save", in: controller).isEnabled)
    }

    func testLargeFontsLeaveRoomForTheCheckboxAndAppList() throws {
        _ = NSApplication.shared
        let controller = ProfileApplicationActivationWindowController(
            profile: RemappingProfile(name: "Editor"), changeHandler: { _ in }, saveHandler: { false }, closeHandler: {}
        )
        defer { controller.close() }
        controller.applyFonts(
            title: .systemFont(ofSize: 19.6, weight: .semibold),
            description: .systemFont(ofSize: 18.2), control: .systemFont(ofSize: 19.6)
        )
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView)
        content.layoutSubtreeIfNeeded()
        let checkbox = try button("profile.apps.enableRemapping", in: controller)
        XCTAssertGreaterThanOrEqual(content.bounds.width, checkbox.fittingSize.width + 40)
        let tables: [NSTableView] = descendants(in: content)
        XCTAssertEqual(tables.count, 1)
        XCTAssertGreaterThanOrEqual(tables[0].enclosingScrollView?.frame.height ?? 0, 160)
    }

    private func button(_ identifier: String, in controller: NSWindowController) throws -> NSButton {
        let content = try XCTUnwrap(controller.window?.contentView)
        let buttons: [NSButton] = descendants(in: content)
        return try XCTUnwrap(buttons.first { $0.identifier?.rawValue == identifier })
    }

    private func descendants<T: NSView>(in root: NSView) -> [T] {
        var result: [T] = (root as? T).map { [$0] } ?? []
        for child in root.subviews {
            let matches: [T] = descendants(in: child)
            result.append(contentsOf: matches)
        }
        return result
    }
}
