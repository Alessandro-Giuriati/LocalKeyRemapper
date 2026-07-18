//
//  GlobalShortcutManager.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import Carbon.HIToolbox

/// Represents a failure that can occur while registering
/// or managing the application's global shortcut.
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

    /// The requested keyboard shortcut could not be registered.
    ///
    /// This commonly happens when another application or macOS
    /// already owns the same combination.
    case registrationFailed(
        OSStatus
    )

    /// Carbon reported success but did not return
    /// a hot-key reference.
    case missingHotKeyReference
}

/// Defines the operations required to manage one global shortcut.
@MainActor
protocol GlobalShortcutRegistering:
    AnyObject
{
    /// The shortcut currently registered with macOS.
    var registeredShortcut:
        KeyCombination?
    {
        get
    }

    /// Registers a global shortcut and associates it with an action.
    ///
    /// Registering a new shortcut replaces the existing registration.
    func register(
        _ shortcut:
            KeyCombination,
        action:
            @escaping () -> Void
    ) throws

    /// Removes the current global shortcut registration.
    func unregister()

    /// Removes both the hot key and the Carbon event handler.
    func stop()
}

/// Registers one specific keyboard shortcut with macOS.
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

    private static let hotKeyNumericID:
        UInt32 = 1

    private static let hotKeyIdentifier =
        EventHotKeyID(
            signature:
                hotKeySignature,
            id:
                hotKeyNumericID
        )

    private var eventHandlerReference:
        EventHandlerRef?

    private var hotKeyReference:
        EventHotKeyRef?

    private var action:
        (() -> Void)?

    private(set) var registeredShortcut:
        KeyCombination?

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
            receivedIdentifier.id
                == GlobalShortcutManager
                    .hotKeyNumericID
        else {
            return OSStatus(
                eventNotHandledErr
            )
        }

        let manager =
            Unmanaged<
                GlobalShortcutManager
            >
            .fromOpaque(userData)
            .takeUnretainedValue()

        Task { @MainActor in
            manager.performRegisteredAction()
        }

        return OSStatus(
            noErr
        )
    }

    func register(
        _ shortcut:
            KeyCombination,
        action:
            @escaping () -> Void
    ) throws {
        unregister()

        try installEventHandlerIfNeeded()

        self.action =
            action

        var newHotKeyReference:
            EventHotKeyRef?

        let registrationStatus =
            RegisterEventHotKey(
                UInt32(
                    shortcut.keyCode
                ),
                GlobalShortcutManager
                    .carbonModifiers(
                        for:
                            shortcut.modifiers
                    ),
                GlobalShortcutManager
                    .hotKeyIdentifier,
                GetApplicationEventTarget(),
                0,
                &newHotKeyReference
            )

        guard
            registrationStatus == noErr
        else {
            self.action = nil

            throw GlobalShortcutError
                .registrationFailed(
                    registrationStatus
                )
        }

        guard let newHotKeyReference else {
            self.action = nil

            throw GlobalShortcutError
                .missingHotKeyReference
        }

        hotKeyReference =
            newHotKeyReference

        registeredShortcut =
            shortcut
    }

    func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(
                hotKeyReference
            )
        }

        hotKeyReference = nil
        registeredShortcut = nil
        action = nil
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

    private func installEventHandlerIfNeeded()
        throws
    {
        guard
            eventHandlerReference == nil
        else {
            return
        }

        var eventType =
            EventTypeSpec(
                eventClass:
                    OSType(
                        kEventClassKeyboard
                    ),
                eventKind:
                    UInt32(
                        kEventHotKeyPressed
                    )
            )

        let userData =
            Unmanaged
                .passUnretained(self)
                .toOpaque()

        var newEventHandlerReference:
            EventHandlerRef?

        let installationStatus =
            InstallEventHandler(
                GetApplicationEventTarget(),
                GlobalShortcutManager
                    .carbonEventHandler,
                1,
                &eventType,
                userData,
                &newEventHandlerReference
            )

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

    private func performRegisteredAction() {
        action?()
    }

    /// Converts the application's modifier representation
    /// into the modifier flags expected by Carbon.
    private static func carbonModifiers(
        for modifiers:
            KeyModifiers
    ) -> UInt32 {
        var carbonFlags:
            UInt32 = 0

        if modifiers.contains(.shift) {
            carbonFlags |=
                UInt32(shiftKey)
        }

        if modifiers.contains(.control) {
            carbonFlags |=
                UInt32(controlKey)
        }

        if modifiers.contains(.option) {
            carbonFlags |=
                UInt32(optionKey)
        }

        if modifiers.contains(.command) {
            carbonFlags |=
                UInt32(cmdKey)
        }

        return carbonFlags
    }
}
