import Testing

@testable import SynchronyCore

@Suite struct RoundTests {

    private static let numericPrompt = Prompt(
        id: "p1",
        text: "Elegí un número del 1 al 10",
        kind: .numeric(range: 1...10, tolerance: 0)
    )

    @Test func incompleteRoundIsNotComplete() {
        let round = Round(prompt: Self.numericPrompt, answerOne: .number(5))
        #expect(!round.isComplete)
        #expect(round.isSynchronized == nil)
    }

    @Test func completeRoundIsComplete() {
        let round = Round(prompt: Self.numericPrompt, answerOne: .number(5), answerTwo: .number(5))
        #expect(round.isComplete)
    }

    @Test func completeRoundReportsSynchronization() {
        let matching = Round(prompt: Self.numericPrompt, answerOne: .number(5), answerTwo: .number(5))
        #expect(matching.isSynchronized == true)

        let mismatched = Round(prompt: Self.numericPrompt, answerOne: .number(5), answerTwo: .number(6))
        #expect(mismatched.isSynchronized == false)
    }
}
