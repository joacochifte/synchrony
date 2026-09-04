import Foundation
import SwiftData

/// Local persistence for match history. Wraps a `ModelContext` rather than
/// a `ModelContainer` so tests and previews can hand it an in-memory
/// context directly — see `ModelContainer.makeSynchronyContainer(inMemory:)`.
@MainActor
public struct MatchHistoryRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func save(_ record: MatchRecord) throws {
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
