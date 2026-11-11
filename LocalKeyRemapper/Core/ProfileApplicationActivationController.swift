//
//  ProfileApplicationActivationController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 11/11/26.
//


import Foundation

/// Resolves foreground notifications against committed settings in memory.
/// Reuses the normal activation transaction; no polling or keyboard callbacks.
@MainActor
final class ProfileApplicationActivationController {
    private struct Assignment: Equatable {
        let profileID: UUID
        let enablesRemapping: Bool
    }

    private var assignments: [String: Assignment] = [:]
    private var lastBundleIdentifier: String?
    private var needsRefresh = true
    private let interfaceBundleIdentifier: String?
    private let restoreTemporaryProfile: () throws -> Void
    private let activateProfile: (UUID) throws -> Void
    private let applyRemappingOverride: (String?, Bool?, Bool) -> Void
    private let reportFailure: (UUID?, Error) -> Void

    var foregroundApplicationHasAssignment: Bool {
        guard let lastBundleIdentifier else { return false }
        return assignments[lastBundleIdentifier] != nil
    }

    init(
        interfaceBundleIdentifier: String? = nil,
        restoreTemporaryProfile: @escaping () throws -> Void = {},
        activateProfile: @escaping (UUID) throws -> Void,
        applyRemappingOverride: @escaping (String?, Bool?, Bool) -> Void,
        reportFailure: @escaping (UUID?, Error) -> Void
    ) {
        self.interfaceBundleIdentifier = interfaceBundleIdentifier
        self.restoreTemporaryProfile = restoreTemporaryProfile
        self.activateProfile = activateProfile
        self.applyRemappingOverride = applyRemappingOverride
        self.reportFailure = reportFailure
    }

    /// Only call after a successful Home Save or initial configuration load.
    func load(_ configuration: RemappingProfilesConfiguration) {
        assignments.removeAll(keepingCapacity: true)
        // Persisted configurations are validated. Fail closed if a caller
        // supplies ambiguous data rather than depending on profile ordering.
        do {
            try ProfileApplicationActivation.validate(configuration.profiles)
            for profile in configuration.profiles {
                for application in profile.applicationActivation.enabledApplications {
                    assignments[application.bundleIdentifier] = Assignment(
                        profileID: profile.id,
                        enablesRemapping: profile.applicationActivation.enablesRemapping
                    )
                }
            }
        } catch {
            assignments.removeAll()
        }
        needsRefresh = true
    }

    func applyForegroundRemappingPolicy() {
        let assignment = lastBundleIdentifier.flatMap { assignments[$0] }
        applyRemappingOverride(
            lastBundleIdentifier,
            assignment?.enablesRemapping == true ? true : nil,
            assignment != nil
        )
    }

    func foregroundApplicationDidActivate(bundleIdentifier: String?, hasTemporaryProfile: Bool = false) {
        // Home and the popover control the last external app, including apps
        // without an assigned profile that allow temporary manual remapping.
        let showingInterface = interfaceBundleIdentifier != nil && bundleIdentifier == interfaceBundleIdentifier
        let foregroundID = showingInterface ? lastBundleIdentifier : bundleIdentifier
        let appChanged = lastBundleIdentifier != foregroundID
        guard needsRefresh || appChanged else { return }

        lastBundleIdentifier = foregroundID
        needsRefresh = false
        let assignment = foregroundID.flatMap { assignments[$0] }

        do {
            let retainsTemporaryProfile = hasTemporaryProfile && !appChanged && assignment != nil
            if hasTemporaryProfile && !retainsTemporaryProfile {
                try restoreTemporaryProfile()
            }
            if let assignment, !retainsTemporaryProfile {
                try activateProfile(assignment.profileID)
            }
            applyForegroundRemappingPolicy()
        } catch {
            // Never enable rules from a different profile after a failed switch.
            applyRemappingOverride(foregroundID, false, assignment != nil)
            reportFailure(assignment?.profileID, error)
        }
    }
}
