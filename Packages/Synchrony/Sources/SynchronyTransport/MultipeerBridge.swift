// MultipeerConnectivity's delegate protocols are @objc and call their
// methods from arbitrary background queues — Apple's SDK doesn't mark
// MCPeerID/MCSession Sendable as of this Xcode version. @preconcurrency
// treats the framework as an unaudited legacy module boundary rather than
// fighting the type checker over types this package doesn't own.
@preconcurrency import MultipeerConnectivity

/// Swift actors can't subclass `NSObject`, which every MultipeerConnectivity
/// delegate protocol requires. This small `NSObject` bridges the raw,
/// thread-hopping ObjC callbacks into `@Sendable` closures that
/// `MultipeerTransport` can safely receive on its own actor via `Task`.
final class MultipeerBridge: NSObject, Sendable {
    private let onSessionStateChange: @Sendable (MCPeerID, MCSessionState) -> Void
    private let onReceiveData: @Sendable (Data, MCPeerID) -> Void
    private let onFoundPeer: @Sendable (MCPeerID, MCNearbyServiceBrowser) -> Void
    private let onReceiveInvitation: @Sendable (MCPeerID, @escaping @Sendable (Bool, MCSession?) -> Void) -> Void

    init(
        onSessionStateChange: @escaping @Sendable (MCPeerID, MCSessionState) -> Void,
        onReceiveData: @escaping @Sendable (Data, MCPeerID) -> Void,
        onFoundPeer: @escaping @Sendable (MCPeerID, MCNearbyServiceBrowser) -> Void,
        onReceiveInvitation: @escaping @Sendable (MCPeerID, @escaping @Sendable (Bool, MCSession?) -> Void) -> Void
    ) {
        self.onSessionStateChange = onSessionStateChange
        self.onReceiveData = onReceiveData
        self.onFoundPeer = onFoundPeer
        self.onReceiveInvitation = onReceiveInvitation
    }
}

extension MultipeerBridge: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        onSessionStateChange(peerID, state)
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        onReceiveData(data, peerID)
    }

    // Synchrony never sends streams or resources — required by the
    // protocol, intentionally empty.
    func session(
        _ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID
    ) {
    }

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {}
}

extension MultipeerBridge: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?
    ) {
        onFoundPeer(peerID, browser)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // No action needed: losing sight of an unconnected peer during
        // discovery isn't a connection-state change.
    }
}

extension MultipeerBridge: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping @Sendable (Bool, MCSession?) -> Void
    ) {
        onReceiveInvitation(peerID, invitationHandler)
    }
}
