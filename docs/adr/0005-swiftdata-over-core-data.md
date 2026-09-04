# 5. SwiftData over Core Data for local persistence

## Status

Accepted

## Context and Problem Statement

Synchrony needs to persist match history locally, on-device, with no sync and no server. Apple offers two frameworks for this on iOS 17+: Core Data, mature and battle-tested since iOS 3, and SwiftData, introduced in iOS 17 as a Swift-native layer that can sit directly on top of Core Data's storage engine.

## Decision Drivers

- The project's technical requirements fix Swift 6 strict concurrency and SwiftUI idioms throughout — the persistence layer shouldn't be the one place that falls back to Objective-C-era patterns.
- This is a small, single-entity-graph local store (matches and their rounds) with no need for Core Data's more advanced features: no CloudKit sync, no complex migrations, no `NSFetchedResultsController`-driven table views.
- Portfolio value: SwiftData is what a senior iOS reviewer would expect a project started in 2026, targeting iOS 17+, to reach for by default.

## Considered Options

- **Core Data**: `.xcdatamodeld` visual schema editor, `NSManagedObject` subclasses, `NSFetchRequest`. Deepest feature set and the longest track record, but its concurrency model (`NSManagedObjectContext` queues, `perform`/`performAndWait`) predates Swift concurrency and doesn't map onto `async`/`await` and actor isolation without a translation layer.
- **SwiftData**: `@Model` macro-generated persistent classes, `ModelContainer`/`ModelContext`, `FetchDescriptor`. Schema is plain Swift types instead of a separate visual editor artifact, and the API surface is designed around Swift concurrency from the start.

## Decision Outcome

Chosen option: "SwiftData," because the project's data needs are simple enough that none of Core Data's extra maturity is actually load-bearing here, while SwiftData's concurrency model is a direct fit for a codebase already built around Swift 6 strict concurrency everywhere else. `@Model` classes (`MatchRecord`, `RoundRecord`) stay out of `SynchronyCore` entirely — they live in `SynchronyPersistence`, translated to and from the pure domain types in `SynchronyCore.Match`/`Round` at the boundary, so the game engine has no framework dependency on how (or whether) a match ends up on disk.

Trade-off accepted: SwiftData is younger and has rougher edges than Core Data in places (schema migration tooling is less mature, some Core Data features have no SwiftData equivalent yet). None of those gaps affect this project's actual requirements, and `@Model` types are still backed by Core Data under the hood, so a future migration to raw Core Data — if some gap ever became load-bearing — would not mean starting over.

That trade-off wasn't hypothetical: building `GameCoordinator`'s full-match test (Phase 8) surfaced two real SwiftData rough edges, both silent or unhelpfully-reported failures rather than clear ones:

- Building a `MatchHistoryRepository` from `container.mainContext` without keeping the `ModelContainer` itself alive anywhere let ARC collect the container mid-match, well after construction — `ModelContext` doesn't retain its owning container. The failure was a bare `EXC_BREAKPOINT` deep inside SwiftData/CoreData with no message, and it was flaky (short synchronous tests happened not to trigger it; a ten-round async match reliably did), which made it look at first like a concurrency bug rather than a lifetime one.
- `MatchRecord.rounds` declared a cascading relationship with no inverse on `RoundRecord`. This "worked" until a save actually hit a merge conflict, then crashed with `NSInternalInconsistencyException: "... does not have an inverse"` — a clear message, but only once the object-lifetime bug above stopped intermittently masking it.

Both are now fixed (`MatchHistoryRepository` stores the container; `RoundRecord.match` is the declared inverse) and covered by `GameCoordinatorTests`, run 12 times consecutively with zero failures as the fix's actual verification, since a single green run doesn't rule out this kind of intermittent, lifetime-dependent bug.
