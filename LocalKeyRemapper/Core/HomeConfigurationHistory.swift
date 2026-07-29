//
//  HomeConfigurationHistory.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

/// Stores session-only Undo and Redo entries for the Home editor.
///
/// The history is never encoded, persisted, logged, or written to disk.
nonisolated final class HomeConfigurationHistory {
    static let defaultMaximumEntryCount =
        5_000

    static let defaultMaximumEstimatedPayloadSize =
        1_500_000

    private struct Entry:
        Equatable
    {
        let sequenceNumber:
            UInt64

        let action:
            HomeConfigurationAction

        var estimatedPayloadSize:
            Int
        {
            action.estimatedPayloadSize
        }
    }

    private let maximumEntryCount:
        Int

    private let maximumEstimatedPayloadSize:
        Int

    private var undoEntries:
        [Entry] = []

    private var redoEntries:
        [Entry] = []

    private var nextSequenceNumber:
        UInt64 = 0

    private(set) var totalEstimatedPayloadSize =
        0

    init(
        maximumEntryCount:
            Int =
                HomeConfigurationHistory
                    .defaultMaximumEntryCount,
        maximumEstimatedPayloadSize:
            Int =
                HomeConfigurationHistory
                    .defaultMaximumEstimatedPayloadSize
    ) {
        self.maximumEntryCount =
            max(
                maximumEntryCount,
                0
            )

        self.maximumEstimatedPayloadSize =
            max(
                maximumEstimatedPayloadSize,
                0
            )
    }

    var canUndo:
        Bool
    {
        !undoEntries.isEmpty
    }

    var canRedo:
        Bool
    {
        !redoEntries.isEmpty
    }

    var undoEntryCount:
        Int
    {
        undoEntries.count
    }

    var redoEntryCount:
        Int
    {
        redoEntries.count
    }

    var totalEntryCount:
        Int
    {
        undoEntries.count
            + redoEntries.count
    }

    /// Records a new user edit and invalidates the previous Redo branch.
    func record(
        _ action:
            HomeConfigurationAction
    ) {
        removeAllRedoEntries()

        let entry =
            Entry(
                sequenceNumber:
                    nextSequenceNumber,
                action:
                    action
            )

        nextSequenceNumber &+=
            1

        undoEntries.append(
            entry
        )

        totalEstimatedPayloadSize +=
            entry.estimatedPayloadSize

        trimOldestEntriesIfNeeded()
    }

    /// Moves the newest Undo entry to Redo and returns its action.
    func takeUndoAction()
        -> HomeConfigurationAction?
    {
        guard
            let entry =
                undoEntries
                    .popLast()
        else {
            return nil
        }

        redoEntries.append(
            entry
        )

        return entry.action
    }

    /// Moves the newest Redo entry back to Undo and returns its action.
    func takeRedoAction()
        -> HomeConfigurationAction?
    {
        guard
            let entry =
                redoEntries
                    .popLast()
        else {
            return nil
        }

        undoEntries.append(
            entry
        )

        return entry.action
    }

    func clear() {
        undoEntries.removeAll()
        redoEntries.removeAll()

        totalEstimatedPayloadSize =
            0

        nextSequenceNumber =
            0
    }

    private func removeAllRedoEntries() {
        for entry in redoEntries {
            totalEstimatedPayloadSize -=
                entry.estimatedPayloadSize
        }

        redoEntries.removeAll()
    }

    private func trimOldestEntriesIfNeeded() {
        while
            totalEntryCount
                > maximumEntryCount
                || totalEstimatedPayloadSize
                    > maximumEstimatedPayloadSize
        {
            guard
                removeOldestEntry()
            else {
                break
            }
        }
    }

    @discardableResult
    private func removeOldestEntry()
        -> Bool
    {
        let oldestUndoIndex =
            undoEntries.indices.min {
                undoEntries[$0]
                    .sequenceNumber
                    < undoEntries[$1]
                        .sequenceNumber
            }

        let oldestRedoIndex =
            redoEntries.indices.min {
                redoEntries[$0]
                    .sequenceNumber
                    < redoEntries[$1]
                        .sequenceNumber
            }

        switch (
            oldestUndoIndex,
            oldestRedoIndex
        ) {
        case (
            .none,
            .none
        ):
            return false

        case (
            .some(
                let undoIndex
            ),
            .none
        ):
            removeUndoEntry(
                at:
                    undoIndex
            )

        case (
            .none,
            .some(
                let redoIndex
            )
        ):
            removeRedoEntry(
                at:
                    redoIndex
            )

        case (
            .some(
                let undoIndex
            ),
            .some(
                let redoIndex
            )
        ):
            if undoEntries[
                undoIndex
            ]
                .sequenceNumber
                <= redoEntries[
                    redoIndex
                ]
                    .sequenceNumber
            {
                removeUndoEntry(
                    at:
                        undoIndex
                )
            } else {
                removeRedoEntry(
                    at:
                        redoIndex
                )
            }
        }

        return true
    }

    private func removeUndoEntry(
        at index:
            Int
    ) {
        let removedEntry =
            undoEntries.remove(
                at:
                    index
            )

        totalEstimatedPayloadSize -=
            removedEntry.estimatedPayloadSize
    }

    private func removeRedoEntry(
        at index:
            Int
    ) {
        let removedEntry =
            redoEntries.remove(
                at:
                    index
            )

        totalEstimatedPayloadSize -=
            removedEntry.estimatedPayloadSize
    }
}
