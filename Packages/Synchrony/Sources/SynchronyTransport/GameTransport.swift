/// The communication channel between two devices. The game engine
/// (`SynchronyCore`) never sees a concrete transport, only this protocol —
/// `MultipeerTransport` is the real implementation; `InMemoryTransport` is
/// an in-process loopback for tests and SwiftUI previews. Every test in
/// this project that exercises a full match runs against `InMemoryTransport`,
/// with no devices or network involved.
public protocol GameTransport: AnyObject, Sendable {
    /// Connection lifecycle events. A fresh subscriber (a new `for await`
    /// loop) only sees events from that point forward, not history —
    /// callers that need the current state should track it themselves.
    var connectionState: AsyncStream<TransportConnectionState> { get }

    /// Messages from the peer, in the order they arrived.
    var incomingMessages: AsyncStream<GameMessage> { get }

    /// Sends a message to the connected peer.
    /// - Throws: `GameTransportError.notConnected` if there's no peer.
    func send(_ message: GameMessage) async throws

    /// Ends the connection from this side and notifies the peer.
    func disconnect() async
}
