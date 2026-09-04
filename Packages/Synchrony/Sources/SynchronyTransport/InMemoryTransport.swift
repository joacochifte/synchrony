/// In-process loopback transport: two instances wired to each other so
/// sending on one delivers straight into the other's `incomingMessages`,
/// with no networking involved. Used by tests and SwiftUI previews to
/// exercise the full game flow without real devices.
public actor InMemoryTransport: GameTransport {
    private var peer: InMemoryTransport?

    private let messageContinuation: AsyncStream<GameMessage>.Continuation
    nonisolated public let incomingMessages: AsyncStream<GameMessage>

    private let stateContinuation: AsyncStream<TransportConnectionState>.Continuation
    nonisolated public let connectionState: AsyncStream<TransportConnectionState>

    public init() {
        // AsyncStream's closure-based initializer is the standard way to
        // capture its continuation for later use — there's no non-IUO way
        // to escape a value out of that closure before the stream exists.
        // swiftlint:disable implicitly_unwrapped_optional
        var messageContinuation: AsyncStream<GameMessage>.Continuation!
        self.incomingMessages = AsyncStream { messageContinuation = $0 }
        self.messageContinuation = messageContinuation

        var stateContinuation: AsyncStream<TransportConnectionState>.Continuation!
        self.connectionState = AsyncStream { stateContinuation = $0 }
        self.stateContinuation = stateContinuation
        // swiftlint:enable implicitly_unwrapped_optional
    }

    /// Creates two `InMemoryTransport` instances already wired to each
    /// other, both in `.connected` state.
    public static func makeConnectedPair() async -> (InMemoryTransport, InMemoryTransport) {
        let deviceA = InMemoryTransport()
        let deviceB = InMemoryTransport()
        await deviceA.connect(to: deviceB)
        await deviceB.connect(to: deviceA)
        return (deviceA, deviceB)
    }

    public func send(_ message: GameMessage) async throws {
        guard let peer else { throw GameTransportError.notConnected }
        await peer.deliver(message)
    }

    public func disconnect() async {
        let connectedPeer = peer
        peer = nil
        stateContinuation.yield(.disconnected(reason: nil))
        messageContinuation.finish()
        await connectedPeer?.receivePeerDisconnect()
    }

    private func connect(to peer: InMemoryTransport) {
        self.peer = peer
        stateContinuation.yield(.connected)
    }

    private func deliver(_ message: GameMessage) {
        messageContinuation.yield(message)
    }

    private func receivePeerDisconnect() {
        peer = nil
        stateContinuation.yield(.disconnected(reason: "peer disconnected"))
        messageContinuation.finish()
    }
}
