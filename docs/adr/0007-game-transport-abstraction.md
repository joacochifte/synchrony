# 7. GameTransport as the only network abstraction the engine sees

## Status

Accepted

## Context and Problem Statement

The spec's critical requirement: `SynchronyCore`'s game engine must never import MultipeerConnectivity, and the entire test suite has to run without devices or network. That means something has to sit between the engine and the real network, and it has to be designed in from the start rather than retrofitted.

## Decision Drivers

- Zero MultipeerConnectivity (or any concrete transport) references outside `SynchronyTransport`.
- Swap the real transport for a fake one without touching engine or UI code.
- Fit Swift 6 structured concurrency idiomatically, since the whole codebase is built on it.
- SwiftUI previews need to show real interaction (a peer that actually responds) without a device.

## Considered Options

- **A narrow, ad hoc protocol** exposing just what the engine happens to need at the time (e.g. `sendData(_:)` with no typed message shape) — minimal upfront design, but pushes message encoding/decoding and connection-state handling out to every caller, and tends to grow ad hoc extensions over time.
- **`GameTransport`: a typed protocol over `AsyncStream`** — `connectionState` and `incomingMessages` as streams, `send(_:)` as an async throwing call taking the typed `GameMessage` enum directly, `disconnect()` to end things explicitly. Two conformers: `MultipeerTransport` (real) and `InMemoryTransport` (an in-process loopback pair for tests and previews).

## Decision Outcome

Chosen option: "`GameTransport` over `AsyncStream`." A typed protocol keeps `GameMessage`'s shape (see ADR-0008) as the one thing that crosses the boundary, instead of raw `Data` that every caller would have to encode/decode themselves. `AsyncStream` composes directly with `for await` loops and SwiftUI's `.task`, matching how the rest of the codebase is written, and — critically — it's exactly expressive enough to build `InMemoryTransport`: two instances wired together so sending on one delivers straight into the other's `incomingMessages`, no sockets involved.

That single design decision is what makes three things possible at once:
- `MatchEngine` and the whole game flow are testable purely in-process (`EndToEndMatchTests`, `GameCoordinatorTests`).
- SwiftUI previews can show a screen mid-conversation with a scripted "opponent" on the other end of a real (if fake) connection, not just a static fixture.
- Swapping `MultipeerTransport` in for real device use required zero changes to `SynchronyCore` or the view layer — only `GameCoordinator`'s `hostGame`/`joinGame` construct the concrete type.

One real constraint this surfaced: `AsyncStream` only supports one genuine consumer. `GameCoordinator` reads `incomingMessages` in a single loop and dispatches every `GameMessage` case from there — `ClockSyncCoordinator` doesn't read the stream itself, it receives forwarded messages via `receive(_:)` instead. See the commit history on `ClockSyncCoordinator` for how that was found and fixed.
