import Foundation
import Testing

@testable import SynchronyPersistence

@Suite struct MatchHistoryStatisticsTests {

    private func record(daysAgo: Double, syncPercentage: Double) -> MatchRecord {
        MatchRecord(
            id: UUID().uuidString,
            playedAt: Date(timeIntervalSinceNow: -daysAgo * 86_400),
            roundCount: 10,
            syncedRoundCount: Int(syncPercentage / 10),
            syncPercentage: syncPercentage
        )
    }

    @Test func emptyHistoryReportsZeroMatchesAndNoTrend() {
        let stats = MatchHistoryStatistics.compute(from: [])
        #expect(stats.matchCount == 0)
        #expect(stats.averageSyncPercentage == 0)
        #expect(stats.bestSyncPercentage == nil)
        #expect(stats.recentTrend == .notEnoughData)
    }

    @Test func averageAndBestAcrossMultipleMatches() {
        let records = [
            record(daysAgo: 2, syncPercentage: 40),
            record(daysAgo: 1, syncPercentage: 80),
            record(daysAgo: 0, syncPercentage: 60),
        ]
        let stats = MatchHistoryStatistics.compute(from: records)
        #expect(stats.matchCount == 3)
        #expect(stats.averageSyncPercentage == 60)
        #expect(stats.bestSyncPercentage == 80)
    }

    @Test func fewerThanTwiceTheWindowReportsNotEnoughData() {
        let records = (0..<6).map { record(daysAgo: Double($0), syncPercentage: 50) }
        let stats = MatchHistoryStatistics.compute(from: records, recentWindow: 5)
        #expect(stats.recentTrend == .notEnoughData)
    }

    @Test func improvingTrendWhenRecentMatchesScoreHigher() {
        // Oldest 3 at 40%, most recent 3 at 80% — a clear improvement.
        var records = (0..<3).map { record(daysAgo: Double(5 + $0), syncPercentage: 40) }
        records += (0..<3).map { record(daysAgo: Double($0), syncPercentage: 80) }

        let stats = MatchHistoryStatistics.compute(from: records, recentWindow: 3)
        #expect(stats.recentTrend == .improving)
    }

    @Test func decliningTrendWhenRecentMatchesScoreLower() {
        var records = (0..<3).map { record(daysAgo: Double(5 + $0), syncPercentage: 80) }
        records += (0..<3).map { record(daysAgo: Double($0), syncPercentage: 40) }

        let stats = MatchHistoryStatistics.compute(from: records, recentWindow: 3)
        #expect(stats.recentTrend == .declining)
    }

    @Test func steadyTrendWhenDifferenceIsWithinNoiseThreshold() {
        var records = (0..<3).map { record(daysAgo: Double(5 + $0), syncPercentage: 60) }
        records += (0..<3).map { record(daysAgo: Double($0), syncPercentage: 61) }

        let stats = MatchHistoryStatistics.compute(from: records, recentWindow: 3)
        #expect(stats.recentTrend == .steady)
    }
}
