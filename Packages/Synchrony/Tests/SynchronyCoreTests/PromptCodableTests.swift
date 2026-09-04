import Foundation
import Testing

@testable import SynchronyCore

@Suite struct PromptCodableTests {

    @Test func decodesFlatNumericJSON() throws {
        let json = """
            {"id": "p1", "text": "¿Cuánto?", "type": "numeric", "min": 1, "max": 10, "tolerance": 2}
            """
        let prompt = try JSONDecoder().decode(Prompt.self, from: Data(json.utf8))
        #expect(prompt.id == "p1")
        #expect(prompt.kind == .numeric(range: 1...10, tolerance: 2))
    }

    @Test func decodesFlatMultipleChoiceJSON() throws {
        let json = """
            {"id": "p2", "text": "¿Cuál?", "type": "multipleChoice", "options": ["A", "B"]}
            """
        let prompt = try JSONDecoder().decode(Prompt.self, from: Data(json.utf8))
        #expect(prompt.kind == .multipleChoice(options: ["A", "B"]))
    }

    @Test func decodesFlatFreeTextJSON() throws {
        let json = """
            {"id": "p3", "text": "¿Qué?", "type": "freeText", "levenshteinThreshold": 2}
            """
        let prompt = try JSONDecoder().decode(Prompt.self, from: Data(json.utf8))
        #expect(prompt.kind == .freeText(levenshteinThreshold: 2))
    }

    @Test func decodesFlatDirectionJSON() throws {
        let json = """
            {"id": "p4", "text": "¿Hacia dónde?", "type": "direction", "toleranceDegrees": 30}
            """
        let prompt = try JSONDecoder().decode(Prompt.self, from: Data(json.utf8))
        #expect(prompt.kind == .direction(toleranceDegrees: 30))
    }

    @Test func rejectsNumericRangeWhereMinExceedsMax() {
        let json = """
            {"id": "p5", "text": "¿Cuánto?", "type": "numeric", "min": 10, "max": 1, "tolerance": 0}
            """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Prompt.self, from: Data(json.utf8))
        }
    }

    @Test func roundTripsThroughEncodeAndDecode() throws {
        let original = Prompt(id: "p6", text: "Test", kind: .direction(toleranceDegrees: 45))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Prompt.self, from: data)
        #expect(decoded == original)
    }
}
