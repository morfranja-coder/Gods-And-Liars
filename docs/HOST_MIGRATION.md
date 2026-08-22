# Gods & Liars — Host Migration

## Goal

A match should survive the departure or crash of the current game host whenever a valid successor can take authority.

Host migration is split into small gates so networking changes do not land before the authoritative state can be reproduced safely.

## 3A — Serializable authoritative match snapshot

`MatchSnapshot` is the versioned, transport-independent representation of the authoritative Mafia match state.

Current schema version: `1`.

The snapshot includes:

- exact 8-player identity set (`peer_id`, `steam_id`, display name);
- deterministic seat assignment;
- each secret role;
- alive/dead state;
- per-player ready/selected/vote target state;
- current match phase;
- round number;
- remaining phase time in milliseconds, never the previous host's absolute monotonic clock;
- public winner state;
- whether roles were already dispatched;
- role-reveal acknowledgements;
- accepted Heretic targets;
- accepted Healer target;
- accepted Inquisitor target;
- votes already received.

The snapshot can round-trip through a plain `Dictionary` or JSON and reconstruct a `MatchSession` without rerolling roles.

Validation rejects:

- unsupported schema versions;
- invalid phases or negative timing;
- anything other than exactly 8 players;
- invalid/duplicate peer IDs, Steam IDs or seats;
- invalid role values.

## Security rule

A full `MatchSnapshot` contains the complete secret role map. It must **not** be replicated to every player.

Future gate 3C will assign one trusted successor/backup authority and send the authoritative snapshot only to that successor. Normal clients continue to receive only the private information they are allowed to know.

## Timing rule

The snapshot stores `phase_remaining_ms`, not `Time.get_ticks_msec()` from the current host. A successor will create a new local deadline from its own monotonic clock after promotion. This avoids comparing clocks from different machines.

## 3A exit gate

3A is complete when:

- snapshot creation is deterministic and versioned;
- JSON/dictionary round-trip preserves authoritative state;
- `MatchSession` restoration preserves roles and player state;
- malformed/incompatible snapshots are rejected;
- CI stays green.

Network transport, successor election and automatic promotion are intentionally outside 3A.
