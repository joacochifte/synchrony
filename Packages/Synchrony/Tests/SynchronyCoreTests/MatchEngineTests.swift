import Testing

@testable import SynchronyCore

@Suite struct MatchEngineTests {

    private static func prompt(_ id: String, tolerance: Int = 0) -> Prompt {
        Prompt(id: id, text: "t", kind: .numeric(range: 1...10, tolerance: tolerance))
    }

    @Test func emptyDeckStartsFinished() {
        let engine = MatchEngine(matchID: "m1", prompts: [])
        #expect(engine.state == .finished)
    }

    @Test func nonEmptyDeckStartsAnsweringFirstRound() {
        let engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1")])
        #expect(engine.state == .answering(roundIndex: 0))
    }

    @Test func oneAnswerKeepsStateAnswering() throws {
        var engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1")])
        try engine.submitAnswer(.number(5), as: .one)
        #expect(engine.state == .answering(roundIndex: 0))
    }

    @Test func bothAnswersMoveStateToRevealing() throws {
        var engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1")])
        try engine.submitAnswer(.number(5), as: .one)
        try engine.submitAnswer(.number(5), as: .two)
        #expect(engine.state == .revealing(roundIndex: 0))
    }

    @Test func submittingWhileRevealingThrows() throws {
        var engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1")])
        try engine.submitAnswer(.number(5), as: .one)
        try engine.submitAnswer(.number(5), as: .two)

        #expect(throws: MatchEngineError.notCurrentlyAnswering) {
            try engine.submitAnswer(.number(1), as: .one)
        }
    }

    @Test func advancingWhileAnsweringThrows() {
        var engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1"), Self.prompt("p2")])
        #expect(throws: MatchEngineError.notCurrentlyRevealing) {
            try engine.advance()
        }
    }

    @Test func advanceMovesToNextRound() throws {
        var engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1"), Self.prompt("p2")])
        try engine.submitAnswer(.number(5), as: .one)
        try engine.submitAnswer(.number(5), as: .two)
        try engine.advance()
        #expect(engine.state == .answering(roundIndex: 1))
    }

    @Test func advanceOnLastRoundFinishesTheMatch() throws {
        var engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1")])
        try engine.submitAnswer(.number(5), as: .one)
        try engine.submitAnswer(.number(5), as: .two)
        try engine.advance()
        #expect(engine.state == .finished)
    }

    @Test func syncPercentageIsZeroWithNoCompletedRounds() {
        let engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1")])
        #expect(engine.syncPercentage == 0)
    }

    @Test func syncPercentageAcrossAFullMatch() throws {
        var engine = MatchEngine(matchID: "m1", prompts: [Self.prompt("p1"), Self.prompt("p2")])

        // Round 1: synchronized.
        try engine.submitAnswer(.number(5), as: .one)
        try engine.submitAnswer(.number(5), as: .two)
        try engine.advance()

        // Round 2: not synchronized.
        try engine.submitAnswer(.number(1), as: .one)
        try engine.submitAnswer(.number(9), as: .two)
        try engine.advance()

        #expect(engine.state == .finished)
        #expect(engine.syncPercentage == 50)
    }
}
