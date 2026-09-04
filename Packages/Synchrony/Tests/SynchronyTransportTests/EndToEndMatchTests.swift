import Testing

@testable import SynchronyCore
@testable import SynchronyTransport

/// Simulates a full two-device match over `InMemoryTransport`, with no
/// coordinator type in between — that composition point doesn't exist yet
/// (it arrives once `MultipeerTransport` and the UI need it in later
/// phases), so this test plays both devices' roles directly to prove
/// `MatchEngine` and `GameTransport` compose correctly. Host is
/// `PlayerSlot.one`, peer is `PlayerSlot.two`, fixed for the whole match.
@Suite struct EndToEndMatchTests {

    private static let prompts = [
        Prompt(id: "p1", text: "Elegí un número del 1 al 10", kind: .numeric(range: 1...10, tolerance: 0)),
        Prompt(id: "p2", text: "¿Playa o montaña?", kind: .multipleChoice(options: ["Playa", "Montaña"])),
    ]

    @Test func playsAFullMatchToCompletionWithMatchingScores() async throws {
        let (host, peer) = await InMemoryTransport.makeConnectedPair()

        var hostEngine = MatchEngine(matchID: "m1", prompts: Self.prompts)
        var peerEngine = MatchEngine(matchID: "m1", prompts: Self.prompts)

        var hostIncoming = host.incomingMessages.makeAsyncIterator()
        var peerIncoming = peer.incomingMessages.makeAsyncIterator()

        // Handshake.
        try await host.send(.handshake(protocolVersion: ProtocolVersion.current))
        #expect(await peerIncoming.next() == .handshake(protocolVersion: ProtocolVersion.current))
        try await peer.send(.handshakeAccepted)
        #expect(await hostIncoming.next() == .handshakeAccepted)

        // Round 0: numeric, synchronized.
        try await host.send(.roundStart(prompt: Self.prompts[0], showAtNanos: 0))
        _ = await peerIncoming.next()

        try hostEngine.submitAnswer(.number(7), as: .one)
        try await host.send(.answer(.number(7)))
        try peerEngine.applyReceivedAnswer(await peerIncoming.next(), as: .one)

        try peerEngine.submitAnswer(.number(7), as: .two)
        try await peer.send(.answer(.number(7)))
        try hostEngine.applyReceivedAnswer(await hostIncoming.next(), as: .two)

        #expect(hostEngine.state == .revealing(roundIndex: 0))
        #expect(peerEngine.state == .revealing(roundIndex: 0))

        try await host.send(.reveal(revealAtNanos: 100))
        _ = await peerIncoming.next()
        try hostEngine.advance()
        try peerEngine.advance()

        // Round 1: multiple choice, not synchronized.
        try await host.send(.roundStart(prompt: Self.prompts[1], showAtNanos: 200))
        _ = await peerIncoming.next()

        try hostEngine.submitAnswer(.choice("Playa"), as: .one)
        try await host.send(.answer(.choice("Playa")))
        try peerEngine.applyReceivedAnswer(await peerIncoming.next(), as: .one)

        try peerEngine.submitAnswer(.choice("Montaña"), as: .two)
        try await peer.send(.answer(.choice("Montaña")))
        try hostEngine.applyReceivedAnswer(await hostIncoming.next(), as: .two)

        try await host.send(.reveal(revealAtNanos: 300))
        _ = await peerIncoming.next()
        try hostEngine.advance()
        try peerEngine.advance()

        #expect(hostEngine.state == .finished)
        #expect(peerEngine.state == .finished)
        #expect(hostEngine.syncPercentage == 50)
        #expect(peerEngine.syncPercentage == 50)

        try await host.send(.matchEnd(syncPercentage: hostEngine.syncPercentage))
        #expect(await peerIncoming.next() == .matchEnd(syncPercentage: 50))
    }

    @Test func handshakeVersionMismatchIsRejected() async throws {
        let (host, peer) = await InMemoryTransport.makeConnectedPair()
        var peerIncoming = peer.incomingMessages.makeAsyncIterator()

        try await host.send(.handshake(protocolVersion: ProtocolVersion.current + 1))

        guard case .handshake(let receivedVersion) = await peerIncoming.next() else {
            Issue.record("expected a handshake message")
            return
        }
        #expect(receivedVersion != ProtocolVersion.current)

        try await peer.send(.handshakeRejected(reason: "protocol version mismatch"))
        var hostIncoming = host.incomingMessages.makeAsyncIterator()
        #expect(await hostIncoming.next() == .handshakeRejected(reason: "protocol version mismatch"))
    }

    @Test func peerDisconnectingMidMatchIsObservable() async throws {
        let (host, peer) = await InMemoryTransport.makeConnectedPair()
        var peerIncoming = peer.incomingMessages.makeAsyncIterator()
        var peerState = peer.connectionState.makeAsyncIterator()
        _ = await peerState.next()  // initial .connected

        try await host.send(.roundStart(prompt: Self.prompts[0], showAtNanos: 0))
        _ = await peerIncoming.next()

        await host.disconnect()

        #expect(await peerState.next() == .disconnected(reason: "peer disconnected"))

        await #expect(throws: GameTransportError.notConnected) {
            try await host.send(.answer(.number(1)))
        }
    }
}

extension MatchEngine {
    /// Test helper: unwraps a received `.answer` message and applies it.
    /// Fails loudly on any other message shape — an out-of-order message
    /// in this simulated flow is a test bug, not something to swallow.
    fileprivate mutating func applyReceivedAnswer(_ message: GameMessage?, as slot: PlayerSlot) throws {
        guard case .answer(let value) = message else {
            Issue.record("expected an .answer message, got \(String(describing: message))")
            return
        }
        try submitAnswer(value, as: slot)
    }
}
