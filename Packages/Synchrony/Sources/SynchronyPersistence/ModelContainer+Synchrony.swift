import SwiftData

extension ModelContainer {
    /// The schema shared by the real on-disk store, tests, and SwiftUI
    /// previews — `inMemory: true` for the latter two, so nothing they do
    /// touches a player's actual history.
    public static func makeSynchronyContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: MatchRecord.self, RoundRecord.self, configurations: configuration)
    }
}
