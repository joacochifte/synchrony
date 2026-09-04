import SwiftData
import SynchronyCore
import SynchronyPersistence
import SynchronyTransport

#if DEBUG
    extension GameCoordinator {
        /// A coordinator backed by an in-memory store, for SwiftUI previews.
        public static func previewInstance() -> GameCoordinator {
            // swiftlint:disable:next force_try
            let container = try! ModelContainer.makeSynchronyContainer(inMemory: true)
            return GameCoordinator(repository: MatchHistoryRepository(container: container))
        }

        /// A coordinator with a handful of sample matches already saved,
        /// for previewing the history screen.
        public static func previewInstanceWithHistory() -> GameCoordinator {
            let coordinator = previewInstance()
            let samplePercentages: [Double] = [40, 60, 70, 90, 80]
            for (index, percentage) in samplePercentages.enumerated() {
                let record = MatchRecord(
                    id: "preview-\(index)",
                    playedAt: .now.addingTimeInterval(Double(index - samplePercentages.count) * 86_400),
                    roundCount: 10,
                    syncedRoundCount: Int(percentage / 10),
                    syncPercentage: percentage
                )
                try? coordinator.repository.save(record)
            }
            coordinator.loadHistory()
            return coordinator
        }

        /// A coordinator snapshotted at a specific screen, for previewing
        /// match-state-dependent views without waiting on a real (or
        /// simulated) connection and its scheduling delays.
        public static func previewFixture(
            screen: Screen,
            role: Role = .host,
            prompt: Prompt = Prompt(
                id: "preview",
                text: "¿Playa o montaña?",
                kind: .multipleChoice(options: ["Playa", "Montaña"])
            ),
            myAnswer: AnswerValue? = nil,
            opponentAnswer: AnswerValue? = nil,
            lastRoundSynced: Bool? = nil,
            roundNumber: Int = 3,
            totalRounds: Int = 10,
            finalSyncPercentage: Double = 70,
            connectionQuality: ConnectionQuality = .good
        ) -> GameCoordinator {
            let coordinator = previewInstance()
            coordinator.screen = screen
            coordinator.role = role
            coordinator.currentPrompt = prompt
            coordinator.myAnswer = myAnswer
            coordinator.opponentAnswer = opponentAnswer
            coordinator.lastRoundSynced = lastRoundSynced
            coordinator.roundNumber = roundNumber
            coordinator.totalRounds = totalRounds
            coordinator.finalSyncPercentage = finalSyncPercentage
            coordinator.connectionQuality = connectionQuality
            return coordinator
        }

        /// Runs a real, live session over a connected pair of
        /// `InMemoryTransport`, with a scripted opponent answering each
        /// round automatically — for previewing real connection-state
        /// transitions instead of a static fixture.
        public static func previewLiveSession() -> GameCoordinator {
            let coordinator = previewInstance()
            Task {
                let (mine, opponent) = await InMemoryTransport.makeConnectedPair()
                async let session: Void = coordinator.beginSession(transport: mine, role: .host)
                async let script: Void = runScriptedOpponent(over: opponent)
                _ = await (session, script)
            }
            return coordinator
        }

        private static func runScriptedOpponent(over transport: any GameTransport) async {
            for await message in transport.incomingMessages {
                switch message {
                case .handshake:
                    try? await transport.send(.handshakeAccepted)
                case .clockSyncPing(let sequence, let sentAtNanos):
                    try? await transport.send(
                        .clockSyncPong(sequence: sequence, pingSentAtNanos: sentAtNanos, pongSentAtNanos: sentAtNanos)
                    )
                case .roundStart:
                    try? await Task.sleep(for: .milliseconds(800))
                    try? await transport.send(.answer(.choice("Playa")))
                default:
                    break
                }
            }
        }
    }
#endif
