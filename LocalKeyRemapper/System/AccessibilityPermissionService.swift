//
//  AccessibilityPermissionService.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import ApplicationServices
import CoreFoundation

/// Defines the operations required to check and request
/// macOS Accessibility permission.
nonisolated protocol AccessibilityPermissionChecking {

    /// Indicates whether the current application is already trusted
    /// as an Accessibility client.
    var isGranted: Bool { get }

    /// Requests Accessibility permission from macOS.
    ///
    /// The returned value represents the permission state
    /// at the moment this method is called.
    @discardableResult
    func requestAccess() -> Bool
}

/// Checks and requests the Accessibility permission required
/// by the keyboard remapping system.
///
/// This service does not intercept keyboard events and does not
/// collect, store, or log keyboard input.
nonisolated final class AccessibilityPermissionService:
    AccessibilityPermissionChecking {

    var isGranted: Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    @discardableResult
    func requestAccess() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }
}
