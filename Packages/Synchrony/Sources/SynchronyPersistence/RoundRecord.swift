import SwiftData

/// One round within a persisted `MatchRecord`. Keeps the prompt's text (for
/// a readable history screen) and whether the round synced — not the raw
/// answers. Nothing in the spec calls for replaying past answers, and
/// there's no reason to hold onto more of a couple's private answers than
/// the feature actually needs.
@Model
public final class RoundRecord {
    public var promptID: String
    public var promptText: String
    public var wasSynchronized: Bool

    /// The owning match. SwiftData needs both sides of a to-many
    /// relationship declared — `MatchRecord.rounds` names this property as
    /// its inverse — or it can't resolve merge conflicts and crashes with
    /// "does not have an inverse" the first time one actually occurs.
    public var match: MatchRecord?

    public init(promptID: String, promptText: String, wasSynchronized: Bool) {
        self.promptID = promptID
        self.promptText = promptText
        self.wasSynchronized = wasSynchronized
    }
}
