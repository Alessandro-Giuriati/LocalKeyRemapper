//
//  RevisionBoundValueCache.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 8/4/26.
//

import Foundation

/// Stores one derived value together with the revisions that produced it.
///
/// The cache is intentionally small and deterministic: it never observes or
/// retains the source objects. Its owner supplies lightweight revision numbers
/// and explicitly invalidates the value when switching to another data source.
nonisolated struct RevisionBoundValueCache<Value> {
    private struct Key: Equatable {
        let contentRevision:
            UInt64

        let dependencyRevision:
            UInt64
    }

    private var entry:
        (
            key: Key,
            value: Value
        )?

    /// Returns the stored value only when both revisions still match.
    func cachedValue(
        contentRevision:
            UInt64,
        dependencyRevision:
            UInt64 = 0
    ) -> Value? {
        let requestedKey =
            Key(
                contentRevision:
                    contentRevision,
                dependencyRevision:
                    dependencyRevision
            )

        guard
            let entry,
            entry.key == requestedKey
        else {
            return nil
        }

        return entry.value
    }

    /// Replaces the previous entry with the value for the supplied revisions.
    mutating func store(
        _ value:
            Value,
        contentRevision:
            UInt64,
        dependencyRevision:
            UInt64 = 0
    ) {
        entry =
            (
                key:
                    Key(
                        contentRevision:
                            contentRevision,
                        dependencyRevision:
                            dependencyRevision
                    ),
                value:
                    value
            )
    }

    /// Releases the stored value immediately.
    mutating func invalidate() {
        entry =
            nil
    }
}
