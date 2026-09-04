# 6. MultipeerConnectivity for peer-to-peer transport

## Status

Accepted

## Context and Problem Statement

Synchrony needs two iPhones in the same room to find each other and exchange messages directly — no server, no internet, no accounts, no codes to type in. iOS offers a few ways to build this.

## Decision Drivers

- No third-party runtime dependencies (spec requirement).
- No account or server of any kind — the spec explicitly rules out logins.
- Discovery has to be automatic: one device creates a game, the other finds it on the local network without either player typing an address.
- The chosen approach has to fit inside `SynchronyTransport` behind `GameTransport` cleanly — see ADR-0007.

## Considered Options

- **MultipeerConnectivity**: Apple's framework for exactly this — spontaneous, serverless peer-to-peer sessions between nearby devices, with built-in advertising, browsing, invitation, encryption, and message passing.
- **Raw Bonjour (`Network` framework: `NWListener`/`NWBrowser`) + manual TCP sockets**: lower-level, full control, but means hand-rolling service discovery, connection setup, and message framing over a raw byte stream — solving a problem MultipeerConnectivity already solves.
- **GameKit peer-to-peer matching**: superseded by MultipeerConnectivity for local sessions years ago; GameKit today is oriented around Game Center online matchmaking, which requires a signed-in Game Center account — directly conflicting with "no accounts."

## Decision Outcome

Chosen option: "MultipeerConnectivity," because it's the framework Apple built specifically for this scenario, it's a system framework (no third-party dependency), it needs no account or server, and its `MCNearbyServiceAdvertiser`/`MCNearbyServiceBrowser`/`MCSession` trio maps directly onto the product's "one device hosts, one joins, no codes" pairing flow.

Trade-off accepted: it's an iOS/macOS-only framework and a comparatively high-level abstraction with less control over the exact wire behavior than raw sockets would give. Neither cost matters here — the project targets iOS exclusively, and the message-passing needs (a handful of small JSON payloads per round) don't need that level of control. See ADR-0007 for how this stays fully isolated from the game engine, and [MultipeerTransport.swift](../../Packages/Synchrony/Sources/SynchronyTransport/MultipeerTransport.swift) for the implementation.
