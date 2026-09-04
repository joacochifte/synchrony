/// What kind of prompt this is, what its matching rule looks like, and
/// (where relevant) the data the UI needs to render an input for it.
///
/// Adding a new prompt kind means adding a case here and a branch in
/// `isMatch(_:_:)` — nothing in the game engine has to change, since the
/// engine only ever calls `prompt.kind.isMatch(answerA, answerB)` without
/// knowing which case it got. See ADR-0003.
///
/// No `Codable` conformance here: an auto-synthesized enum-with-associated-
/// values encoding nests every field under its case name, which is an ugly,
/// Swift-internal-shaped JSON to hand-author 40 prompts in. `Prompt` encodes
/// and decodes this data as flat, human-readable fields instead — see its
/// custom `Codable` implementation.
public enum PromptKind: Equatable, Sendable {
    /// Exact match, or within `tolerance` of each other.
    case numeric(range: ClosedRange<Int>, tolerance: Int)

    /// Exact match on the chosen option.
    case multipleChoice(options: [String])

    /// Match if the normalized Levenshtein distance is at or below
    /// `levenshteinThreshold`. 2 is a reasonable default for short answers:
    /// it forgives typos and minor spelling variants without accepting a
    /// genuinely different word.
    case freeText(levenshteinThreshold: Int)

    /// Match if the two headings are within `toleranceDegrees` of each
    /// other, measured the short way around the compass.
    case direction(toleranceDegrees: Double)
}

extension PromptKind {
    /// Whether two answers to a prompt of this kind count as synchronized.
    /// Answers of the wrong shape for this kind (a programming error, not a
    /// game state) are treated as not matching rather than trapping.
    public func isMatch(_ lhs: AnswerValue, _ rhs: AnswerValue) -> Bool {
        switch self {
        case .numeric(_, let tolerance):
            guard case .number(let a) = lhs, case .number(let b) = rhs else { return false }
            return abs(a - b) <= tolerance

        case .multipleChoice:
            guard case .choice(let a) = lhs, case .choice(let b) = rhs else { return false }
            return a == b

        case .freeText(let threshold):
            guard case .text(let a) = lhs, case .text(let b) = rhs else { return false }
            let distance = TextNormalizer.levenshteinDistance(
                TextNormalizer.normalize(a),
                TextNormalizer.normalize(b)
            )
            return distance <= threshold

        case .direction(let tolerance):
            guard case .heading(let a) = lhs, case .heading(let b) = rhs else { return false }
            return AngularMath.difference(a, b) <= tolerance
        }
    }
}
