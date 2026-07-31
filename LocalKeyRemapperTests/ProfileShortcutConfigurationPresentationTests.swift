//
//  ProfileShortcutConfigurationPresentationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileShortcutConfigurationPresentationTests:
    XCTestCase
{
    func testNilOverrideCreatesUseDefaultDraft() {
        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    nil
            )

        XCTAssertEqual(
            draft.mode,
            .useDefault
        )

        XCTAssertEqual(
            draft.proposal,
            .complete(
                nil
            )
        )
    }

    func testDisabledOverrideCreatesExplicitOffDraft() {
        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .disabled
            )

        XCTAssertEqual(
            draft.mode,
            .off
        )

        XCTAssertEqual(
            draft.proposal,
            .complete(
                .disabled
            )
        )
    }

    func testToggleOverridePreservesItsShortcut() {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.n
            )

        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .toggle(
                        shortcut
                    )
            )

        XCTAssertEqual(
            draft.mode,
            .toggle
        )

        XCTAssertEqual(
            draft.toggleShortcut,
            shortcut
        )

        XCTAssertEqual(
            draft.proposal,
            .complete(
                .toggle(
                    shortcut
                )
            )
        )
    }

    func testSeparateOverridePreservesBothShortcuts() {
        let enableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let disableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            enableShortcut,
                        disable:
                            disableShortcut
                    )
            )

        XCTAssertEqual(
            draft.mode,
            .separate
        )

        XCTAssertEqual(
            draft.enableShortcut,
            enableShortcut
        )

        XCTAssertEqual(
            draft.disableShortcut,
            disableShortcut
        )

        XCTAssertEqual(
            draft.proposal,
            .complete(
                .separate(
                    enable:
                        enableShortcut,
                    disable:
                        disableShortcut
                )
            )
        )
    }

    func testChangingUseDefaultDraftToToggleUsesSuggestedShortcut() {
        var draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    nil
            )

        draft.mode =
            .toggle

        XCTAssertEqual(
            draft.proposal,
            .complete(
                .toggle(
                    ProfileShortcutConfigurationDraft
                        .defaultToggleShortcut
                )
            )
        )
    }

    func testMissingToggleShortcutProducesIncompleteProposal() {
        var draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .toggle(
                        makeShortcut(
                            keyCode:
                                KeyCode.n
                        )
                    )
            )

        draft.toggleShortcut =
            nil

        XCTAssertEqual(
            draft.proposal,
            .incomplete
        )
    }

    func testMissingSeparateShortcutProducesIncompleteProposal() {
        var draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            makeShortcut(
                                keyCode:
                                    KeyCode.e
                            ),
                        disable:
                            makeShortcut(
                                keyCode:
                                    KeyCode.d
                            )
                    )
            )

        draft.disableShortcut =
            nil

        XCTAssertEqual(
            draft.proposal,
            .incomplete
        )
    }

    func testUseDefaultProposalResolvesCurrentDefault() {
        let defaultConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    nil
            )

        XCTAssertEqual(
            draft.proposal
                .effectiveConfiguration(
                    defaultConfiguration:
                        defaultConfiguration
                ),
            defaultConfiguration
        )
    }

    func testOverrideEqualToDefaultRemainsExplicit() {
        let defaultConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    defaultConfiguration
            )

        XCTAssertEqual(
            draft.mode,
            .toggle
        )

        XCTAssertEqual(
            draft.proposal,
            .complete(
                defaultConfiguration
            )
        )

        XCTAssertEqual(
            draft.proposal
                .effectiveConfiguration(
                    defaultConfiguration:
                        defaultConfiguration
                ),
            defaultConfiguration
        )
    }

    func testPresentationProducesExpectedTableAndDetailTitles() {
        let toggleShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let enableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let disableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        XCTAssertEqual(
            ProfileShortcutConfigurationPresentation
                .tableTitle(
                    for:
                        nil
                ),
            "Default"
        )

        XCTAssertEqual(
            ProfileShortcutConfigurationPresentation
                .tableTitle(
                    for:
                        .disabled
                ),
            "Off"
        )

        XCTAssertEqual(
            ProfileShortcutConfigurationPresentation
                .tableTitle(
                    for:
                        .toggle(
                            toggleShortcut
                        )
                ),
            KeyCombinationDisplayName
                .name(
                    for:
                        toggleShortcut
                )
        )

        XCTAssertEqual(
            ProfileShortcutConfigurationPresentation
                .tableTitle(
                    for:
                        .separate(
                            enable:
                                enableShortcut,
                            disable:
                                disableShortcut
                        )
                ),
            "Separate"
        )

        XCTAssertEqual(
            ProfileShortcutConfigurationPresentation
                .detailTitle(
                    for:
                        nil,
                    defaultConfiguration:
                        .disabled
                ),
            "Uses Default Global Shortcuts: Off"
        )

        XCTAssertEqual(
            ProfileShortcutConfigurationPresentation
                .configurationTitle(
                    .separate(
                        enable:
                            enableShortcut,
                        disable:
                            disableShortcut
                    )
                ),
            "Enable: "
                + KeyCombinationDisplayName
                    .name(
                        for:
                            enableShortcut
                    )
                + " · Disable: "
                + KeyCombinationDisplayName
                    .name(
                        for:
                            disableShortcut
                    )
        )
    }

    private func makeShortcut(
        keyCode:
            CGKeyCode
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
}
