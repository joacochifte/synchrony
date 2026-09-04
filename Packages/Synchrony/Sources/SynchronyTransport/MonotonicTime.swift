/// Converts `ContinuousClock` durations to plain `Int64` nanoseconds, the
/// wire representation `GameMessage`'s clock-related fields use (see
/// ADR-0004). Every timestamp is relative to some origin instant a caller
/// picks once and reuses — there's no shared epoch between two devices,
/// only a translation constant (the estimated offset) between their two
/// arbitrary origins.
public enum MonotonicTime: Sendable {
    public static func nanoseconds(from origin: ContinuousClock.Instant, to instant: ContinuousClock.Instant) -> Int64 {
        let (seconds, attoseconds) = origin.duration(to: instant).components
        return seconds * 1_000_000_000 + attoseconds / 1_000_000_000
    }
}
