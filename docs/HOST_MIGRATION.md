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

## 3C — Backup authority

`HostMigrationManager` owns the secret backup copy used by later migration gates.

Rules:

- the current host chooses the initial backup using the 3B successor rule;
- the selected backup SteamID is public session metadata so every client knows the intended successor;
- the complete secret snapshot remains private and is sent only to the selected backup;
- once selected, the backup remains fixed while that Steam identity is still connected, even if that player dies in-game;
- a replacement backup is elected only if the current backup disconnects;
- this minimizes how many clients ever receive the complete secret role map;
- the host captures a `MatchSnapshot` at most every 250 ms and sends only when the serialized authoritative state changed;
- snapshots are delivered by reliable authority RPC only to the elected backup peer;
- each snapshot carries a monotonically increasing sequence number;
- stale or duplicate sequences are ignored;
- the receiver validates both the intended SteamID and the complete `MatchSnapshot` before storing it;
- non-selected clients never receive the snapshot RPC;
- lobby/session teardown clears stored backup state.

The backup snapshot is passive in 3C. It does not yet promote the client, recreate networking or restore authority. Those actions belong to 3D–3H.

## 3C exit gate

3C is complete when:

- the current backup remains stable while connected;
- disconnecting it deterministically elects a replacement;
- only the intended Steam identity accepts a backup snapshot;
- malformed and stale snapshots cannot replace the stored backup;
- the latest valid backup can be queried locally for later promotion;
- CI stays green.

## 3D — Voluntary Steam lobby ownership transfer

Before an active host voluntarily exits, `HostMigrationManager.request_voluntary_host_exit()` transfers Steam lobby ownership to the already-selected backup authority.

Safety gates:

- only the current multiplayer server/host may request the transfer;
- Steam must be initialized and expose `setLobbyOwner`;
- the backup SteamID must be different from the current host;
- the backup peer must still exist in the authoritative roster and map to the selected SteamID;
- the backup must already hold a valid complete `MatchSnapshot`;
- if any prerequisite fails, the transfer is rejected and the host remains in the lobby;
- if Steam rejects `setLobbyOwner`, the host remains in the lobby;
- only after Steam reports successful ownership transfer does the departing host leave its current lobby/transport.

This gate transfers the Steam lobby owner deterministically but does not yet keep the gameplay transport alive. Clients will still observe the old `SteamMultiplayerPeer` disappearing until gates 3E–3G recreate the transport and reconnect them.

## 3D exit gate

3D is complete when:

- invalid/missing backup state blocks voluntary transfer;
- a valid connected backup passes the transfer gate;
- current host cannot select itself;
- Steam ownership transfer is attempted before teardown;
- a rejected Steam transfer does not tear down the host;
- CI stays green.

## 3E — Unexpected host-loss recovery

`HostMigrationManager` now owns the `server_disconnected` recovery path while a valid migration target exists.

The old behavior destroyed the multiplayer transport, left the Steam lobby and cleared the roster immediately. During host migration this is no longer allowed. On an unexpected host loss:

- only the failed `SteamMultiplayerPeer` transport is detached;
- the Steam lobby membership, lobby ID, roster and current match state remain in memory;
- the complete backup snapshot remains stored only on the selected backup;
- clients enter `host_migration_recovering` instead of `host_disconnected`;
- every client already knows the selected backup SteamID from the public backup-authority identity sync;
- clients poll the current Steam lobby owner every 200 ms;
- if Steam assigns lobby ownership directly to the selected backup, that backup is marked `host_migration_promotion_ready` only when it also holds a valid snapshot;
- other clients remain in `host_migration_waiting`;
- if Steam temporarily assigns ownership to another remaining player, that temporary owner calls `setLobbyOwner` to hand the lobby to the selected backup;
- the recovery window is bounded to 8 seconds;
- timeout enters `host_migration_timed_out` but does not yet decide the final user-facing fallback; that belongs to 3I.

If no valid backup identity exists when the transport dies, the legacy safe teardown path is retained.

3E deliberately stops before recreating the gameplay server. A client being Steam lobby owner is not yet equivalent to being the Godot multiplayer authority. Gate 3F performs that promotion.

## 3E exit gate

3E is complete when:

- a host crash no longer destroys lobby/roster state while migration is possible;
- the selected backup can distinguish itself from observers;
- a backup without a valid snapshot cannot promote;
- a temporary Steam lobby owner deterministically hands ownership to the selected backup;
- promotion readiness requires Steam ownership to match the selected backup identity;
- recovery has a bounded timeout;
- CI stays green.

## Next gates

- 3F — recreate `SteamMultiplayerPeer` and promote the backup to gameplay server;
- 3G — reconnect remaining peers;
- 3H — restore snapshot and resume phase/deadline;
- 3I — safe fallback when migration cannot complete.
