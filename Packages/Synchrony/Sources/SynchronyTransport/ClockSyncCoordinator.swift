/// Runs the ping/pong exchange described in ADR-0004 and turns the
/// resulting samples into a clock offset and a connection-quality reading.
/// The peer that needs to translate the host's scheduled instants into its
/// own clock is the one that calls `synchronize()`; the host just needs to
/// echo back any ping it receives (see `GameCoordinator`).
///
/// This does *not* read `GameTransport.incomingMessages` itself: an
/// `AsyncStream` only has one real consumer, and the owner already needs
/// its own loop over that stream to handle every other `GameMessage` case.
/// Instead, the owner forwards `.clockSyncPong` messages in via
/// `receive(_:)` as they arrive.
public actor ClockSyncCoordinator {
    public enum SyncError: Error, Equatable, Sendable {
        case noSamplesCollected
    }

    public struct Result: Equatable, Sendable {
        public let offsetNanos: Int64
        public let quality: ConnectionQuality
    }

    private let transport: any GameTransport
    private let origin: ContinuousClock.Instant
    private let sampleCount: Int
    private let clock = ContinuousClock()

    private let pongMessages: AsyncStream<GameMessage>
    private let pongContinuation: AsyncStream<GameMessage>.Continuation

    public init(transport: any GameTransport, origin: ContinuousClock.Instant, sampleCount: Int = 8) {
        self.transport = transport
        self.origin = origin
        self.sampleCount = sampleCount

        // swiftlint:disable:next implicitly_unwrapped_optional
        var continuation: AsyncStream<GameMessage>.Continuation!
        self.pongMessages = AsyncStream { continuation = $0 }
        self.pongContinuation = continuation
    }

    /// Forwards a `.clockSyncPong` seen on the shared message loop. Any
    /// other message is ignored.
    public func receive(_ message: GameMessage) {
        guard case .clockSyncPong = message else { return }
        pongContinuation.yield(message)
    }

    /// Sends `sampleCount` pings one at a time, waiting for each matching
    /// pong before sending the next. There's no per-ping timeout: this
    /// runs inside a `Task` the caller can cancel (leaving the pairing
    /// screen cancels it), which is this project's answer to "what if a
    /// pong never arrives" for now.
    public func synchronize() async throws -> Result {
        var iterator = pongMessages.makeAsyncIterator()
        var samples: [ClockSyncSample] = []

        for sequence in 0..<sampleCount {
            let sendNanos = MonotonicTime.nanoseconds(from: origin, to: clock.now)
            try await transport.send(.clockSyncPing(sequence: sequence, sentAtNanos: sendNanos))

            while let message = await iterator.next() {
                guard case .clockSyncPong(let pongSequence, _, let remoteReplyNanos) = message, pongSequence == sequence
                else { continue }
                let receiveNanos = MonotonicTime.nanoseconds(from: origin, to: clock.now)
                samples.append(
                    ClockSyncSample(
                        localSendNanos: sendNanos,
                        localReceiveNanos: receiveNanos,
                        remoteReplyNanos: remoteReplyNanos
                    )
                )
                break
            }
        }

        guard !samples.isEmpty else { throw SyncError.noSamplesCollected }

        let offset = try ClockOffsetEstimator.estimateOffsetNanos(from: samples)
        let variance = ClockOffsetEstimator.roundTripVarianceNanos(of: samples)
        return Result(offsetNanos: offset, quality: ConnectionQuality.classify(roundTripVarianceNanos: variance))
    }
}
