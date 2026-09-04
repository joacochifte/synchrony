# Synchrony

A cooperative two-player game for iPhone: no server, no accounts, no internet. Two devices discover each other over the local network and play a round of shared prompts, answering in secret and revealing at the same instant.

> 🚧 Work in progress. This README will grow with each phase — see [Project status](#project-status) below.

## Project status

**Phase 4 — Game engine.** `SynchronyCore` now has `MatchEngine` (the answering → revealing → next-round state machine and sync scoring), a bundled 40-prompt deck in Rioplatense Spanish loaded via `DeckLoader`, and deterministic round selection. No transport or UI yet — the engine has no idea how answers get to it.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branching model, commit convention, and how to run tests, lint, and format locally.

## Architecture

```mermaid
graph TD
    App["Synchrony (app shell)"] --> UI[SynchronyUI]
    UI --> Core[SynchronyCore]
    UI --> Transport[SynchronyTransport]
    UI --> Persistence[SynchronyPersistence]
    Transport --> Core
    Persistence --> Core
```

- **SynchronyCore** — domain models, game engine, match state machine. No UIKit/SwiftUI/MultipeerConnectivity imports; pure and fully testable.
- **SynchronyTransport** — the `GameTransport` protocol plus a real `MultipeerTransport` and an `InMemoryTransport` for tests and previews.
- **SynchronyPersistence** — SwiftData models and repository for local match history.
- **SynchronyUI** — SwiftUI views and view models.
- **Synchrony (app target)** — composition root, entry point, Info.plist, assets.

Architecture decisions are recorded in [`docs/adr/`](docs/adr):

- [0001 — Record architecture decisions](docs/adr/0001-record-architecture-decisions.md)
- [0002 — One local SPM package with four targets](docs/adr/0002-local-spm-package-structure.md)
- [0003 — Closed enum for PromptKind](docs/adr/0003-prompt-kind-closed-enum.md)

## Building

Requirements: Xcode 16.4+, iOS 17.0 simulator or device.

```bash
git clone https://github.com/joacochifte/synchrony.git
cd synchrony
open Synchrony.xcodeproj
```

Select the `Synchrony` scheme and run on an iPhone simulator (⌘R). No manual configuration steps.

To run the package's own test suite directly:

```bash
swift test --package-path Packages/Synchrony
```

## Known limitations

- No gameplay yet — this phase only sets up the project structure.
- MultipeerConnectivity requires two physical devices (or a device + simulator, with caveats) to test peer discovery; this can't run in CI.

## License

[MIT](LICENSE)
