import Testing

@testable import SynchronyCore

@Suite struct MatchTests {

    @Test func newMatchStartsWithNoRounds() {
        let match = Match(id: "m1")
        #expect(match.rounds.isEmpty)
    }

    @Test func roundsCanBeAppended() {
        let prompt = Prompt(id: "p1", text: "¿Playa o montaña?", kind: .multipleChoice(options: ["Playa", "Montaña"]))
        var match = Match(id: "m1")
        match.rounds.append(Round(prompt: prompt))
        #expect(match.rounds.count == 1)
    }
}
