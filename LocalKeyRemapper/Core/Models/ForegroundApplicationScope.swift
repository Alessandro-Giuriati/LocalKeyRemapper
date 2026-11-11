//
//  ForegroundApplicationScope.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 10/11/26.
//

import Foundation

/// Stores app override lists and the behavior for every unlisted app.
/// Drafts may overlap. Persistence validates that enabled entries are disjoint.
nonisolated struct ForegroundApplicationScope: Codable, Equatable {
    enum List: Equatable {
        case included
        case excluded
    }

    enum ValidationError: Error, Equatable, LocalizedError {
        case overlappingApplications([Application])

        var errorDescription: String? {
            switch self {
            case .overlappingApplications(let applications):
                let names = applications.map {
                    "\($0.displayName) (\($0.bundleIdentifier))"
                }.joined(separator: "\n")
                return "These apps are enabled in both lists. Turn each one off in one list before saving.\n\n\(names)"
            }
        }
    }

    /// Used to read the first persisted scope format.
    enum Mode: String, Codable {
        case allApplications
        case onlySelectedApplications
        case exceptSelectedApplications
    }

    struct Application: Codable, Equatable {
        let bundleIdentifier: String
        let displayName: String
        var isEnabled: Bool

        init(bundleIdentifier: String, displayName: String, isEnabled: Bool = true) {
            self.bundleIdentifier = bundleIdentifier
            self.displayName = displayName
            self.isEnabled = isEnabled
        }

        private enum CodingKeys: String, CodingKey {
            case bundleIdentifier
            case displayName
            case isEnabled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
            displayName = try container.decode(String.self, forKey: .displayName)
            isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        }
    }

    static let unrestricted = Self()

    var allowsOtherApplications: Bool
    var allowsManualActivationForOtherApplications: Bool
    var includedApplications: [Application]
    var excludedApplications: [Application]

    init(
        allowsOtherApplications: Bool = true,
        allowsManualActivationForOtherApplications: Bool = false,
        includedApplications: [Application] = [],
        excludedApplications: [Application] = []
    ) {
        self.allowsOtherApplications = allowsOtherApplications
        self.allowsManualActivationForOtherApplications = allowsManualActivationForOtherApplications
        self.includedApplications = includedApplications
        self.excludedApplications = excludedApplications
    }

    /// Preserves existing callers and the behavior of saved single-list scopes.
    init(mode: Mode, applications: [Application] = []) {
        self.init(
            allowsOtherApplications: mode != .onlySelectedApplications,
            includedApplications: mode == .onlySelectedApplications ? applications : [],
            excludedApplications: mode == .exceptSelectedApplications ? applications : []
        )
    }

    var observesForegroundApplication: Bool {
        includedApplications.contains(where: \.isEnabled)
            || excludedApplications.contains(where: \.isEnabled)
            || permitsTemporaryManualActivation
    }

    var permitsTemporaryManualActivation: Bool {
        !allowsOtherApplications && allowsManualActivationForOtherApplications
    }

    func permitsTemporaryManualActivation(in bundleIdentifier: String?) -> Bool {
        guard permitsTemporaryManualActivation, let bundleIdentifier else {
            return false
        }

        return !containsEnabledApplication(bundleIdentifier, in: .included)
            && !containsEnabledApplication(bundleIdentifier, in: .excluded)
    }

    func validate() throws {
        let includedIdentifiers = Set(includedApplications.lazy.filter(\.isEnabled).map(\.bundleIdentifier))
        let overlaps = excludedApplications.filter {
            $0.isEnabled && includedIdentifiers.contains($0.bundleIdentifier)
        }
        guard overlaps.isEmpty else {
            throw ValidationError.overlappingApplications(overlaps)
        }
    }

    var validationMessage: String? {
        do {
            try validate()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Adds a selection to the editable draft, including cross-list conflicts.
    func adding(_ applications: [Application], to list: List) -> Self {
        var updated = self
        var existing = list == .included ? includedApplications : excludedApplications
        var identifiers = Set(existing.map(\.bundleIdentifier))
        for application in applications where identifiers.insert(application.bundleIdentifier).inserted {
            existing.append(application)
        }

        switch list {
        case .included:
            updated.includedApplications = existing
        case .excluded:
            updated.excludedApplications = existing
        }

        return updated
    }

    /// Resolves the scope when the manual setting is enabled.
    func allowsRemapping(in bundleIdentifier: String?) -> Bool {
        remappingOverride(in: bundleIdentifier) ?? true
    }

    func containsEnabledApplication(_ bundleIdentifier: String?, in list: List) -> Bool {
        let applications = list == .included ? includedApplications : excludedApplications
        return applications.contains { $0.isEnabled && $0.bundleIdentifier == bundleIdentifier }
    }

    /// A nil override uses the user's manual setting for apps without an enabled entry.
    func remappingOverride(in bundleIdentifier: String?) -> Bool? {
        if containsEnabledApplication(bundleIdentifier, in: .excluded) {
            return false
        }

        if containsEnabledApplication(bundleIdentifier, in: .included) {
            return true
        }

        return allowsOtherApplications ? nil : false
    }

    private enum CodingKeys: String, CodingKey {
        case allowsOtherApplications
        case allowsManualActivationForOtherApplications
        case includedApplications
        case excludedApplications
        case mode
        case applications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.mode) {
            self.init(
                mode: try container.decode(Mode.self, forKey: .mode),
                applications: try container.decodeIfPresent([Application].self, forKey: .applications) ?? []
            )
            return
        }

        self.init(
            allowsOtherApplications: try container.decodeIfPresent(Bool.self, forKey: .allowsOtherApplications) ?? true,
            allowsManualActivationForOtherApplications: try container.decodeIfPresent(Bool.self, forKey: .allowsManualActivationForOtherApplications) ?? false,
            includedApplications: try container.decodeIfPresent([Application].self, forKey: .includedApplications) ?? [],
            excludedApplications: try container.decodeIfPresent([Application].self, forKey: .excludedApplications) ?? []
        )
        try validate()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(allowsOtherApplications, forKey: .allowsOtherApplications)
        try container.encode(allowsManualActivationForOtherApplications, forKey: .allowsManualActivationForOtherApplications)
        try container.encode(includedApplications, forKey: .includedApplications)
        try container.encode(excludedApplications, forKey: .excludedApplications)
    }
}
