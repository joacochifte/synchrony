import Foundation
import Observation
import SwiftData
import SynchronyCore
import SynchronyPersistence
import SynchronyTransport

/// Ties `MatchEngine`, `GameTransport`, and `MatchHistoryRepository`
/// together into an actual playable match — the composition point ADR-0002
/// and ADR-0004 both deferred until the UI needed it.
///
/// Host and peer play asymmetric roles on purpose: the host is the only
/// side that runs a `MatchEngine` (it already has the full prompt list from
/// `DeckLoader`, so it can own the authoritative answering/revealing/
/// finished state machine and decide round timing). The peer never builds
/// its own `MatchEngine` — `GameMessage.roundStart` only ever carries one
/// prompt at a time, matching the spec's wire shape, so the peer just
/// reacts to whatever arrives and computes each round's own sync result
/// directly via `PromptKind.isMatch(_:_:)`, no local state machine needed.
@MainActor
@Observable
public final class GameCoordinator {
    public enum Screen: Equatable, Sendable {
        case home
        case pairing
        case playing
        case revealing
        case summary
        case history
    }

    public enum Role: Equatable, Sendable {
        case host
        case peer
    }

    /// Rounds per match. Not sent over the wire — both sides assume this
    /// default, per the spec's own round-loop description.
    public static let roundCount = 10

    /// Scheduling margin for a healthy connection, in nanoseconds — "now +
    /// this much" is what `showAtNanos`/`revealAtNanos` get set to.
    private let baseRevealMarginNanos: Int64
    private let degradedRevealMarginNanos: Int64
    /// How long the reveal stays on screen before auto-advancing.
    private let revealViewingDuration: Duration

    public internal(set) var screen: Screen = .home
    public internal(set) var role: Role?
    public internal(set) var connectionState: TransportConnectionState = .notConnected
    public internal(set) var connectionQuality: ConnectionQuality = .good
    public internal(set) var errorMessage: String?

    public internal(set) var currentPrompt: Prompt?
    public internal(set) var roundNumber: Int = 0
    public internal(set) var totalRounds: Int = GameCoordinator.roundCount
    public internal(set) var myAnswer: AnswerValue?
    public internal(set) var opponentAnswer: AnswerValue?
    public internal(set) var lastRoundSynced: Bool?
    public internal(set) var finalSyncPercentage: Double = 0

    public internal(set) var history: [MatchRecord] = []
    public internal(set) var historyStatistics = MatchHistoryStatistics.compute(from: [])

    private var transport: (any GameTransport)?
    private var engine: MatchEngine?
    private var mySlot: PlayerSlot = .one
    private var opponentSlot: PlayerSlot = .two
    private let origin = ContinuousClock.now
    private var offsetNanos: Int64 = 0
    private var clockSync: ClockSyncCoordinator?
    /// Plain data, not `RoundRecord` — `@Model` instances only get built at
    /// the moment they're inserted into a context in `finishMatch`, not
    /// held around for the length of a match. SwiftData has been flaky
    /// about model objects created well before ever touching a context.
    private var completedRounds: [CompletedRound] = []
    private var matchID = UUID().uuidString

    private struct CompletedRound {
        let promptID: String
        let promptText: String
        let wasSynchronized: Bool
    }

    let repository: MatchHistoryRepository

    /// - Parameters:
    ///   - baseRevealMarginNanos: scheduling margin on a healthy connection.
    ///     Defaults to the spec's own example (500ms).
    ///   - degradedRevealMarginNanos: scheduling margin once
    ///     `ConnectionQuality` reports `.degraded`.
    ///   - revealViewingDuration: how long the reveal stays up before
    ///     auto-advancing to the next round. Tests pass tiny values for all
    ///     three so a simulated match doesn't take tens of real seconds.
    public init(
        repository: MatchHistoryRepository,
        baseRevealMarginNanos: Int64 = 500_000_000,
        degradedRevealMarginNanos: Int64 = 1_000_000_000,
        revealViewingDuration: Duration = .seconds(3)
    ) {
        self.repository = repository
        self.baseRevealMarginNanos = baseRevealMarginNanos
        self.degradedRevealMarginNanos = degradedRevealMarginNanos
        self.revealViewingDuration = revealViewingDuration
    }

    // MARK: - Starting a session

    public func hostGame(displayName: String) {
        errorMessage = nil
        screen = .pairing
        Task {
            let transport = await MultipeerTransport.host(displayName: displayName)
            await beginSession(transport: transport, role: .host)
        }
    }

    public func joinGame(displayName: String) {
        errorMessage = nil
        screen = .pairing
        Task {
            let transport = await MultipeerTransport.join(displayName: displayName)
            await beginSession(transport: transport, role: .peer)
        }
    }

    /// Exposed so SwiftUI previews — and anything else — can drive a
    /// session over `InMemoryTransport` instead of the real
    /// `MultipeerTransport`.
    public func beginSession(transport: any GameTransport, role: Role) async {
        self.transport = transport
        self.role = role
        mySlot = role == .host ? .one : .two
        opponentSlot = role == .host ? .two : .one
        matchID = UUID().uuidString
        completedRounds = []

        if role == .peer {
            clockSync = ClockSyncCoordinator(transport: transport, origin: origin)
        }

        Task { [weak self] in await self?.observeConnectionState(transport) }
        Task { [weak self] in await self?.runMessageLoop(transport) }
    }

    public func returnHome() {
        transport = nil
        engine = nil
        clockSync = nil
        role = nil
        screen = .home
        connectionState = .notConnected
        currentPrompt = nil
        myAnswer = nil
        opponentAnswer = nil
    }

    public func showHistory() {
        loadHistory()
        screen = .history
    }

    // MARK: - Connection lifecycle

    private func observeConnectionState(_ transport: any GameTransport) async {
        for await state in transport.connectionState {
            connectionState = state

            if state == .connected, role == .host {
                try? await transport.send(.handshake(protocolVersion: ProtocolVersion.current))
            }

            if case .disconnected = state, screen != .summary, screen != .home {
                errorMessage = String(localized: "El otro jugador se desconectó.")
                screen = .home
            }
        }
    }

    // MARK: - Message loop

    /// The single consumer of `transport.incomingMessages` — an
    /// `AsyncStream` only has one real reader, so every message type,
    /// including the ones `ClockSyncCoordinator` cares about, gets
    /// dispatched from here rather than read independently elsewhere.
    private func runMessageLoop(_ transport: any GameTransport) async {
        for await message in transport.incomingMessages {
            await handle(message, transport: transport)
        }
    }

    private func handle(_ message: GameMessage, transport: any GameTransport) async {
        switch message {
        case .handshake(let version):
            await handleHandshake(version: version, transport: transport)
        case .handshakeAccepted:
            await handleHandshakeAccepted(transport: transport)
        case .handshakeRejected(let reason):
            handleHandshakeRejected(reason: reason)
        case .clockSyncPing(let sequence, let sentAtNanos):
            await respondToClockSyncPing(sequence: sequence, sentAtNanos: sentAtNanos, transport: transport)
        case .clockSyncPong:
            await clockSync?.receive(message)
        case .roundStart(let prompt, let showAtNanos):
            await presentRound(prompt: prompt, showAtNanos: showAtNanos)
        case .answer(let value):
            await handleOpponentAnswer(value, transport: transport)
        case .reveal(let revealAtNanos):
            await presentReveal(revealAtNanos: revealAtNanos, transport: transport)
        case .matchEnd(let syncPercentage):
            await finishMatch(syncPercentage: syncPercentage)
        }
    }

    private func handleHandshakeAccepted(transport: any GameTransport) async {
        guard role == .host else { return }
        await startMatch(transport: transport)
    }

    private func handleHandshakeRejected(reason: String) {
        // `reason` is a wire-protocol detail, not user-facing copy — the
        // two devices in a match aren't guaranteed to share a locale, so
        // showing it verbatim could put the wrong language on screen. The
        // message shown here is always in the local device's own language.
        errorMessage = String(localized: "No se pudo conectar: las versiones de la app no coinciden.")
        returnHome()
    }

    private func respondToClockSyncPing(sequence: Int, sentAtNanos: Int64, transport: any GameTransport) async {
        let replyNanos = MonotonicTime.nanoseconds(from: origin, to: ContinuousClock.now)
        try? await transport.send(
            .clockSyncPong(sequence: sequence, pingSentAtNanos: sentAtNanos, pongSentAtNanos: replyNanos)
        )
    }

    private func handleOpponentAnswer(_ value: AnswerValue, transport: any GameTransport) async {
        opponentAnswer = value
        guard role == .host else { return }
        _ = try? engine?.submitAnswer(value, as: opponentSlot)
        await hostAdvanceIfRevealing(transport: transport)
    }

    private func handleHandshake(version: Int, transport: any GameTransport) async {
        guard version == ProtocolVersion.current else {
            try? await transport.send(.handshakeRejected(reason: "protocol version mismatch"))
            return
        }
        try? await transport.send(.handshakeAccepted)

        if role == .peer, let clockSync {
            Task { [weak self] in
                guard let result = try? await clockSync.synchronize() else { return }
                self?.offsetNanos = result.offsetNanos
                self?.connectionQuality = result.quality
            }
        }
    }

    // MARK: - Host: driving the match

    private func startMatch(transport: any GameTransport) async {
        guard let deck = try? DeckLoader.loadBundledDeck() else { return }
        let prompts = DeckLoader.selectRound(from: deck, count: Self.roundCount)
        engine = MatchEngine(matchID: matchID, prompts: prompts)
        totalRounds = prompts.count
        await startRound(at: 0, transport: transport)
    }

    private func startRound(at roundIndex: Int, transport: any GameTransport) async {
        guard let engine, roundIndex < engine.match.rounds.count else { return }
        let prompt = engine.match.rounds[roundIndex].prompt
        let margin = connectionQuality == .degraded ? degradedRevealMarginNanos : baseRevealMarginNanos
        let showAtNanos = MonotonicTime.nanoseconds(from: origin, to: ContinuousClock.now) + margin
        try? await transport.send(.roundStart(prompt: prompt, showAtNanos: showAtNanos))
        await presentRound(prompt: prompt, showAtNanos: showAtNanos)
    }

    private func hostAdvanceIfRevealing(transport: any GameTransport) async {
        guard let engine, case .revealing = engine.state else { return }
        let margin = connectionQuality == .degraded ? degradedRevealMarginNanos : baseRevealMarginNanos
        let revealAtNanos = MonotonicTime.nanoseconds(from: origin, to: ContinuousClock.now) + margin
        try? await transport.send(.reveal(revealAtNanos: revealAtNanos))
        await presentReveal(revealAtNanos: revealAtNanos, transport: transport)
    }

    // MARK: - Shared presentation (both roles)

    private func presentRound(prompt: Prompt, showAtNanos: Int64) async {
        await sleepUntil(showAtNanos)

        currentPrompt = prompt
        myAnswer = nil
        opponentAnswer = nil
        lastRoundSynced = nil
        roundNumber += 1
        screen = .playing
    }

    private func presentReveal(revealAtNanos: Int64, transport: any GameTransport) async {
        await sleepUntil(revealAtNanos)

        if let prompt = currentPrompt, let myAnswer, let opponentAnswer {
            let synced = prompt.kind.isMatch(myAnswer, opponentAnswer)
            lastRoundSynced = synced
            completedRounds.append(
                CompletedRound(promptID: prompt.id, promptText: prompt.text, wasSynchronized: synced))
        }
        screen = .revealing

        try? await Task.sleep(for: revealViewingDuration)

        if role == .host {
            await hostAdvance(transport: transport)
        }
    }

    private func hostAdvance(transport: any GameTransport) async {
        guard var currentEngine = engine else { return }
        _ = try? currentEngine.advance()
        engine = currentEngine

        switch currentEngine.state {
        case .finished:
            let percentage = currentEngine.syncPercentage
            try? await transport.send(.matchEnd(syncPercentage: percentage))
            await finishMatch(syncPercentage: percentage)

        case .answering(let roundIndex):
            await startRound(at: roundIndex, transport: transport)

        case .revealing:
            break
        }
    }

    private func finishMatch(syncPercentage: Double) async {
        finalSyncPercentage = syncPercentage
        let rounds = completedRounds.map {
            RoundRecord(promptID: $0.promptID, promptText: $0.promptText, wasSynchronized: $0.wasSynchronized)
        }
        let record = MatchRecord(
            id: matchID,
            playedAt: .now,
            roundCount: completedRounds.count,
            syncedRoundCount: completedRounds.count(where: \.wasSynchronized),
            syncPercentage: syncPercentage,
            rounds: rounds
        )
        try? repository.save(record)
        screen = .summary
    }

    // MARK: - Player input

    public func submitAnswer(_ answer: AnswerValue) {
        guard let transport else { return }
        myAnswer = answer

        if role == .host {
            _ = try? engine?.submitAnswer(answer, as: mySlot)
        }

        Task {
            try? await transport.send(.answer(answer))
            if role == .host {
                await hostAdvanceIfRevealing(transport: transport)
            }
        }
    }

    // MARK: - History

    public func loadHistory() {
        guard let records = try? repository.fetchAll() else { return }
        history = records
        historyStatistics = MatchHistoryStatistics.compute(from: records)
    }

    // MARK: - Timing

    private func sleepUntil(_ targetNanos: Int64) async {
        let localTargetNanos = targetNanos - offsetNanos
        let nowNanos = MonotonicTime.nanoseconds(from: origin, to: ContinuousClock.now)
        let delayNanos = max(0, localTargetNanos - nowNanos)
        try? await Task.sleep(for: .nanoseconds(delayNanos))
    }
}
