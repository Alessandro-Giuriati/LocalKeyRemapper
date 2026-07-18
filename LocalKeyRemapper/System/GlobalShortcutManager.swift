//
//  GlobalShortcutManager.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import Carbon.HIToolbox

/// Represents a failure that can occur while registering
/// or managing the application's global shortcuts.
nonisolated enum GlobalShortcutError:
    Error,
    Equatable
{
    /// The Carbon event handler could not be installed.
    case eventHandlerInstallationFailed(
        OSStatus
    )

    /// Carbon reported success but did not return
    /// an event-handler reference.
    case missingEventHandlerReference

    /// More than one registration uses the same application action.
    case duplicateAction(
        GlobalShortcutAction
    )

    /// More than one registration uses the same key combination.
    case duplicateShortcut

    /// The requested keyboard shortcut could not be registered.
    ///
    /// This commonly happens when another application or macOS
    /// already owns the same combination.
    case registrationFailed(
        action:
            GlobalShortcutAction,
        status:
            OSStatus
    )

    /// Carbon reported success but did not return
    /// a hot-key reference.
    case missingHotKeyReference(
        GlobalShortcutAction
    )
}

/// Defines the operations required to manage the application's
/// global shortcut registrations.
@MainActor
protocol GlobalShortcutRegistering:
    AnyObject
{
    /// The registrations currently active with macOS.
    var registeredRegistrations:
        [GlobalShortcutRegistration]
    {
        get
    }

    /// Atomically replaces all global shortcut registrations.
    ///
    /// If one registration fails, every registration created by
    /// this call is removed before the error is returned.
    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void
    ) throws

    /// Removes every current global shortcut registration.
    func unregister()

    /// Removes every hot key and the Carbon event handler.
    func stop()
}

/// Registers the application's specific keyboard shortcuts with macOS.
///
/// This manager does not use a global keyboard monitor, does not receive
/// normal typing events, and does not store or log keyboard input.
@MainActor
final class GlobalShortcutManager:
    GlobalShortcutRegistering
{
    /// Four-character identifier: "LKRM".
    private static let hotKeySignature:
        OSType = 0x4C4B524D

    private var eventHandlerReference:
        EventHandlerRef?

    private var hotKeyReferences:
        [GlobalShortcutAction: EventHotKeyRef] = [:]

    private var actionHandler:
        ((
            GlobalShortcutAction
        ) -> Void)?

    /// Tracks pressed actions so one physical press performs
    /// one application command.
    private var pressedActions:
        Set<GlobalShortcutAction> = []

    private(set) var registeredRegistrations:
        [GlobalShortcutRegistration] = []

    /// Receives only Carbon hot-key events delivered
    /// specifically to this application.
    private static let carbonEventHandler:
        EventHandlerUPP =
    {
        _,
        event,
        userData -> OSStatus in

        guard
            let event,
            let userData
        else {
            return OSStatus(
                eventNotHandledErr
            )
        }

        var receivedIdentifier =
            EventHotKeyID(
                signature: 0,
                id: 0
            )

        let parameterStatus =
            GetEventParameter(
                event,
                EventParamName(
                    kEventParamDirectObject
                ),
                EventParamType(
                    typeEventHotKeyID
                ),
                nil,
                MemoryLayout<
                    EventHotKeyID
                >.size,
                nil,
                &receivedIdentifier
            )

        guard
            parameterStatus == noErr
        else {
            return parameterStatus
        }

        guard
            receivedIdentifier.signature
                == GlobalShortcutManager
                    .hotKeySignature,
            let action =
                GlobalShortcutAction(
                    rawValue:
                        receivedIdentifier.id
                )
        else {
            return OSStatus(
                eventNotHandledErr
            )
        }

        let eventKind =
            GetEventKind(
                event
            )

        let manager =
            Unmanaged<
                GlobalShortcutManager
            >
            .fromOpaque(
                userData
            )
            .takeUnretainedValue()

        Task { @MainActor in
            manager.handleHotKeyEvent(
                action:
                    action,
                eventKind:
                    eventKind
            )
        }

        return OSStatus(
            noErr
        )
    }

    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void
    ) throws {
        try validateRegistrations(
            registrations
        )

        unregister()

        guard !registrations.isEmpty else {
            return
        }

        try installEventHandlerIfNeeded()

        self.actionHandler =
            actionHandler

        do {
            for registration in registrations {
                let hotKeyReference =
                    try registerHotKey(
                        registration
                    )

                hotKeyReferences[
                    registration.action
                ] = hotKeyReference
            }

            registeredRegistrations =
                registrations
        } catch {
            unregister()
            throw error
        }
    }

    func unregister() {
        for hotKeyReference in
            hotKeyReferences.values
        {
            UnregisterEventHotKey(
                hotKeyReference
            )
        }

        hotKeyReferences.removeAll()
        registeredRegistrations.removeAll()
        pressedActions.removeAll()
        actionHandler = nil
    }

    func stop() {
        unregister()

        if let eventHandlerReference {
            RemoveEventHandler(
                eventHandlerReference
            )
        }

        eventHandlerReference = nil
    }

    private func validateRegistrations(
        _ registrations:
            [GlobalShortcutRegistration]
    ) throws {
        var seenActions:
            Set<GlobalShortcutAction> = []

        var seenShortcuts:
            Set<KeyCombination> = []

        for registration in registrations {
            guard
                seenActions
                    .insert(
                        registration.action
                    )
                    .inserted
            else {
                throw GlobalShortcutError
                    .duplicateAction(
                        registration.action
                    )
            }

            guard
                seenShortcuts
                    .insert(
                        registration.shortcut
                    )
                    .inserted
            else {
                throw GlobalShortcutError
                    .duplicateShortcut
            }
        }
    }

    private func registerHotKey(
        _ registration:
            GlobalShortcutRegistration
    ) throws -> EventHotKeyRef {
        var newHotKeyReference:
            EventHotKeyRef?

        let identifier =
            EventHotKeyID(
                signature:
                    GlobalShortcutManager
                        .hotKeySignature,
                id:
                    registration
                        .action
                        .rawValue
            )

        let registrationStatus =
            RegisterEventHotKey(
                UInt32(
                    registration
                        .shortcut
                        .keyCode
                ),
                GlobalShortcutManager
                    .carbonModifiers(
                        for:
                            registration
                                .shortcut
                                .modifiers
                    ),
                identifier,
                GetApplicationEventTarget(),
                0,
                &newHotKeyReference
            )

        guard
            registrationStatus == noErr
        else {
            throw GlobalShortcutError
                .registrationFailed(
                    action:
                        registration.action,
                    status:
                        registrationStatus
                )
        }

        guard let newHotKeyReference else {
            throw GlobalShortcutError
                .missingHotKeyReference(
                    registration.action
                )
        }

        return newHotKeyReference
    }

    private func installEventHandlerIfNeeded()
        throws
    {
        guard
            eventHandlerReference == nil
        else {
            return
        }

        let eventTypes =
            [
                EventTypeSpec(
                    eventClass:
                        OSType(
                            kEventClassKeyboard
                        ),
                    eventKind:
                        UInt32(
                            kEventHotKeyPressed
                        )
                ),
                EventTypeSpec(
                    eventClass:
                        OSType(
                            kEventClassKeyboard
                        ),
                    eventKind:
                        UInt32(
                            kEventHotKeyReleased
                        )
                )
            ]

        let userData =
            Unmanaged
                .passUnretained(
                    self
                )
                .toOpaque()

        var newEventHandlerReference:
            EventHandlerRef?

        let installationStatus =
            eventTypes.withUnsafeBufferPointer {
                eventTypesBuffer in

                InstallEventHandler(
                    GetApplicationEventTarget(),
                    GlobalShortcutManager
                        .carbonEventHandler,
                    eventTypesBuffer.count,
                    eventTypesBuffer.baseAddress,
                    userData,
                    &newEventHandlerReference
                )
            }

        guard
            installationStatus == noErr
        else {
            throw GlobalShortcutError
                .eventHandlerInstallationFailed(
                    installationStatus
                )
        }

        guard
            let newEventHandlerReference
        else {
            throw GlobalShortcutError
                .missingEventHandlerReference
        }

        eventHandlerReference =
            newEventHandlerReference
    }

    private func handleHotKeyEvent(
        action:
            GlobalShortcutAction,
        eventKind:
            UInt32
    ) {
        guard
            hotKeyReferences[action] != nil
        else {
            return
        }

        switch eventKind {
        case UInt32(
            kEventHotKeyPressed
        ):
            guard
                pressedActions
                    .insert(
                        action
                    )
                    .inserted
            else {
                return
            }

            actionHandler?(
                action
            )

        case UInt32(
            kEventHotKeyReleased
        ):
            pressedActions.remove(
                action
            )

        default:
            return
        }
    }

    /// Converts the application's modifier representation
    /// into the modifier flags expected by Carbon.
    private static func carbonModifiers(
        for modifiers:
            KeyModifiers
    ) -> UInt32 {
        var carbonFlags:
            UInt32 = 0

        if modifiers.contains(
            .shift
        ) {
            carbonFlags |=
                UInt32(
                    shiftKey
                )
        }

        if modifiers.contains(
            .control
        ) {
            carbonFlags |=
                UInt32(
                    controlKey
                )
        }

        if modifiers.contains(
            .option
        ) {
            carbonFlags |=
                UInt32(
                    optionKey
                )
        }

        if modifiers.contains(
            .command
        ) {
            carbonFlags |=
                UInt32(
                    cmdKey
                )
        }

        return carbonFlags
    }
}
