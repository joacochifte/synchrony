# 1. Record architecture decisions

## Status

Accepted

## Context and Problem Statement

Synchrony has to work as a functioning app and as a portfolio piece read by senior engineers who will not see the reasoning behind non-obvious choices unless it is written down somewhere. Commit messages capture the *what*; they are a poor place for the *why* behind a decision with real trade-offs, or for a record of the alternatives that were considered and rejected.

## Decision Drivers

- A senior developer reading the repo needs to find the reasoning behind a decision without archaeology through commit history.
- Decisions with more than one reasonable option should not be made silently.
- The record should stay close to the code it describes, versioned in the same repository.

## Considered Options

- No formal record — reasoning lives only in commit messages and PR descriptions.
- A single `ARCHITECTURE.md` document, prose-only.
- Architecture Decision Records (ADRs) in [MADR](https://adr.github.io/madr/) format, one file per decision, numbered sequentially.

## Decision Outcome

Chosen option: "Architecture Decision Records in MADR format", because it keeps each decision self-contained, dated, and immutable once accepted — superseding a decision means adding a new ADR that links back to the old one, not editing history. Records live in `docs/adr/`, numbered sequentially, starting with this one.

A decision earns an ADR when it has more than one reasonable option and reversing it later would be expensive. Routine implementation choices do not need one.
