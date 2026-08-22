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

Gate 3C assigns one trusted successor/backup authority and sends the authoritative snapshot only to that successor. Normal clients continue to receive only the private information they are allowed to know.

## Timing rule

The snapshot stores `phase_remaining_ms`, not `Time.get_ticks_msec()` from the current host. A successor will create a new local deadline from its own monotonic clock after promotion. This avoids comparing clocks from different machines.

## 3A exit gate

3A is complete when:

- snapshot creation is deterministic and versioned;
- JSON/dictionary round-trip preserves authoritative state;
- `MatchSession` restoration preserves roles and player state;
- malformed/incompatible snapshots are rejected;
- CI stays green.

## 3B — Deterministic successor election

`HostSuccessorRules` selects the next game host without depending on transient Godot peer IDs.

Canonical rules:

- the current host is always excluded;
- candidates must have a valid positive SteamID;
- connected living players are preferred;
- among living candidates, the lowest SteamID wins;
- if no living candidate exists, connected dead/spectator players are allowed as fallback and the lowest SteamID wins;
- if no candidate exists, successor SteamID is `0` and migration must fall back safely;
- `peer_id` is never used as the election tie-break because peer IDs may change while the multiplayer transport is reconstructed.

The rule is intentionally transport-independent. Steam lobby ownership transfer, backup snapshot delivery and transport recreation happen in later gates.

## 3B exit gate

3B is complete when:

- every client supplied the same roster/alive state chooses the same successor SteamID;
- current host exclusion is tested;
- player insertion order and peer ID values do not affect the winner;
- living candidates outrank dead candidates;
- dead candidates provide a deterministic fallback;
- invalid Steam IDs are ignored;
- CI stays green.

## Next gates

- 3C — backup authority and secret snapshot replication to the elected successor only;
- 3D — voluntary Steam lobby ownership transfer;
- 3E — unexpected host-loss recovery;
- 3F — recreate `SteamMultiplayerPeer`;
- 3G — reconnect remaining peers;
- 3H — restore snapshot and resume phase/deadline;
- 3I — safe fallback when migration cannot complete.
