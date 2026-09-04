/// The answer a player gives to a prompt. One case per `PromptKind`, kept in
/// a single enum so `Round` can hold two answers of the same shape without
/// generics.
public enum AnswerValue: Codable, Equatable, Sendable {
    case number(Int)
    case choice(String)
    case text(String)
    case heading(Double)
}
