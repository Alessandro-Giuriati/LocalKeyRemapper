//
//  EventTapManager.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import CoreFoundation
import CoreGraphics

/// Represents an error that can occur while creating
/// or installing the keyboard event tap.
nonisolated enum EventTapError: Error, Equatable {

    /// Core Graphics could not create the event tap.
    case creationFailed

    /// Core Foundation could not create the run loop source.
    case runLoopSourceCreationFailed
}

/// Creates, installs, and removes the keyboard event tap.
///
/// The event tap listens only for key-down and key-up events.
/// It does not store, log, or transmit keyboard input.
@MainActor
final class EventTapManager: EventTapManaging {

    private let remappingEngine: RemappingEngine

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool {
        eventTap != nil && runLoopSource != nil
    }

    init(remappingEngine: RemappingEngine) {
        self.remappingEngine = remappingEngine
    }

    func start() throws {
        guard !isRunning else {
            return
        }

        let eventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue)

        let userInfo = Unmanaged
            .passUnretained(self)
            .toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: userInfo
        ) else {
            throw EventTapError.creationFailed
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            throw EventTapError.runLoopSourceCreationFailed
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            runLoopSource,
            .commonModes
        )

        CGEvent.tapEnable(
            tap: eventTap,
            enable: true
        )
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(
                tap: eventTap,
                enable: false
            )
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )

            CFRunLoopSourceInvalidate(runLoopSource)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private static let eventTapCallback: CGEventTapCallBack = {
        _,
        eventType,
        event,
        userInfo in

        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<EventTapManager>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

        return MainActor.assumeIsolated {
            manager.handle(
                eventType: eventType,
                event: event
            )
        }
    }

    private func handle(
        eventType: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        if eventType == .tapDisabledByTimeout {
            reenableAfterTimeout()
            return Unmanaged.passUnretained(event)
        }

        guard
            eventType == .keyDown ||
            eventType == .keyUp
        else {
            return Unmanaged.passUnretained(event)
        }

        let sourceKeyCode = CGKeyCode(
            event.getIntegerValueField(
                .keyboardEventKeycode
            )
        )

        let decision = remappingEngine.decision(
            for: sourceKeyCode
        )

        switch decision {
        case .passThrough:
            return Unmanaged.passUnretained(event)

        case .replaceKeyCode(let destinationKeyCode):
            event.setIntegerValueField(
                .keyboardEventKeycode,
                value: Int64(destinationKeyCode)
            )

            return Unmanaged.passUnretained(event)
        }
    }

    private func reenableAfterTimeout() {
        guard let eventTap, isRunning else {
            return
        }

        CGEvent.tapEnable(
            tap: eventTap,
            enable: true
        )
    }
}
