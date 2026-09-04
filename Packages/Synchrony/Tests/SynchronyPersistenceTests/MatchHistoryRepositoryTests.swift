import Foundation
import SwiftData
import Testing

@testable import SynchronyPersistence

@MainActor
@Suite struct MatchHistoryRepositoryTests {

    private func makeRepository() throws -> MatchHistoryRepository {
        let container = try ModelContainer.makeSynchronyContainer(inMemory: true)
        return MatchHistoryRepository(context: ModelContext(container))
    }

    @Test func savingAndFetchingReturnsTheRecord() throws {
        let repository = try makeRepository()
        let record = MatchRecord(id: "m1", playedAt: .now, roundCount: 2, syncedRoundCount: 1, syncPercentage: 50)

        try repository.save(record)
        let fetched = try repository.fetchAll()

        #expect(fetched.count == 1)
        #expect(fetched.first?.id == "m1")
    }

    @Test func fetchAllDefaultsToMostRecentFirst() throws {
        let repository = try makeRepository()
        let older = MatchRecord(
            id: "older",
            playedAt: Date(timeIntervalSince1970: 0),
            roundCount: 1,
            syncedRoundCount: 1,
            syncPercentage: 100
        )
        let newer = MatchRecord(
            id: "newer",
            playedAt: Date(timeIntervalSince1970: 1_000),
            roundCount: 1,
            syncedRoundCount: 0,
            syncPercentage: 0
        )

        try repository.save(older)
        try repository.save(newer)

        let fetched = try repository.fetchAll()
        #expect(fetched.map(\.id) == ["newer", "older"])
    }

    @Test func fetchAllCanReturnOldestFirst() throws {
        let repository = try makeRepository()
        let older = MatchRecord(
            id: "older",
            playedAt: Date(timeIntervalSince1970: 0),
            roundCount: 1,
            syncedRoundCount: 1,
            syncPercentage: 100
        )
        let newer = MatchRecord(
            id: "newer",
            playedAt: Date(timeIntervalSince1970: 1_000),
            roundCount: 1,
            syncedRoundCount: 0,
            syncPercentage: 0
        )

        try repository.save(older)
        try repository.save(newer)

        let fetched = try repository.fetchAll(mostRecentFirst: false)
        #expect(fetched.map(\.id) == ["older", "newer"])
    }

    @Test func deleteRemovesTheRecord() throws {
        let repository = try makeRepository()
        let record = MatchRecord(id: "m1", playedAt: .now, roundCount: 1, syncedRoundCount: 1, syncPercentage: 100)
        try repository.save(record)

        try repository.delete(record)

        #expect(try repository.fetchAll().isEmpty)
    }

    @Test func savingCascadesRoundsThroughTheRelationship() throws {
        let repository = try makeRepository()
        let rounds = [
            RoundRecord(promptID: "p1", promptText: "¿Cuánto?", wasSynchronized: true),
            RoundRecord(promptID: "p2", promptText: "¿Playa o montaña?", wasSynchronized: false),
        ]
        let record = MatchRecord(
            id: "m1", playedAt: .now, roundCount: 2, syncedRoundCount: 1, syncPercentage: 50, rounds: rounds)

        try repository.save(record)

        let fetched = try repository.fetchAll().first
        #expect(fetched?.rounds.count == 2)
    }
}
