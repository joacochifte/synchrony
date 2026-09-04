/// Where a match is in its round-by-round flow.
public enum MatchState: Equatable, Sendable {
    /// Round `roundIndex` is showing its prompt; waiting on one or both answers.
    case answering(roundIndex: Int)
    /// Both answers for round `roundIndex` are in and can be revealed.
    case revealing(roundIndex: Int)
    /// All rounds are done.
    case finished
}

public enum MatchEngineError: Error, Equatable, Sendable {
    /// Tried to submit an answer while not in `.answering`.
    case notCurrentlyAnswering
    /// Tried to advance to the next round while not in `.revealing`.
    case notCurrentlyRevealing
}

/// Drives a `Match` through its rounds: collects answers, reveals once both
/// are in, and advances. Knows nothing about how answers arrive — that's the
/// transport layer's job — so it's just as usable against two calls from a
/// unit test as it will be wired to `InMemoryTransport` or the real network.
public struct MatchEngine: Sendable {
    public private(set) var match: Match
    public private(set) var state: MatchState

    /// Builds a match from an already-selected list of prompts — shuffling
    /// and picking the round count is `DeckLoader`'s job, not the engine's,
    /// so the engine stays deterministic and easy to test.
    public init(matchID: String, prompts: [Prompt]) {
        self.match = Match(id: matchID, rounds: prompts.map { Round(prompt: $0) })
        self.state = prompts.isEmpty ? .finished : .answering(roundIndex: 0)
    }

    /// Records one player's answer for the current round. Answers can be
    /// overwritten up until the round completes — nothing in the domain
    /// layer needs to forbid changing your mind before the peer answers;
    /// simultaneity of the reveal is the transport layer's concern.
    @discardableResult
    public mutating func submitAnswer(_ answer: AnswerValue, as slot: PlayerSlot) throws -> MatchState {
        guard case .answering(let roundIndex) = state else {
            throw MatchEngineError.notCurrentlyAnswering
        }

        switch slot {
        case .one: match.rounds[roundIndex].answerOne = answer
        case .two: match.rounds[roundIndex].answerTwo = answer
        }

        if match.rounds[roundIndex].isComplete {
            state = .revealing(roundIndex: roundIndex)
        }
        return state
    }

    /// Moves from a revealed round to the next round's answering phase, or
    /// to `.finished` if that was the last one.
    @discardableResult
    public mutating func advance() throws -> MatchState {
        guard case .revealing(let roundIndex) = state else {
            throw MatchEngineError.notCurrentlyRevealing
        }

        let nextIndex = roundIndex + 1
        state = nextIndex < match.rounds.count ? .answering(roundIndex: nextIndex) : .finished
        return state
    }

    /// Synchrony percentage across completed rounds: 0 until at least one
    /// round is complete, so an in-progress match doesn't report a
    /// misleadingly perfect or empty score.
    public var syncPercentage: Double {
        let completedRounds = match.rounds.filter(\.isComplete)
        guard !completedRounds.isEmpty else { return 0 }
        let syncedCount = completedRounds.filter { $0.isSynchronized == true }.count
        return Double(syncedCount) / Double(completedRounds.count) * 100
    }
}
