import SwiftData
import Testing

@testable import SynchronyCore
@testable import SynchronyPersistence
@testable import SynchronyTransport
@testable import SynchronyUI

@MainActor
@Suite struct GameCoordinatorTests {

    /// Tiny timing so a full simulated match runs in well under a second
    /// instead of the tens of real seconds the production margins and
    /// reveal-viewing pause would take.
    private func makeCoordinator() throws -> GameCoordinator {
        let container = try ModelContainer.makeSynchronyContainer(inMemory: true)
        return GameCoordinator(
            repository: MatchHistoryRepository(container: container),
            baseRevealMarginNanos: 1_000_000,
            degradedRevealMarginNanos: 2_000_000,
            revealViewingDuration: .milliseconds(10)
        )
    }

    @Test func fullMatchReachesSummaryWithMatchingScoresOnBothSides() async throws {
        let host = try makeCoordinator()
        let peer = try makeCoordinator()
        let (hostTransport, peerTransport) = await InMemoryTransport.makeConnectedPair()

        await host.beginSession(transport: hostTransport, role: .host)
        await peer.beginSession(transport: peerTransport, role: .peer)

        // Drive the match off the host's own round changes: both sides
        // answer with the exact same value the moment the host enters a
        // new round, which trivially matches under any PromptKind's
        // criterion regardless of which kind the deck happened to select.
        // (Waiting for both host's *and* peer's round counters to read the
        // same value at the same poll tick is the wrong way to do this —
        // that instant can slip between two 5ms polls and never be caught,
        // since nothing holds the two coordinators at the same round
        // number for longer than a scheduler turn.)
        var lastRoundSeen = 0
        try await waitUntil(timeout: .seconds(5)) {
            if host.screen == .playing, host.roundNumber != lastRoundSeen, let kind = host.currentPrompt?.kind {
                lastRoundSeen = host.roundNumber
                let answer = Self.matchingAnswer(for: kind)
                host.submitAnswer(answer)
                peer.submitAnswer(answer)
            }
            return host.screen == .summary && peer.screen == .summary
        }

        #expect(host.finalSyncPercentage == 100)
        #expect(peer.finalSyncPercentage == 100)

        host.loadHistory()
        peer.loadHistory()
        #expect(host.history.count == 1)
        #expect(peer.history.count == 1)
        #expect(host.history.first?.syncPercentage == 100)
    }

    /// An answer that trivially matches itself under any `PromptKind`'s
    /// criterion, so a test can synchronize every round regardless of
    /// which kind the deck happened to select.
    private static func matchingAnswer(for kind: PromptKind) -> AnswerValue {
        switch kind {
        case .numeric: .number(5)
        case .multipleChoice(let options): .choice(options[0])
        case .freeText: .text("respuesta")
        case .direction: .heading(90)
        }
    }

    /// Polls `condition` (which may itself take action, like driving the
    /// next round forward) instead of sleeping a fixed amount.
    private func waitUntil(
        timeout: Duration = .seconds(5),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}
