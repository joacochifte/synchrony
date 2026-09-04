# 3. Closed enum for PromptKind, matching encapsulated on the type itself

## Status

Accepted

## Context and Problem Statement

The game supports four prompt types today (numeric, multiple choice, free text, direction) and is meant to grow more later. The spec requires that adding a new prompt type not require touching the game engine — the state machine that drives a match through its rounds. Swift offers two natural ways to model "a prompt kind with its own answer shape and matching rule": a closed enum with a switch-based matching method, or an open protocol with type erasure so new kinds can be added from outside the module.

## Decision Drivers

- Adding a prompt kind should mean editing one place, not the engine.
- The prompt deck is loaded from a single JSON file bundled with the app (Phase 4) — there is no plugin system and no reason to expect third-party prompt kinds.
- This is a solo project in a first Swift codebase; a design has to be defensible to a senior reviewer, but doesn't need to solve for extensibility no one asked for.

## Considered Options

- **Open protocol + type erasure**: each prompt kind is its own type conforming to a `MatchCriterion` protocol; a type-erasing wrapper (`AnyPrompt`) and a runtime registry decode prompts from JSON by dispatching on a string discriminator. True open/closed compliance — a new kind can be added without recompiling this module.
- **Closed enum, matching encapsulated on the type**: `PromptKind` is a `Codable` enum with one case per kind; `isMatch(_:_:)` is a method on the enum itself, switching over `self`. The engine calls `prompt.kind.isMatch(answerA, answerB)` and never inspects which case it got.

## Decision Outcome

Chosen option: "closed enum, matching encapsulated on the type", because the actual requirement is that the **engine** stay ignorant of prompt-kind specifics, not that the **type itself** be open to extension from outside the module — nothing in this project loads prompt kinds from outside `SynchronyCore`. The protocol/type-erasure approach solves a problem this codebase doesn't have (external, dynamically-loaded prompt kinds) at the cost of real complexity: an existential wrapper, a type registry, and non-trivial heterogeneous JSON decoding, for four cases that are all known upfront.

With the closed enum, adding a fifth prompt kind means: add a case to `PromptKind`, add a branch to `isMatch(_:_:)`, add a case to `AnswerValue` if its answer shape doesn't already exist. Nothing under `Sources/SynchronyCore` outside `PromptKind.swift` changes, and nothing outside `SynchronyCore` changes at all.

If prompt kinds ever need to come from outside this module — a plugin system, a server-driven prompt catalog — that is grounds to revisit this decision, not a sign it was wrong for the problem at hand.
