public enum GameTransportError: Error, Equatable, Sendable {
    /// Tried to send while there's no connected peer to send to.
    case notConnected
}
