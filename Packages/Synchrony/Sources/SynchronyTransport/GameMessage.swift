import SynchronyCore

/// The wire protocol version this build speaks. Bump on any breaking change
/// to `GameMessage`'s shape and check it in the handshake — a mismatch
/// means an old and a new build of the app trying to play together, which
/// should fail with a clear message rather than send garbage.
public enum ProtocolVersion {
    public static let current = 1
}

/// Every message that can cross a `GameTransport`.
///
/// Clock-related fields (`sentAtNanos`, `showAtNanos`, ...) are opaque
/// `Int64` nanosecond counts, not `Date` — a device only ever compares them
/// against its own `ContinuousClock` readings, never interprets them as
/// wall-clock time. The actual offset-estimation algorithm that fills these
/// in is Phase 6's job; this phase only fixes the message shapes it needs.
public enum GameMessage: Codable, Equatable, Sendable {
    /// Sent by whichever peer connects first, declaring the protocol
    /// version it speaks.
    case handshake(protocolVersion: Int)
    case handshakeAccepted
    case handshakeRejected(reason: String)

    /// Round-trip sampling for clock offset estimation.
    case clockSyncPing(sequence: Int, sentAtNanos: Int64)
    case clockSyncPong(sequence: Int, pingSentAtNanos: Int64, pongSentAtNanos: Int64)

    /// Shows `prompt` to both players at the same instant: `showAtNanos`,
    /// translated through each device's own clock-offset estimate.
    case roundStart(prompt: Prompt, showAtNanos: Int64)

    case answer(AnswerValue)

    /// Reveals both already-exchanged answers for the current round at the
    /// same instant, translated the same way as `roundStart`.
    case reveal(revealAtNanos: Int64)

    case matchEnd(syncPercentage: Double)
}
