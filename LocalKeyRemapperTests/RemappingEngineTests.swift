//
//  RemappingEngineTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import XCTest
@testable import LocalKeyRemapper

final class RemappingEngineTests: XCTestCase {

    func testMappedKeyReturnsReplacement() {
        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    sourceKeyCode: KeyCode.v,
                    destinationKeyCode: KeyCode.w
                )
            ]
        )

        let decision = engine.decision(for: KeyCode.v)

        XCTAssertEqual(
            decision,
            .replaceKeyCode(KeyCode.w)
        )
    }

    func testUnmappedKeyPassesThrough() {
        let engine = RemappingEngine(
            rules: [
                RemapRule(
                    sourceKeyCode: KeyCode.v,
                    destinationKeyCode: KeyCode.w
                )
            ]
        )

        let decision = engine.decision(for: KeyCode.w)

        XCTAssertEqual(
            decision,
            .passThrough
        )
    }

    func testReplacingRulesUpdatesTheEngine() {
        let engine = RemappingEngine()

        XCTAssertEqual(
            engine.decision(for: KeyCode.v),
            .passThrough
        )

        engine.replaceRules(
            [
                RemapRule(
                    sourceKeyCode: KeyCode.v,
                    destinationKeyCode: KeyCode.w
                )
            ]
        )

        XCTAssertEqual(
            engine.decision(for: KeyCode.v),
            .replaceKeyCode(KeyCode.w)
        )
    }
}
