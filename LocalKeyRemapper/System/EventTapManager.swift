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
nonisolated enum EventTapError:
    Error,
    Equatable
{
    /// Core Graphics could not create the event tap.
    case creationFailed

    /// Core Foundation could not create the run loop source.
    case runLoopSourceCreationFailed
}

/// Creates, installs, pauses, resumes, and removes
/// the keyboard event tap.
///
/// The event tap listens only for key-down and key-up events.
/// It does not store, log, or transmit keyboard input.
@MainActor
final class EventTapManager:
    EventTapManaging
{
    private let remappingEngine:
        RemappingEngine

    private var eventTap:
        CFMachPort?

    private var runLoopSource:
        CFRunLoopSource?

    private var isPaused = false

    private var isInterruptionNotificationPending =
        false

    /// Called after Core Graphics disables the event tap.
    ///
    /// The callback is scheduled after the current event-tap callback
    /// returns, so higher-level code can safely remove or recreate the tap.
    var onInterruption:
        (() -> Void)?

    /// Keeps key-up events consistent with the decision made
    /// for the corresponding physical key-down event.
    ///
    /// This is runtime state only. It is never persisted or logged.
    private var activeDecisions:
        [CGKeyCode: RemapDecision] = [:]

    var isRunning: Bool {
        eventTap != nil &&
        runLoopSource != nil
    }

    init(
        remappingEngine:
            RemappingEngine
    ) {
        self.remappingEngine =
            remappingEngine
    }

    func start() throws {
        guard !isRunning else {
            return
        }

        let eventMask =
            (CGEventMask(1)
                << CGEventType.keyDown.rawValue) |
            (CGEventMask(1)
                << CGEventType.keyUp.rawValue)

        let userInfo =
            Unmanaged
                .passUnretained(
                    self
                )
                .toOpaque()

        guard
            let eventTap =
                CGEvent.tapCreate(
                    tap:
                        .cgSessionEventTap,
                    place:
                        .headInsertEventTap,
                    options:
                        .defaultTap,
                    eventsOfInterest:
                        eventMask,
                    callback:
                        Self.eventTapCallback,
                    userInfo:
                        userInfo
                )
        else {
            throw EventTapError
                .creationFailed
        }

        guard
            let runLoopSource =
                CFMachPortCreateRunLoopSource(
                    kCFAllocatorDefault,
                    eventTap,
                    0
                )
        else {
            CFMachPortInvalidate(
                eventTap
            )

            throw EventTapError
                .runLoopSourceCreationFailed
        }

        self.eventTap =
            eventTap

        self.runLoopSource =
            runLoopSource

        isPaused =
            false

        isInterruptionNotificationPending =
            false

        activeDecisions.removeAll(
            keepingCapacity:
                true
        )

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            runLoopSource,
            .commonModes
        )

        CGEvent.tapEnable(
            tap:
                eventTap,
            enable:
                true
        )
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(
                tap:
                    eventTap,
                enable:
                    false
            )
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )

            CFRunLoopSourceInvalidate(
                runLoopSource
            )
        }

        if let eventTap {
            CFMachPortInvalidate(
                eventTap
            )
        }

        runLoopSource =
            nil

        eventTap =
            nil

        isPaused =
            false

        isInterruptionNotificationPending =
            false

        activeDecisions.removeAll(
            keepingCapacity:
                true
        )
    }

    func pause() {
        guard
            let eventTap,
            isRunning,
            !isPaused
        else {
            return
        }

        CGEvent.tapEnable(
            tap:
                eventTap,
            enable:
                false
        )

        isPaused =
            true

        activeDecisions.removeAll(
            keepingCapacity:
                true
        )
    }

    func resume() {
        guard
            let eventTap,
            isRunning,
            isPaused
        else {
            return
        }

        activeDecisions.removeAll(
            keepingCapacity:
                true
        )

        CGEvent.tapEnable(
            tap:
                eventTap,
            enable:
                true
        )

        isPaused =
            false
    }

    private static let eventTapCallback:
        CGEventTapCallBack =
    {
        _,
        eventType,
        event,
        userInfo in

        guard let userInfo else {
            return Unmanaged
                .passUnretained(
                    event
                )
        }

        let manager =
            Unmanaged<EventTapManager>
                .fromOpaque(
                    userInfo
                )
                .takeUnretainedValue()

        return MainActor.assumeIsolated {
            manager.handle(
                eventType:
                    eventType,
                event:
                    event
            )
        }
    }

    private func handle(
        eventType:
            CGEventType,
        event:
            CGEvent
    ) -> Unmanaged<CGEvent>? {
        if
            eventType
                == .tapDisabledByTimeout
                || eventType
                == .tapDisabledByUserInput
        {
            activeDecisions.removeAll(
                keepingCapacity:
                    true
            )

            scheduleInterruptionNotification()

            return Unmanaged
                .passUnretained(
                    event
                )
        }

        guard
            eventType == .keyDown
                || eventType == .keyUp
        else {
            return Unmanaged
                .passUnretained(
                    event
                )
        }

        let sourceKeyCode =
            CGKeyCode(
                event.getIntegerValueField(
                    .keyboardEventKeycode
                )
            )

        let sourceCombination =
            KeyCombination(
                keyCode:
                    sourceKeyCode,
                modifiers:
                    KeyModifiers(
                        eventFlags:
                            event.flags
                    )
            )

        let decision =
            decisionForEvent(
                eventType:
                    eventType,
                sourceKeyCode:
                    sourceKeyCode,
                sourceCombination:
                    sourceCombination
            )

        apply(
            decision,
            to:
                event
        )

        return Unmanaged
            .passUnretained(
                event
            )
    }

    private func scheduleInterruptionNotification() {
        guard
            !isInterruptionNotificationPending
        else {
            return
        }

        isInterruptionNotificationPending =
            true

        Task {
            @MainActor
            [weak self] in

            guard let self else {
                return
            }

            isInterruptionNotificationPending =
                false

            onInterruption?()
        }
    }

    private func decisionForEvent(
        eventType:
            CGEventType,
        sourceKeyCode:
            CGKeyCode,
        sourceCombination:
            KeyCombination
    ) -> RemapDecision {
        if eventType == .keyDown {
            if
                let activeDecision =
                    activeDecisions[
                        sourceKeyCode
                    ]
            {
                return activeDecision
            }

            let decision =
                remappingEngine.decision(
                    for:
                        sourceCombination
                )

            activeDecisions[
                sourceKeyCode
            ] = decision

            return decision
        }

        if
            let activeDecision =
                activeDecisions.removeValue(
                    forKey:
                        sourceKeyCode
                )
        {
            return activeDecision
        }

        return remappingEngine.decision(
            for:
                sourceCombination
        )
    }

    private func apply(
        _ decision:
            RemapDecision,
        to event:
            CGEvent
    ) {
        switch decision {
        case .passThrough:
            return

        case .replaceWith(
            let destination
        ):
            event.setIntegerValueField(
                .keyboardEventKeycode,
                value:
                    Int64(
                        destination.keyCode
                    )
            )

            event.flags =
                destination.modifiers
                    .applying(
                        to:
                            event.flags
                    )
        }
    }
}
