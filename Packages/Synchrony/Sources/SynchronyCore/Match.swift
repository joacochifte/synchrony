/// A full game session: an ordered sequence of rounds. This is a plain data
/// container in this phase — the state machine that drives it through
/// waiting/answering/revealing states arrives with the game engine.
public struct Match: Equatable, Sendable {
    public let id: String
    public var rounds: [Round]

    public init(id: String, rounds: [Round] = []) {
        self.id = id
        self.rounds = rounds
    }
}
