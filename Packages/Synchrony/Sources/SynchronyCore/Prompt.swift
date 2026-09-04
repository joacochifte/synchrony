/// A single prompt shown to both players in a round.
///
/// `Codable` is hand-written rather than synthesized: the wire format is a
/// flat JSON object — `id`, `text`, a `type` discriminator, and that type's
/// own fields at the top level — which is both what the bundled deck file
/// uses and what travels over the wire between devices. See `PromptKind`
/// for why this isn't a nested, per-case encoding instead.
public struct Prompt: Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let kind: PromptKind

    public init(id: String, text: String, kind: PromptKind) {
        self.id = id
        self.text = text
        self.kind = kind
    }
}

extension Prompt: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, text, type, min, max, tolerance, options, levenshteinThreshold, toleranceDegrees
    }

    private enum Kind: String, Codable {
        case numeric, multipleChoice, freeText, direction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let text = try container.decode(String.self, forKey: .text)
        let type = try container.decode(Kind.self, forKey: .type)

        let kind: PromptKind
        switch type {
        case .numeric:
            let min = try container.decode(Int.self, forKey: .min)
            let max = try container.decode(Int.self, forKey: .max)
            guard min <= max else {
                throw DecodingError.dataCorruptedError(
                    forKey: .max,
                    in: container,
                    debugDescription: "min (\(min)) must be <= max (\(max)) for prompt '\(id)'"
                )
            }
            let tolerance = try container.decode(Int.self, forKey: .tolerance)
            kind = .numeric(range: min...max, tolerance: tolerance)

        case .multipleChoice:
            let options = try container.decode([String].self, forKey: .options)
            kind = .multipleChoice(options: options)

        case .freeText:
            let threshold = try container.decode(Int.self, forKey: .levenshteinThreshold)
            kind = .freeText(levenshteinThreshold: threshold)

        case .direction:
            let tolerance = try container.decode(Double.self, forKey: .toleranceDegrees)
            kind = .direction(toleranceDegrees: tolerance)
        }

        self.init(id: id, text: text, kind: kind)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)

        switch kind {
        case .numeric(let range, let tolerance):
            try container.encode(Kind.numeric, forKey: .type)
            try container.encode(range.lowerBound, forKey: .min)
            try container.encode(range.upperBound, forKey: .max)
            try container.encode(tolerance, forKey: .tolerance)

        case .multipleChoice(let options):
            try container.encode(Kind.multipleChoice, forKey: .type)
            try container.encode(options, forKey: .options)

        case .freeText(let threshold):
            try container.encode(Kind.freeText, forKey: .type)
            try container.encode(threshold, forKey: .levenshteinThreshold)

        case .direction(let tolerance):
            try container.encode(Kind.direction, forKey: .type)
            try container.encode(tolerance, forKey: .toleranceDegrees)
        }
    }
}
