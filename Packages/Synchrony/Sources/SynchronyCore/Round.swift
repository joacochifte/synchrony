/// One prompt and the two players' answers to it. Slots are named `answerOne`
/// / `answerTwo` rather than "host"/"peer" on purpose — the domain layer has
/// no concept of network roles, only two symmetric cooperating players.
public struct Round: Equatable, Sendable {
    public let prompt: Prompt
    public var answerOne: AnswerValue?
    public var answerTwo: AnswerValue?

    public init(prompt: Prompt, answerOne: AnswerValue? = nil, answerTwo: AnswerValue? = nil) {
        self.prompt = prompt
        self.answerOne = answerOne
        self.answerTwo = answerTwo
    }

    public var isComplete: Bool {
        answerOne != nil && answerTwo != nil
    }

    /// `nil` until both answers are in; then whether they matched under
    /// the prompt's own criterion.
    public var isSynchronized: Bool? {
        guard let answerOne, let answerTwo else { return nil }
        return prompt.kind.isMatch(answerOne, answerTwo)
    }
}
