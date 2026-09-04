# 8. JSONEncoder over PropertyListEncoder for GameMessage

## Status

Accepted

## Context and Problem Statement

`GameMessage` values have to become `Data` to travel over `MCSession.send(_:toPeers:with:)`, and back into `GameMessage` on the receiving end. Swift's `Codable` supports this through more than one encoder.

## Decision Drivers

- Messages are small (a handful of fields, at most one `Prompt` with a short options list) and sent infrequently (roughly one per round, plus a handful of clock-sync pings) — this is not a throughput- or latency-sensitive path.
- This is a first Swift networking project; being able to inspect what actually went over the wire while debugging MultipeerConnectivity matters more than shaving bytes.
- No third-party dependencies, so the choice is between what `Foundation` already ships.

## Considered Options

- **`JSONEncoder`/`JSONDecoder`**: text-based, human-readable, slightly larger payload, trivial to log or print for debugging.
- **`PropertyListEncoder`** (binary plist format): more compact and typically faster to encode/decode, but opaque without a decoder on hand — can't eyeball a captured payload.

## Decision Outcome

Chosen option: "`JSONEncoder`," because at this message size and frequency the compactness and speed advantage of a binary plist is not something this app would ever notice, while JSON's readability is a real, repeated benefit while building and debugging `MultipeerTransport` — being able to `print(String(data: data, encoding: .utf8))` a message and read it directly is worth more here than the bytes saved. `GameMessage`'s own `Codable` conformance doesn't care which encoder is used on top of it, so this is free to revisit later without touching the message type itself if it ever became load-bearing.
