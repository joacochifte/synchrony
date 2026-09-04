import Foundation
import SwiftData

/// Local persistence for match history.
///
/// Holds the `ModelContainer` itself, not just a `ModelContext` — a
/// `ModelContext` doesn't keep its owning container alive, so a caller
/// that builds one from a locally-scoped container and discards the
/// container (`MatchHistoryRepository(context: container.mainContext)`,
/// with `container` never stored anywhere) ends up with a context backed
/// by an already-deallocated store. Long-running async code gives ARC
/// plenty of chances to actually collect that orphaned container well
/// before the context gets used, which crashes deep inside SwiftData with
/// no useful message. Storing the container and deriving `mainContext`
/// from it here instead ties its lifetime to the repository's.
@MainActor
public struct MatchHistoryRepository {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    private var context: ModelContext {
        container.mainContext
    }

    public func save(_ record: MatchRecord) throws {
        for round in record.rounds {
            context.insert(round)
        }
        context.insert(record)
        try context.save()
    }

    public func fetchAll(mostRecentFirst: Bool = true) throws -> [MatchRecord] {
        let order: SortOrder = mostRecentFirst ? .reverse : .forward
        let descriptor = FetchDescriptor<MatchRecord>(sortBy: [SortDescriptor(\.playedAt, order: order)])
        return try context.fetch(descriptor)
    }

    public func delete(_ record: MatchRecord) throws {
        context.delete(record)
        try context.save()
    }
}
