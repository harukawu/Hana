//
//  MiningHistoryCoordinator.swift
//  Hana
//
//  Created by Haruka on 2026/7/27.
//

import Foundation
import HoshiReader
import Observation
import SwiftData

@MainActor
@Observable
final class MiningHistoryCoordinator {
    var isPendingAlertPresented = false
    var isErrorAlertPresented = false
    private(set) var unavailableHistoryID: UUID?
    private(set) var errorMessage = ""

    @ObservationIgnored private var isProcessing = false

    private enum StartTarget {
        case next
        case pending
        case history(UUID)
    }

    func startNext(in modelContext: ModelContext) {
        scheduleStart(.next, in: modelContext)
    }

    func retryPending(in modelContext: ModelContext) {
        isPendingAlertPresented = false
        scheduleStart(.pending, in: modelContext)
    }

    func retryUnavailable(in modelContext: ModelContext) {
        guard let unavailableHistoryID else { return }
        dismissError()
        scheduleStart(.history(unavailableHistoryID), in: modelContext)
    }

    func receiveAnkiSuccess(in modelContext: ModelContext) {
        // A callback cannot legitimately belong to a new handoff that has not
        // finished opening AnkiMobile. Ignore duplicate or stale callbacks that
        // arrive while the serialized transition is still running.
        guard !isProcessing else { return }
        isProcessing = true
        Task { @MainActor in
            await acknowledgePendingAndContinue(in: modelContext)
            isProcessing = false
        }
    }

    func deletePending(in modelContext: ModelContext) {
        guard !isProcessing else { return }
        do {
            guard let pendingHistory = try firstHistory(with: .pending, in: modelContext) else {
                isPendingAlertPresented = false
                return
            }
            modelContext.delete(pendingHistory)
            try modelContext.save()
            isPendingAlertPresented = false
        } catch {
            presentError(error)
        }
    }

    func deleteUnavailable(in modelContext: ModelContext) {
        guard !isProcessing, let unavailableHistoryID else { return }
        do {
            if let history = try findHistory(with: unavailableHistoryID, in: modelContext) {
                modelContext.delete(history)
                try modelContext.save()
            }
            dismissError()
        } catch {
            presentError(error, historyID: unavailableHistoryID)
        }
    }

    func deleteAll(in modelContext: ModelContext) {
        guard !isProcessing else { return }
        do {
            try modelContext.delete(model: MiningHistory.self)
            try modelContext.save()
            isPendingAlertPresented = false
            dismissError()
        } catch {
            presentError(error)
        }
    }

    func dismissError() {
        isErrorAlertPresented = false
        unavailableHistoryID = nil
        errorMessage = ""
    }

    private func scheduleStart(_ target: StartTarget, in modelContext: ModelContext) {
        guard !isProcessing else { return }
        isProcessing = true
        Task { @MainActor in
            await send(target, in: modelContext)
            isProcessing = false
        }
    }

    private func send(_ target: StartTarget, in modelContext: ModelContext) async {
        let history: MiningHistory
        do {
            switch target {
            case .next:
                if try firstHistory(with: .pending, in: modelContext) != nil {
                    isPendingAlertPresented = true
                    return
                }
                guard let queuedHistory = try firstHistory(with: .queued, in: modelContext) else {
                    if let failedHistory = try firstHistory(with: .failed, in: modelContext) {
                        presentError(
                            MiningHistoryCoordinatorError.previouslyFailed,
                            historyID: failedHistory.id
                        )
                    }
                    return
                }
                history = queuedHistory
            case .pending:
                guard let pendingHistory = try firstHistory(with: .pending, in: modelContext) else {
                    isPendingAlertPresented = false
                    return
                }
                history = pendingHistory
            case .history(let id):
                guard let requestedHistory = try findHistory(with: id, in: modelContext) else {
                    dismissError()
                    return
                }
                if let pendingHistory = try firstHistory(with: .pending, in: modelContext),
                   pendingHistory.id != requestedHistory.id {
                    isPendingAlertPresented = true
                    return
                }
                history = requestedHistory
            }
        } catch {
            presentError(error)
            return
        }

        let noteData: MiningHistorySendData
        do {
            noteData = try history.toTuple()
        } catch {
            markFailed(history, error: error, in: modelContext)
            return
        }
        defer {
            try? FileManager.default.removeItem(at: noteData.imageURL)
        }

        let previousStatus = history.status
        let previousAttemptDate = history.lastAttemptAt
        history.status = .pending
        history.lastAttemptAt = .now
        do {
            try modelContext.save()
        } catch {
            history.status = previousStatus
            history.lastAttemptAt = previousAttemptDate
            presentError(error, historyID: history.id)
            return
        }

        let addedSynchronously = await HoshiAnkiManager.shared.addNote(from: noteData)
        if addedSynchronously {
            await acknowledgePendingAndContinue(in: modelContext)
        }
    }

    private func acknowledgePendingAndContinue(in modelContext: ModelContext) async {
        do {
            guard let pendingHistory = try firstHistory(with: .pending, in: modelContext) else {
                return
            }
            modelContext.delete(pendingHistory)
            try modelContext.save()
            isPendingAlertPresented = false
            await send(.next, in: modelContext)
        } catch {
            presentError(error)
        }
    }

    private func markFailed(
        _ history: MiningHistory,
        error originalError: Error,
        in modelContext: ModelContext
    ) {
        history.status = .failed
        do {
            try modelContext.save()
            presentError(originalError, historyID: history.id)
        } catch let persistenceError {
            presentError(
                MiningHistoryCoordinatorError.couldNotPersistFailure(
                    original: originalError.localizedDescription,
                    persistence: persistenceError.localizedDescription
                ),
                historyID: history.id
            )
        }
    }

    private func presentError(_ error: Error, historyID: UUID? = nil) {
        isPendingAlertPresented = false
        unavailableHistoryID = historyID
        errorMessage = error.localizedDescription
        isErrorAlertPresented = true
    }

    private func firstHistory(
        with status: MiningHistoryStatus,
        in modelContext: ModelContext
    ) throws -> MiningHistory? {
        try modelContext.fetch(FetchDescriptor<MiningHistory>())
            .filter { $0.status == status }
            .min { first, second in
                if first.createdAt == second.createdAt {
                    return first.id.uuidString < second.id.uuidString
                }
                return first.createdAt < second.createdAt
            }
    }

    private func findHistory(
        with id: UUID,
        in modelContext: ModelContext
    ) throws -> MiningHistory? {
        let requestedID = id
        let predicate = #Predicate<MiningHistory> { history in
            history.id == requestedID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

private enum MiningHistoryCoordinatorError: LocalizedError {
    case previouslyFailed
    case couldNotPersistFailure(original: String, persistence: String)

    var errorDescription: String? {
        switch self {
        case .previouslyFailed:
            "A mining history failed previously. Retry it or delete it before continuing."
        case .couldNotPersistFailure(let original, let persistence):
            "The mining history failed: \(original). Its failed state could not be saved: \(persistence)"
        }
    }
}
