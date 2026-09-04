# Synchrony

A cooperative two-player game for iPhone: no server, no accounts, no internet. Two devices discover each other over the local network and play a round of shared prompts, answering in secret and revealing at the same instant.

> 🚧 Work in progress. This README will grow with each phase — see [Project status](#project-status) below.

## Project status

**Phase 8 — UI.** `SynchronyUI` now has `GameCoordinator` — the composition root tying the game engine, transport, and persistence together into an actual playable match — and all seven screens (home, pairing, prompt, reveal, summary, history). The app builds and runs end to end for the first time. See [ADR-0005](docs/adr/0005-swiftdata-over-core-data.md) for two real SwiftData bugs this phase's full-match test caught.

## Simultaneous synchronization

```mermaid
sequenceDiagram
    participant Host
    participant Peer

    Host->>Peer: handshake(protocolVersion)
    Peer-->>Host: handshakeAccepted

    loop 8 samples
        Host->>Peer: clockSyncPing(seq, sentAtNanos: t0)
        Note over Peer: t2 = own clock at reply time
        Peer-->>Host: clockSyncPong(seq, pingSentAtNanos: t0, pongSentAtNanos: t2)
        Note over Host: t3 = own clock at receipt<br/>sample = (t0, t3, t2)
    end

    Note over Host: discard slowest 25% by round-trip time<br/>offset = median(estimatedOffset per sample)

    Host->>Peer: roundStart(prompt, showAtNanos: T)
    Note over Host: shows prompt locally at T (own clock)
    Note over Peer: shows prompt locally at T − offset

    Note over Host,Peer: both players answer independently

    Host->>Peer: answer(hostAnswer)
    Peer-->>Host: answer(peerAnswer)

    Host->>Peer: reveal(revealAtNanos: T2)
    Note over Host,Peer: both reveal the already-exchanged<br/>answers at their translated instant

    Host->>Peer: matchEnd(syncPercentage)
```

Full rationale in [ADR-0004](docs/adr/0004-clock-synchronization-mechanism.md).

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
- [0004 — Clock synchronization mechanism](docs/adr/0004-clock-synchronization-mechanism.md)
- [0005 — SwiftData over Core Data](docs/adr/0005-swiftdata-over-core-data.md)

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

- `MultipeerTransport` compiles and is exercised by `GameCoordinator`'s full-match test over `InMemoryTransport`, but real MultipeerConnectivity peer discovery needs two physical devices (or a device + simulator, with caveats); this can't run in CI, which is why `ClockOffsetEstimator` — the one piece of the sync mechanism that's pure math — is what's actually unit tested, with synthetic samples.
- Direction prompts use a plain 0–359° slider rather than a real compass reading — CoreLocation sensing is device-only and can't be exercised in a preview or CI, and wiring it in doesn't change anything about the domain layer or protocol.
- No accessibility labels, Dynamic Type verification, or es/en localization yet — that's Phase 9.
- Building against MultipeerConnectivity emits Swift 6 concurrency warnings from Apple's own (not-yet-Sendable-audited) SDK, silenced at the import boundary with `@preconcurrency` — expected, not a bug in this code.

## License

[MIT](LICENSE)
