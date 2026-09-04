import Foundation
import Testing

@testable import SynchronyCore

@Suite struct DeckLoaderTests {

    @Test func loadsValidPromptArray() throws {
        let json = """
            [{"id": "p1", "text": "Uno", "type": "numeric", "min": 1, "max": 10, "tolerance": 0}]
            """
        let prompts = try DeckLoader.loadPrompts(from: Data(json.utf8))
        #expect(prompts.count == 1)
    }

    @Test func rejectsDuplicateIDs() {
        let json = """
            [
              {"id": "dup", "text": "Uno", "type": "numeric", "min": 1, "max": 10, "tolerance": 0},
              {"id": "dup", "text": "Dos", "type": "numeric", "min": 1, "max": 10, "tolerance": 0}
            ]
            """
        #expect(throws: DeckLoader.LoadError.duplicatePromptID("dup")) {
            try DeckLoader.loadPrompts(from: Data(json.utf8))
        }
    }

    @Test func loadsBundledDeckWithAtLeastFortyUniquePrompts() throws {
        let prompts = try DeckLoader.loadBundledDeck()
        #expect(prompts.count >= 40)

        let uniqueIDs = Set(prompts.map(\.id))
        #expect(uniqueIDs.count == prompts.count)
    }

    @Test func bundledDeckCoversAllFourPromptKinds() throws {
        let prompts = try DeckLoader.loadBundledDeck()

        var sawNumeric = false
        var sawMultipleChoice = false
        var sawFreeText = false
        var sawDirection = false

        for prompt in prompts {
            switch prompt.kind {
            case .numeric: sawNumeric = true
            case .multipleChoice: sawMultipleChoice = true
            case .freeText: sawFreeText = true
            case .direction: sawDirection = true
            }
        }

        #expect(sawNumeric)
        #expect(sawMultipleChoice)
        #expect(sawFreeText)
        #expect(sawDirection)
    }

    @Test func selectRoundIsDeterministicForAGivenSeed() {
        let deck = (0..<20).map { Prompt(id: "p\($0)", text: "t", kind: .numeric(range: 1...10, tolerance: 0)) }

        var generatorA = SeededGenerator(seed: 42)
        var generatorB = SeededGenerator(seed: 42)

        let selectionA = DeckLoader.selectRound(from: deck, count: 5, using: &generatorA)
        let selectionB = DeckLoader.selectRound(from: deck, count: 5, using: &generatorB)

        #expect(selectionA.map(\.id) == selectionB.map(\.id))
    }

    @Test func selectRoundReturnsRequestedCountWithoutDuplicates() {
        let deck = (0..<20).map { Prompt(id: "p\($0)", text: "t", kind: .numeric(range: 1...10, tolerance: 0)) }
        var generator = SeededGenerator(seed: 7)

        let selection = DeckLoader.selectRound(from: deck, count: 10, using: &generator)

        #expect(selection.count == 10)
        #expect(Set(selection.map(\.id)).count == 10)
    }

    @Test func selectRoundCapsAtDeckSizeWhenCountExceedsIt() {
        let deck = (0..<3).map { Prompt(id: "p\($0)", text: "t", kind: .numeric(range: 1...10, tolerance: 0)) }
        var generator = SeededGenerator(seed: 1)

        let selection = DeckLoader.selectRound(from: deck, count: 10, using: &generator)

        #expect(selection.count == 3)
    }
}
