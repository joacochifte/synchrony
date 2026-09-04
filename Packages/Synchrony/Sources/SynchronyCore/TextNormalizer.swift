import Foundation

/// Normalizes and compares free-text answers so that trivial differences in
/// casing, accents, or spacing don't count as a desync.
public enum TextNormalizer: Sendable {

    /// Lowercases, strips diacritics, and collapses whitespace: "Milanesa " and
    /// "milanesa" normalize to the same string, but "Milanesa" and "Ensalada"
    /// still don't.
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let trimmed = folded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Levenshtein edit distance between two strings, computed with a
    /// two-row dynamic programming table (no need to keep the full grid).
    public static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)

        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previousRow = Array(0...b.count)
        var currentRow = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            currentRow[0] = i
            for j in 1...b.count {
                let substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1
                currentRow[j] = Swift.min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + substitutionCost
                )
            }
            previousRow = currentRow
        }

        return previousRow[b.count]
    }
}
