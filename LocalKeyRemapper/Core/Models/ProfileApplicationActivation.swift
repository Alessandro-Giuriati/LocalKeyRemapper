import Foundation

/// App identities only: no paths, bookmarks, application history, or key input.
nonisolated struct ProfileApplicationActivation: Codable, Equatable {
    var applications: [ForegroundApplicationScope.Application] = []
    var enablesRemapping = false

    static let disabled = Self()

    var enabledApplications: [ForegroundApplicationScope.Application] {
        applications.filter(\.isEnabled)
    }

    func adding(_ applications: [ForegroundApplicationScope.Application]) -> Self {
        var updated = self
        var identifiers = Set(updated.applications.map(\.bundleIdentifier))
        updated.applications.append(contentsOf: applications.filter {
            identifiers.insert($0.bundleIdentifier).inserted
        })
        return updated
    }

    /// Each foreground app may have at most one enabled profile assignment.
    static func validate(_ profiles: [RemappingProfile]) throws {
        if let error = validationErrors(for: profiles).first {
            throw error
        }
    }

    static func validationMessage(for profiles: [RemappingProfile], involving profileID: UUID? = nil) -> String? {
        let errors = validationErrors(for: profiles, involving: profileID)
        return errors.isEmpty ? nil : errors.map(\.localizedDescription).joined(separator: "\n")
    }

    private static func validationErrors(
        for profiles: [RemappingProfile], involving profileID: UUID? = nil
    ) -> [ValidationError] {
        let invalidApps = profiles.filter { profile in
            (profileID == nil || profile.id == profileID) && profile.applicationActivation.applications.contains {
                $0.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }.map { ValidationError.invalidApplication(profileName: $0.name) }
        return invalidApps + ProfileApplicationConflicts(profiles: profiles).duplicateErrors(involving: profileID)
    }

    enum ValidationError: Error, Equatable, LocalizedError {
        case invalidApplication(profileName: String)
        case conflictingProfiles(application: String, profiles: [String])

        var errorDescription: String? {
            switch self {
            case .invalidApplication(let name):
                return "Choose a valid application for “\(name)”."
            case .conflictingProfiles(let app, let profiles):
                let names = profiles.map { "“\($0)”" }.joined(separator: ", ")
                return "“\(app)” is enabled in \(profiles.count) profiles: \(names). Leave it enabled in only one profile before saving Home."
            }
        }
    }
}

/// App assignment issues derived from the Home draft for its three editors.
nonisolated struct ProfileApplicationConflicts {
    private struct Assignment {
        let appName: String
        var profiles: [UUID: String] = [:]
    }

    private let duplicates: [String: Assignment]
    private let globallyExcludedAppIDs: Set<String>

    init(profiles: [RemappingProfile] = [], scope: ForegroundApplicationScope = .unrestricted) {
        var assignments: [String: Assignment] = [:]
        for profile in profiles {
            for app in profile.applicationActivation.enabledApplications {
                assignments[app.bundleIdentifier, default: Assignment(appName: app.displayName)]
                    .profiles[profile.id] = profile.name
            }
        }
        duplicates = assignments.filter { $0.value.profiles.count > 1 }
        globallyExcludedAppIDs = Set(scope.excludedApplications.lazy.filter(\.isEnabled).map(\.bundleIdentifier))
    }

    func duplicateErrors(involving profileID: UUID?) -> [ProfileApplicationActivation.ValidationError] {
        duplicates.keys.sorted().compactMap { identifier in
            guard let assignment = duplicates[identifier] else { return nil }
            if let profileID, assignment.profiles[profileID] == nil { return nil }
            return .conflictingProfiles(application: assignment.appName, profiles: duplicateProfileNames(for: identifier))
        }
    }

    func duplicateProfileNames(for bundleIdentifier: String) -> [String] {
        duplicates[bundleIdentifier]?.profiles.values.sorted() ?? []
    }

    func conflictsWithGlobalScope(
        _ app: ForegroundApplicationScope.Application,
        in activation: ProfileApplicationActivation
    ) -> Bool {
        app.isEnabled && activation.enablesRemapping && globallyExcludedAppIDs.contains(app.bundleIdentifier)
    }

    func affects(_ activation: ProfileApplicationActivation) -> Bool {
        activation.enabledApplications.contains { app in
            duplicates[app.bundleIdentifier] != nil
                || conflictsWithGlobalScope(app, in: activation)
        }
    }

    func globalWarning(for profile: RemappingProfile) -> String? {
        let activation = profile.applicationActivation
        let blockedApps = activation.applications.filter {
            conflictsWithGlobalScope($0, in: activation)
        }
        guard !blockedApps.isEmpty else { return nil }
        let names = blockedApps.map(\.displayName).joined(separator: ", ")
        return "Active profile “\(profile.name)” requests automatic remapping for \(names). The global exclusion keeps remapping off."
    }
}
