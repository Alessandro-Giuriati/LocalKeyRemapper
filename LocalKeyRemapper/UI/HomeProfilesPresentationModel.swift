//
//  HomeProfilesPresentationModel.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import Foundation

/// Owns presentation-only filtering and sorting for the Home profiles table.
///
/// This model never mutates the persisted profile collection, never changes the
/// active profile, and never participates in Home Undo/Redo history.
nonisolated struct HomeProfilesPresentationModel:
    Equatable
{
    enum SortKey:
        Equatable
    {
        case name
        case creationDate
    }

    enum SortDirection:
        Equatable
    {
        case ascending
        case descending
    }

    var searchText = ""
    var sortKey: SortKey = .name
    var sortDirection: SortDirection = .ascending

    /// Returns the visible profiles without modifying their persistent order.
    func visibleProfiles(
        from profiles: [RemappingProfile]
    ) -> [RemappingProfile] {
        let filteredProfiles =
            profiles.filter {
                profile in

                guard !searchText.isEmpty else {
                    return true
                }

                return profile.name.range(
                    of:
                        searchText,
                    options: [
                        .caseInsensitive,
                        .diacriticInsensitive
                    ],
                    range:
                        nil,
                    locale:
                        .current
                ) != nil
            }

        return filteredProfiles.sorted {
            lhs,
            rhs in

            let comparison =
                compare(
                    lhs,
                    rhs
                )

            switch sortDirection {
            case .ascending:
                return comparison == .orderedAscending

            case .descending:
                return comparison == .orderedDescending
            }
        }
    }

    /// Selects a new sort property or reverses the current direction.
    mutating func toggleSort(
        _ requestedKey: SortKey
    ) {
        if sortKey == requestedKey {
            sortDirection =
                sortDirection == .ascending
                    ? .descending
                    : .ascending
        } else {
            sortKey = requestedKey
            sortDirection = .ascending
        }
    }

    private func compare(
        _ lhs: RemappingProfile,
        _ rhs: RemappingProfile
    ) -> ComparisonResult {
        switch sortKey {
        case .name:
            return compareNames(
                lhs,
                rhs
            )

        case .creationDate:
            if lhs.createdAt < rhs.createdAt {
                return .orderedAscending
            }

            if lhs.createdAt > rhs.createdAt {
                return .orderedDescending
            }

            return compareNames(
                lhs,
                rhs
            )
        }
    }

    /// Produces deterministic ordering even when names differ only by case.
    private func compareNames(
        _ lhs: RemappingProfile,
        _ rhs: RemappingProfile
    ) -> ComparisonResult {
        let caseInsensitiveComparison =
            lhs.name.localizedCaseInsensitiveCompare(
                rhs.name
            )

        if caseInsensitiveComparison != .orderedSame {
            return caseInsensitiveComparison
        }

        let exactComparison =
            lhs.name.compare(
                rhs.name,
                options:
                    .literal
            )

        if exactComparison != .orderedSame {
            return exactComparison
        }

        return lhs.id.uuidString.compare(
            rhs.id.uuidString,
            options:
                .literal
        )
    }
}
