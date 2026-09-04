@preconcurrency import MultipeerConnectivity

/// The real transport: two iPhones on the same local network, paired with
/// no codes and no login, per the product's zero-config pairing
/// requirement. One device calls `host(displayName:)` and advertises;
/// the other calls `join(displayName:)`, finds the host, and invites
/// itself in — there's no peer picker UI, since a Synchrony match is
/// always exactly two devices.
public actor MultipeerTransport: GameTransport {
    /// Bonjour service type: 1–15 characters, lowercase letters/numbers/
    /// hyphens only. Declared again (as `_synchrony._tcp`/`_synchrony._udp`)
    /// in the app's Info.plist under `NSBonjourServices` — without that,
    /// MultipeerConnectivity fails silently on iOS 14+.
    private static let serviceType = "synchrony"

    private let peerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var bridge: MultipeerBridge?
    private var connectedPeer: MCPeerID?

    private let messageContinuation: AsyncStream<GameMessage>.Continuation
    // swiftlint:disable implicitly_unwrapped_optional
    nonisolated public let incomingMessages: AsyncStream<GameMessage>

    private let stateContinuation: AsyncStream<TransportConnectionState>.Continuation
    nonisolated public let connectionState: AsyncStream<TransportConnectionState>

    private init(displayName: String) {
        let peerID = MCPeerID(displayName: displayName)
        self.peerID = peerID
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)

        var messageContinuation: AsyncStream<GameMessage>.Continuation!
        self.incomingMessages = AsyncStream { messageContinuation = $0 }
        self.messageContinuation = messageContinuation

        var stateContinuation: AsyncStream<TransportConnectionState>.Continuation!
        self.connectionState = AsyncStream { stateContinuation = $0 }
        self.stateContinuation = stateContinuation
    }
    // swiftlint:enable implicitly_unwrapped_optional

    /// Creates a game and advertises it on the local network.
    public static func host(displayName: String) async -> MultipeerTransport {
        let transport = MultipeerTransport(displayName: displayName)
        await transport.startAdvertising()
        return transport
    }

    /// Looks for a hosted game on the local network and joins the first
    /// one found.
    public static func join(displayName: String) async -> MultipeerTransport {
        let transport = MultipeerTransport(displayName: displayName)
        await transport.startBrowsing()
        return transport
    }

    public func send(_ message: GameMessage) async throws {
        guard let connectedPeer else { throw GameTransportError.notConnected }
        let data = try JSONEncoder().encode(message)
        try session.send(data, toPeers: [connectedPeer], with: .reliable)
    }

    public func disconnect() async {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        connectedPeer = nil
        stateContinuation.yield(.disconnected(reason: nil))
        messageContinuation.finish()
    }

    // MARK: - Setup

    private func startAdvertising() {
        let bridge = makeBridge()
        self.bridge = bridge
        session.delegate = bridge

        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = bridge
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        stateContinuation.yield(.connecting)
    }

    private func startBrowsing() {
        let bridge = makeBridge()
        self.bridge = bridge
        session.delegate = bridge

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = bridge
        browser.startBrowsingForPeers()
        self.browser = browser

        stateContinuation.yield(.connecting)
    }

    private func makeBridge() -> MultipeerBridge {
        MultipeerBridge(
            onSessionStateChange: { [weak self] peerID, state in
                Task { await self?.handleSessionStateChange(peerID: peerID, state: state) }
            },
            onReceiveData: { [weak self] data, _ in
                Task { await self?.handleReceivedData(data) }
            },
            onFoundPeer: { [weak self] peerID, browser in
                Task { await self?.handleFoundPeer(peerID, browser: browser) }
            },
            onReceiveInvitation: { [weak self] peerID, handler in
                Task { await self?.handleReceivedInvitation(from: peerID, handler: handler) }
            }
        )
    }

    // MARK: - Bridge callbacks

    private func handleSessionStateChange(peerID: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            connectedPeer = peerID
            stateContinuation.yield(.connected)

        case .connecting:
            stateContinuation.yield(.connecting)

        case .notConnected:
            let wasTheConnectedPeer = connectedPeer == peerID
            connectedPeer = nil
            if wasTheConnectedPeer {
                stateContinuation.yield(.disconnected(reason: "peer disconnected"))
                messageContinuation.finish()
            }

        @unknown default:
            break
        }
    }

    private func handleReceivedData(_ data: Data) {
        // Malformed or foreign data on the session is dropped, not
        // trapped on — a corrupt packet shouldn't end the match.
        guard let message = try? JSONDecoder().decode(GameMessage.self, from: data) else { return }
        messageContinuation.yield(message)
    }

    private func handleFoundPeer(_ peerID: MCPeerID, browser: MCNearbyServiceBrowser) {
        guard connectedPeer == nil else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    private func handleReceivedInvitation(from peerID: MCPeerID, handler: @Sendable (Bool, MCSession?) -> Void) {
        guard connectedPeer == nil else {
            handler(false, nil)
            return
        }
        handler(true, session)
    }
}
