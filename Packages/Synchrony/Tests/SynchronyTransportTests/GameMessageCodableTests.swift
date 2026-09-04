import Foundation
import Testing

@testable import SynchronyCore
@testable import SynchronyTransport

@Suite struct GameMessageCodableTests {

    private static let samplePrompt = Prompt(id: "p1", text: "¿Cuánto?", kind: .numeric(range: 1...10, tolerance: 1))

    @Test(
        arguments: [
            GameMessage.handshake(protocolVersion: ProtocolVersion.current),
            .handshakeAccepted,
            .handshakeRejected(reason: "version mismatch"),
            .clockSyncPing(sequence: 1, sentAtNanos: 1_000),
            .clockSyncPong(sequence: 1, pingSentAtNanos: 1_000, pongSentAtNanos: 1_050),
            .roundStart(prompt: samplePrompt, showAtNanos: 2_000),
            .answer(.number(7)),
            .reveal(revealAtNanos: 3_000),
            .matchEnd(syncPercentage: 80),
        ]
    )
    func roundTripsThroughEncodeAndDecode(_ message: GameMessage) throws {
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(GameMessage.self, from: data)
        #expect(decoded == message)
    }
}
