import Testing

@testable import SynchronyCore

@Suite struct TextNormalizerTests {

    @Test func normalizeLowercases() {
        #expect(TextNormalizer.normalize("Milanesa") == "milanesa")
    }

    @Test func normalizeStripsAccents() {
        #expect(TextNormalizer.normalize("café") == "cafe")
        #expect(TextNormalizer.normalize("Ñoquis") == "noquis")
    }

    @Test func normalizeCollapsesWhitespace() {
        #expect(TextNormalizer.normalize("  hola   mundo  ") == "hola mundo")
    }

    @Test func normalizeMakesAccentedAndPlainTextEqual() {
        #expect(TextNormalizer.normalize("Milanesa Napolitana") == TextNormalizer.normalize("milanesa napolitana"))
    }

    @Test func levenshteinDistanceOfIdenticalStringsIsZero() {
        #expect(TextNormalizer.levenshteinDistance("gato", "gato") == 0)
    }

    @Test func levenshteinDistanceOfEmptyStringIsTheOtherLength() {
        #expect(TextNormalizer.levenshteinDistance("", "abc") == 3)
        #expect(TextNormalizer.levenshteinDistance("abc", "") == 3)
    }

    @Test func levenshteinDistanceOfSingleSubstitution() {
        #expect(TextNormalizer.levenshteinDistance("gato", "pato") == 1)
    }

    @Test func levenshteinDistanceClassicExample() {
        #expect(TextNormalizer.levenshteinDistance("kitten", "sitting") == 3)
    }
}
