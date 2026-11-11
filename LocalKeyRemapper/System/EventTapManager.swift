//
//  EventTapManager.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import Carbon.HIToolbox
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
/// The event tap listens for key-down, key-up, and modifier-state events.
/// Modifier-state events preserve the supported physical modifier state so
/// function-key events can be matched without losing held modifiers.
/// It does not store, log, persist, or transmit keyboard input.
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
    private var foregroundApplicationAllowsRemapping = true
    private var isDeliveringEvents = false

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

    /// Tracks Fn from ordered modifier events instead of relying only on
    /// function-key metadata attached to the final key event.
    private var fnModifierStateTracker =
        FnModifierStateTracker()

    /// Preserves Shift, Control, Option, and Command across runtime events.
    ///
    /// Some F1 through F12 events omit these modifiers even while they remain
    /// physically held. This tracker keeps the ordered modifier state needed
    /// to match the same combination that the editor captured.
    private var nonFnModifierStateTracker =
        NonFnModifierStateTracker()

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
                << CGEventType.keyUp.rawValue) |
            (CGEventMask(1)
                << CGEventType.flagsChanged.rawValue)

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

        isDeliveringEvents = foregroundApplicationAllowsRemapping
        if isDeliveringEvents {
            synchronizeModifierState()
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            runLoopSource,
            .commonModes
        )

        CGEvent.tapEnable(
            tap:
                eventTap,
            enable:
                isDeliveringEvents
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

        isDeliveringEvents = false
        isPaused =
            false

        isInterruptionNotificationPending =
            false

        activeDecisions.removeAll(
            keepingCapacity:
                true
        )

        resetModifierState()
    }

    func setForegroundApplicationAllowsRemapping(_ allowsRemapping: Bool) {
        guard foregroundApplicationAllowsRemapping != allowsRemapping else {
            return
        }

        foregroundApplicationAllowsRemapping = allowsRemapping

        // A tap that was draining releases may still be enabled. Refresh
        // modifiers because it ignored modifier events while outside scope.
        if allowsRemapping && isDeliveringEvents {
            synchronizeModifierState()
        }

        updateEventTapDelivery()
    }

    func pause() {
        guard isRunning, !isPaused else {
            return
        }

        isPaused = true
        updateEventTapDelivery()
    }

    func resume() {
        guard isRunning, isPaused else {
            return
        }

        isPaused = false
        updateEventTapDelivery()
    }

    private func updateEventTapDelivery() {
        guard let eventTap else {
            return
        }

        let shouldDeliverEvents = !isPaused && (
            foregroundApplicationAllowsRemapping || activeDecisions.values.contains {
                if case .replaceWith = $0 {
                    return true
                }

                return false
            }
        )

        guard isDeliveringEvents != shouldDeliverEvents else {
            return
        }

        if shouldDeliverEvents {
            synchronizeModifierState()
        } else {
            activeDecisions.removeAll(keepingCapacity: true)
            resetModifierState()
        }

        isDeliveringEvents = shouldDeliverEvents
        CGEvent.tapEnable(tap: eventTap, enable: shouldDeliverEvents)
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

    func handle(
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

            resetModifierState()

            scheduleInterruptionNotification()

            return Unmanaged
                .passUnretained(
                    event
                )
        }

        if eventType == .flagsChanged {
            if foregroundApplicationAllowsRemapping {
                updateModifierState(from: event)
            }

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

        guard let decision = decisionForEvent(
            eventType: eventType,
            sourceKeyCode: sourceKeyCode,
            event: event
        ) else {
            return nil
        }

        apply(decision, to: event)

        return Unmanaged
            .passUnretained(
                event
            )
    }

    private func synchronizeModifierState() {
        fnModifierStateTracker.synchronize(
            isPressed:
                PhysicalFnKeyState
                    .isPressed()
        )

        var currentModifiers =
            KeyModifiers(
                eventFlags:
                    CGEventSource.flagsState(
                        .combinedSessionState
                    )
            )

        currentModifiers.remove(
            .fn
        )

        nonFnModifierStateTracker.synchronize(
            currentModifiers:
                currentModifiers
        )
    }

    private func resetModifierState() {
        fnModifierStateTracker.reset()
        nonFnModifierStateTracker.reset()
    }

    private func updateModifierState(
        from event:
            CGEvent
    ) {
        let keyCode =
            CGKeyCode(
                event.getIntegerValueField(
                    .keyboardEventKeycode
                )
            )

        var currentModifiers =
            KeyModifiers(
                eventFlags:
                    event.flags
            )

        currentModifiers.remove(
            .fn
        )

        nonFnModifierStateTracker
            .handleFlagsChanged(
                keyCode:
                    keyCode,
                currentModifiers:
                    currentModifiers
            )

        guard
            keyCode
                == CGKeyCode(
                    kVK_Function
                )
        else {
            return
        }

        fnModifierStateTracker.handleFlagsChanged(
            isPressed:
                event
                    .flags
                    .contains(
                        .maskSecondaryFn
                    )
                || PhysicalFnKeyState
                    .isPressed()
        )
    }

    private func scheduleInterruptionNotification() {
        guard !isInterruptionNotificationPending else {
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
        eventType: CGEventType,
        sourceKeyCode: CGKeyCode,
        event: CGEvent
    ) -> RemapDecision? {
        if eventType == .keyUp {
            let decision = activeDecisions.removeValue(forKey: sourceKeyCode) ?? .passThrough
            if !foregroundApplicationAllowsRemapping {
                updateEventTapDelivery()
            }

            return decision
        }

        if let decision = activeDecisions[sourceKeyCode] {
            // Complete the original release, but do not emit more mapped key
            // presses in the application that paused remapping.
            if !foregroundApplicationAllowsRemapping, case .replaceWith = decision {
                return nil
            }

            return decision
        }

        // A release or repeat without a tracked press can belong to a key that
        // went down while the event tap was disabled. Keep that press native.
        guard foregroundApplicationAllowsRemapping,
              event.getIntegerValueField(.keyboardEventAutorepeat) == 0
        else {
            return .passThrough
        }

        let sourceCombination = KeyCombinationInputNormalizer.capturedCombination(
            deliveredKeyCode: sourceKeyCode,
            eventModifiers: KeyModifiers(eventFlags: event.flags),
            capturedNonFnModifiers: nonFnModifierStateTracker.modifiers,
            trackedPhysicalFnIsPressed: fnModifierStateTracker.isPressed
        )
        let decision = remappingEngine.decision(for: sourceCombination)
        activeDecisions[sourceKeyCode] = decision
        return decision
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
