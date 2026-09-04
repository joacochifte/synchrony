import Testing

@testable import SynchronyTransport

@Suite struct InMemoryTransportTests {

    @Test func connectedPairStartsInConnectedState() async {
        let (deviceA, _) = await InMemoryTransport.makeConnectedPair()

        var iterator = deviceA.connectionState.makeAsyncIterator()
        let firstState = await iterator.next()
        #expect(firstState == .connected)
    }

    @Test func sendingDeliversToThePeersIncomingMessages() async throws {
        let (deviceA, deviceB) = await InMemoryTransport.makeConnectedPair()

        try await deviceA.send(.handshake(protocolVersion: 1))

        var iterator = deviceB.incomingMessages.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == .handshake(protocolVersion: 1))
    }

    @Test func sendingWithoutAPeerThrows() async {
        let lonely = InMemoryTransport()
        await #expect(throws: GameTransportError.notConnected) {
            try await lonely.send(.handshakeAccepted)
        }
    }

    @Test func disconnectNotifiesThePeer() async {
        let (deviceA, deviceB) = await InMemoryTransport.makeConnectedPair()

        var stateIterator = deviceB.connectionState.makeAsyncIterator()
        _ = await stateIterator.next()  // the initial .connected event

        await deviceA.disconnect()

        let stateAfterDisconnect = await stateIterator.next()
        #expect(stateAfterDisconnect == .disconnected(reason: "peer disconnected"))
    }

    @Test func disconnectEndsTheIncomingMessagesStream() async {
        let (deviceA, deviceB) = await InMemoryTransport.makeConnectedPair()

        await deviceA.disconnect()

        var receivedAnything = false
        for await _ in deviceB.incomingMessages {
            receivedAnything = true
        }
        #expect(!receivedAnything)
    }

    @Test func sendingAfterDisconnectThrows() async {
        let (deviceA, _) = await InMemoryTransport.makeConnectedPair()
        await deviceA.disconnect()

        await #expect(throws: GameTransportError.notConnected) {
            try await deviceA.send(.handshakeAccepted)
        }
    }
}
