import Foundation

/// Loads the prompt deck from JSON — the bundled default deck, or arbitrary
/// data for tests and any future custom decks.
public enum DeckLoader: Sendable {

    public enum LoadError: Error, Equatable, Sendable {
        case bundledResourceNotFound
        case duplicatePromptID(String)
    }

    /// Decodes prompts from raw JSON `Data`, rejecting duplicate IDs — a
    /// duplicate is a content bug, not something the caller should have to
    /// guard against downstream.
    public static func loadPrompts(from data: Data) throws -> [Prompt] {
        let prompts = try JSONDecoder().decode([Prompt].self, from: data)

        var seenIDs: Set<String> = []
        for prompt in prompts {
            guard seenIDs.insert(prompt.id).inserted else {
                throw LoadError.duplicatePromptID(prompt.id)
            }
        }

        return prompts
    }

    /// Loads the deck shipped inside `SynchronyCore`'s resource bundle.
    public static func loadBundledDeck() throws -> [Prompt] {
        guard let url = Bundle.module.url(forResource: "prompts", withExtension: "json") else {
            throw LoadError.bundledResourceNotFound
        }
        let data = try Data(contentsOf: url)
        return try loadPrompts(from: data)
    }

    /// Picks `count` prompts at random from `deck`, without repeats.
    /// Injecting the generator keeps this deterministic in tests; real
    /// callers can use the overload below.
    public static func selectRound<Generator: RandomNumberGenerator>(
        from deck: [Prompt],
        count: Int,
        using generator: inout Generator
    ) -> [Prompt] {
        Array(deck.shuffled(using: &generator).prefix(count))
    }

    public static func selectRound(from deck: [Prompt], count: Int = 10) -> [Prompt] {
        var generator = SystemRandomNumberGenerator()
        return selectRound(from: deck, count: count, using: &generator)
    }
}
