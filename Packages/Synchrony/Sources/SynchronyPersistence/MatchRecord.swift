import Foundation
import SwiftData

/// A completed match, persisted locally. Deliberately separate from
/// `SynchronyCore.Match`: that type is the live, in-progress domain model;
/// this is what's left of it once the match is over and worth keeping —
/// no in-flight state, no answers, just enough to show history and compute
/// stats over time.
@Model
public final class MatchRecord {
    @Attribute(.unique) public var id: String
    public var playedAt: Date
    public var roundCount: Int
    public var syncedRoundCount: Int
    public var syncPercentage: Double

    @Relationship(deleteRule: .cascade)
    public var rounds: [RoundRecord]

    public init(
        id: String,
        playedAt: Date,
        roundCount: Int,
        syncedRoundCount: Int,
        syncPercentage: Double,
        rounds: [RoundRecord] = []
    ) {
        self.id = id
        self.playedAt = playedAt
        self.roundCount = roundCount
        self.syncedRoundCount = syncedRoundCount
        self.syncPercentage = syncPercentage
        self.rounds = rounds
    }
}
