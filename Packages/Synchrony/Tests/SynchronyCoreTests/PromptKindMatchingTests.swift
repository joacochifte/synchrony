import Testing

@testable import SynchronyCore

@Suite struct PromptKindMatchingTests {

    // MARK: - Numeric

    @Test func numericExactMatchWithZeroTolerance() {
        let kind = PromptKind.numeric(range: 1...10, tolerance: 0)
        #expect(kind.isMatch(.number(7), .number(7)))
        #expect(!kind.isMatch(.number(7), .number(8)))
    }

    @Test func numericMatchesWithinToleranceBoundary() {
        let kind = PromptKind.numeric(range: 1...10, tolerance: 2)
        #expect(kind.isMatch(.number(5), .number(7)))
        #expect(!kind.isMatch(.number(5), .number(8)))
    }

    @Test func numericRejectsWrongAnswerShape() {
        let kind = PromptKind.numeric(range: 1...10, tolerance: 0)
        #expect(!kind.isMatch(.number(5), .choice("5")))
    }

    // MARK: - Multiple choice

    @Test func multipleChoiceMatchesSameOption() {
        let kind = PromptKind.multipleChoice(options: ["Playa", "Montaña"])
        #expect(kind.isMatch(.choice("Playa"), .choice("Playa")))
    }

    @Test func multipleChoiceRejectsDifferentOptions() {
        let kind = PromptKind.multipleChoice(options: ["Playa", "Montaña"])
        #expect(!kind.isMatch(.choice("Playa"), .choice("Montaña")))
    }

    // MARK: - Free text

    @Test func freeTextMatchesIgnoringCaseAndAccents() {
        let kind = PromptKind.freeText(levenshteinThreshold: 0)
        #expect(kind.isMatch(.text("Milanesa"), .text("milanesa")))
        #expect(kind.isMatch(.text("Ñoquis"), .text("noquis")))
    }

    @Test func freeTextMatchesWithinThreshold() {
        let kind = PromptKind.freeText(levenshteinThreshold: 2)
        #expect(kind.isMatch(.text("milanesa"), .text("milanesas")))
    }

    @Test func freeTextRejectsBeyondThreshold() {
        let kind = PromptKind.freeText(levenshteinThreshold: 2)
        #expect(!kind.isMatch(.text("milanesa"), .text("ensalada")))
    }

    // MARK: - Direction

    @Test func directionMatchesWithinTolerance() {
        let kind = PromptKind.direction(toleranceDegrees: 15)
        #expect(kind.isMatch(.heading(10), .heading(20)))
    }

    @Test func directionMatchesAcrossWraparound() {
        let kind = PromptKind.direction(toleranceDegrees: 10)
        #expect(kind.isMatch(.heading(358), .heading(2)))
    }

    @Test func directionRejectsBeyondTolerance() {
        let kind = PromptKind.direction(toleranceDegrees: 10)
        #expect(!kind.isMatch(.heading(0), .heading(90)))
    }
}
