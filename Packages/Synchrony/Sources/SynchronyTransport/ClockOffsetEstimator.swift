/// One ping/pong round trip, in the local device's own nanosecond clock
/// except for `remoteReplyNanos`, which is the peer's clock reading — all
/// three values come from `ContinuousClock`/`DispatchTime`-derived
/// durations, never `Date`, since `Date` can jump (NTP sync, DST, manual
/// clock changes) mid-match.
public struct ClockSyncSample: Equatable, Sendable {
    /// t0: local clock when the ping was sent.
    public let localSendNanos: Int64
    /// t3: local clock when the pong was received.
    public let localReceiveNanos: Int64
    /// t2: the peer's own clock when it sent the pong.
    public let remoteReplyNanos: Int64

    public init(localSendNanos: Int64, localReceiveNanos: Int64, remoteReplyNanos: Int64) {
        self.localSendNanos = localSendNanos
        self.localReceiveNanos = localReceiveNanos
        self.remoteReplyNanos = remoteReplyNanos
    }

    public var roundTripNanos: Int64 {
        localReceiveNanos - localSendNanos
    }

    /// Estimated `peerClock - localClock`, assuming the ping and pong each
    /// took half the round trip — the standard simplifying assumption for
    /// P2P links where a full four-timestamp NTP exchange isn't available.
    public var estimatedOffsetNanos: Int64 {
        remoteReplyNanos - (localSendNanos + roundTripNanos / 2)
    }
}

/// Turns a batch of ping/pong samples into a single clock offset estimate,
/// per the sync mechanism in ADR-0004: discard the samples with the
/// highest round-trip time (latency spikes make for the least trustworthy
/// offset estimates), then take the median of what's left.
public enum ClockOffsetEstimator: Sendable {

    public enum EstimationError: Error, Equatable, Sendable {
        case noSamples
    }

    public static func estimateOffsetNanos(
        from samples: [ClockSyncSample],
        discardingSlowestFraction fraction: Double = 0.25
    ) throws -> Int64 {
        guard !samples.isEmpty else { throw EstimationError.noSamples }

        let sortedByRoundTrip = samples.sorted { $0.roundTripNanos < $1.roundTripNanos }
        let keepCount = max(1, Int(Double(sortedByRoundTrip.count) * (1 - fraction)))
        let kept = sortedByRoundTrip.prefix(keepCount)

        let offsets = kept.map(\.estimatedOffsetNanos).sorted()
        return median(of: offsets)
    }

    /// Variance of round-trip times, in nanoseconds² — a cheap jitter
    /// signal for `ConnectionQuality.classify(roundTripVarianceNanos:)`.
    public static func roundTripVarianceNanos(of samples: [ClockSyncSample]) -> Double {
        guard samples.count > 1 else { return 0 }
        let roundTrips = samples.map { Double($0.roundTripNanos) }
        let mean = roundTrips.reduce(0, +) / Double(roundTrips.count)
        let squaredDifferences = roundTrips.map { ($0 - mean) * ($0 - mean) }
        return squaredDifferences.reduce(0, +) / Double(roundTrips.count)
    }

    private static func median(of sortedValues: [Int64]) -> Int64 {
        let count = sortedValues.count
        if count.isMultiple(of: 2) {
            return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2
        }
        return sortedValues[count / 2]
    }
}

/// A rough read on link stability, derived from round-trip jitter. The UI
/// shows a degraded indicator and the sync engine widens its reveal margin
/// when this reports `.degraded` — see ADR-0004.
public enum ConnectionQuality: Equatable, Sendable {
    case good
    case degraded

    /// Threshold: 50ms² of round-trip variance (~7ms standard deviation).
    /// Chosen generously — Wi-Fi/Bluetooth P2P jitter on iOS commonly sits
    /// in the low milliseconds even on a healthy link, so this is meant to
    /// catch genuinely unstable connections, not normal noise.
    public static func classify(roundTripVarianceNanos variance: Double) -> Self {
        let varianceInMillisecondsSquared = variance / 1_000_000_000_000
        return varianceInMillisecondsSquared > 50 ? .degraded : .good
    }
}
