/// A single prompt shown to both players in a round.
public struct Prompt: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let kind: PromptKind

    public init(id: String, text: String, kind: PromptKind) {
        self.id = id
        self.text = text
        self.kind = kind
    }
}
