/// Aggregate sync stats across a couple's match history.
public struct MatchHistoryStatistics: Equatable, Sendable {
    public enum Trend: Equatable, Sendable {
        case improving
        case declining
        case steady
        /// Not enough matches yet to say anything meaningful about a trend.
        case notEnoughData
    }

    public let matchCount: Int
    public let averageSyncPercentage: Double
    public let bestSyncPercentage: Double?
    public let recentTrend: Trend

    /// - Parameter recentWindow: how many of the most recent matches count
    ///   as "recent" when comparing against the matches before them to
    ///   determine the trend. Needs at least `recentWindow * 2` matches
    ///   total, or the trend is `.notEnoughData` — comparing 2 matches
    ///   against 1 isn't a trend, it's noise.
    public static func compute(from records: [MatchRecord], recentWindow: Int = 5) -> Self {
        guard !records.isEmpty else {
            return Self(
                matchCount: 0, averageSyncPercentage: 0, bestSyncPercentage: nil, recentTrend: .notEnoughData)
        }

        let percentagesByDate = records.sorted { $0.playedAt < $1.playedAt }.map(\.syncPercentage)

        return Self(
            matchCount: records.count,
            averageSyncPercentage: percentagesByDate.reduce(0, +) / Double(percentagesByDate.count),
            bestSyncPercentage: percentagesByDate.max(),
            recentTrend: trend(fromChronological: percentagesByDate, recentWindow: recentWindow)
        )
    }

    /// Compares the average of the most recent `recentWindow` matches
    /// against the `recentWindow` before them. A 2-point difference is
    /// treated as noise rather than a real trend.
    private static func trend(fromChronological percentages: [Double], recentWindow: Int) -> Trend {
        guard recentWindow > 0, percentages.count >= recentWindow * 2 else { return .notEnoughData }

        let recent = percentages.suffix(recentWindow)
        let previous = percentages.dropLast(recentWindow).suffix(recentWindow)
        let recentAverage = recent.reduce(0, +) / Double(recent.count)
        let previousAverage = previous.reduce(0, +) / Double(previous.count)

        let noiseThreshold = 2.0
        let delta = recentAverage - previousAverage
        if delta > noiseThreshold { return .improving }
        if delta < -noiseThreshold { return .declining }
        return .steady
    }
}
