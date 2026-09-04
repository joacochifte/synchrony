/// Lifecycle of a `GameTransport` connection, observable by the UI so it
/// can show a "waiting for the other player" or "connection lost" state.
public enum TransportConnectionState: Equatable, Sendable {
    case notConnected
    case connecting
    case connected
    case disconnected(reason: String?)
}
