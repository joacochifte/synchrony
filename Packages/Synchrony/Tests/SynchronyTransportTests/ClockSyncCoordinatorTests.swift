import Testing

@testable import SynchronyTransport

@Suite struct ClockSyncCoordinatorTests {

    @Test func synchronizeProducesAnOffsetAgainstARespondingPeer() async throws {
        let (prober, responder) = await InMemoryTransport.makeConnectedPair()
        let origin = ContinuousClock.now

        // A minimal stand-in for the host side of GameCoordinator: echo
        // every ping straight back as a pong.
        let responderTask = Task {
            var iterator = responder.incomingMessages.makeAsyncIterator()
            while let message = await iterator.next() {
                guard case .clockSyncPing(let sequence, let sentAtNanos) = message else { continue }
                let replyNanos = MonotonicTime.nanoseconds(from: origin, to: ContinuousClock.now)
                try? await responder.send(
                    .clockSyncPong(sequence: sequence, pingSentAtNanos: sentAtNanos, pongSentAtNanos: replyNanos)
                )
            }
        }

        let coordinator = ClockSyncCoordinator(transport: prober, origin: origin, sampleCount: 5)
        let result = try await coordinator.synchronize()

        // Two devices in the same process, same origin: the estimated
        // offset should land very close to zero.
        #expect(abs(result.offsetNanos) < 50_000_000)  // within 50ms
        #expect(result.quality == .good)

        responderTask.cancel()
    }

    @Test func synchronizeThrowsWithNoPeerToRespond() async {
        let lonely = InMemoryTransport()
        let coordinator = ClockSyncCoordinator(transport: lonely, origin: ContinuousClock.now, sampleCount: 3)

        await #expect(throws: GameTransportError.notConnected) {
            try await coordinator.synchronize()
        }
    }
}
