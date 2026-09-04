# Contributing to Synchrony

This is a solo portfolio project, but it follows a real process on purpose: the repository is meant to demonstrate how the work is done, not just what got built.

## Branching model

- `main` — always compilable. Only updated by merging `dev` at a release.
- `dev` — integration branch. Feature work merges here first.
- `feat/…`, `fix/…`, `docs/…`, `chore/…` — one branch per unit of work, cut from `dev`.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), strictly:

```
<type>(<scope>): <summary>

<body — explains why, not what>
```

- One commit, one logical change. Don't mix a refactor with a new feature in the same commit.
- The body explains the reasoning behind the change, not a restatement of the diff.
- No `wip`, `fixes`, or `misc changes` commits.

Types in use: `feat`, `fix`, `docs`, `chore`, `test`, `refactor`.

## Architecture decisions

A choice with more than one reasonable option and real cost to reverse gets an ADR in [`docs/adr/`](docs/adr), in [MADR](https://adr.github.io/madr/) format, added in the same commit that implements the decision. See [ADR-0001](docs/adr/0001-record-architecture-decisions.md) for the full rationale.

## Running tests locally

```bash
# Package unit tests (SynchronyCore, SynchronyTransport, SynchronyPersistence, SynchronyUI)
swift test --package-path Packages/Synchrony

# Full app build for the simulator, same invocation CI uses
xcodebuild build \
  -project Synchrony.xcodeproj -scheme Synchrony \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## Lint and format

```bash
swiftlint lint --strict
swift-format lint --recursive --strict Synchrony SynchronyTests SynchronyUITests Packages/Synchrony/Sources Packages/Synchrony/Tests
swift-format format --recursive --in-place Synchrony SynchronyTests SynchronyUITests Packages/Synchrony/Sources Packages/Synchrony/Tests
```

CI runs both tools in check mode and fails the build on any violation.
