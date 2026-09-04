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

    public init(promptID: String, promptText: String, wasSynchronized: Bool) {
        self.promptID = promptID
        self.promptText = promptText
        self.wasSynchronized = wasSynchronized
    }
}
