# Gods & Liars — Host Migration

## Goal

A match should survive the departure or crash of the current game host whenever a valid successor can take authority.

Host migration is split into small gates so networking changes do not land before the authoritative state can be reproduced safely.

## 3A — Serializable authoritative match snapshot

`MatchSnapshot` is the versioned, transport-independent representation of the authoritative Mafia match state.

Current schema version: `1`.

The snapshot includes the exact 8-player identity set, seats, secret roles, alive/dead state, current phase and round, remaining phase time, winner state, role acknowledgements, accepted night actions and votes. It round-trips through Dictionary/JSON and reconstructs a `MatchSession` without rerolling roles.

A full snapshot contains the complete secret role map and must never be replicated to every player. It is sent only to the selected backup authority.

## 3B — Deterministic successor election

`HostSuccessorRules` selects the next host by stable SteamID, never by transient Godot peer ID. The current host is excluded, living connected players are preferred, the lowest SteamID wins, and dead/spectator players are deterministic fallback candidates.

## 3C — Backup authority

`HostMigrationManager` keeps one stable backup while that Steam identity remains connected. The backup SteamID is public session metadata, but the complete snapshot is delivered only to that peer. Snapshots are reliable, sequence-numbered, validated and refreshed only when authoritative state changes.

## 3D — Voluntary Steam lobby ownership transfer

Before a host exits voluntarily, ownership is transferred to the selected backup with `setLobbyOwner`. Transfer is blocked unless the backup is connected and already holds a valid snapshot. A rejected Steam transfer leaves the current host in place.

## 3E — Unexpected host-loss recovery

On `server_disconnected`, only the failed multiplayer transport is detached while the Steam Lobby, roster and backup snapshot are preserved. Clients poll Steam lobby ownership. A temporary Steam owner hands ownership to the selected backup. Recovery is bounded to 8 seconds and only a backup with a valid snapshot can become promotion-ready.

## 3F — Recreate SteamMultiplayerPeer

`HostMigrationTransport` promotes only the confirmed backup owner. Promotion requires a valid Lobby, matching local/backup/owner SteamID, a valid snapshot, no active multiplayer peer and an available `SteamMultiplayerPeer` implementation. The backup creates a new host peer with relay enabled and becomes the new gameplay server. Failure preserves Lobby and snapshot state for the fallback gate.

## 3G — Reconnect remaining peers

`HostMigrationReconnect` publishes a migration transport-ready marker in the existing Steam Lobby. Remaining clients reconnect with `create_client(new_host_steam_id, 0)` and identify themselves by SteamID.

The new host never trusts client-supplied seat or display metadata. It rebuilds those fields from the authoritative snapshot and stores `old_peer_id -> new_peer_id` mappings. The old host is excluded. Reconnection completes when the seven remaining players have been remapped.

## 3H — Restore snapshot and resume phase/deadline

`HostMigrationSnapshotRemapper` converts every old gameplay peer reference to the newly assigned peer IDs. The disconnected old host remains in the 8-player authoritative session as a dead tombstone using reserved peer ID `2147483647`, preventing collision with the new host's peer ID `1`.

Actions owned by the disconnected host are dropped. Votes/night actions/protection/investigation targeting the disconnected host are also cleared rather than remapped to the tombstone.

`HostMigrationRestore` then:

- reconstructs the exact `MatchSession` without rerolling roles;
- restores roles-dispatched state, acknowledgements, night actions and votes;
- restores public alive/dead state and winner state;
- restores round and phase;
- redispatches private role data through the existing private RPC path;
- recreates the host-local phase deadline as `Time.get_ticks_msec() + phase_remaining_ms`;
- emits `host_migration_restored` when gameplay authority is ready to continue.

The old host's monotonic clock is never reused.

## 3I — Safe fallback

`HostMigrationFallback` is the final safety net. It listens for migration recovery timeout, migrated-host transport failure, reconnect failure, restore failure, and the legacy `host_disconnected` path used when no recoverable successor exists.

Fallback rules:

- only one fallback may run at a time, so simultaneous downstream failures cannot trigger duplicate teardown;
- the active Match Lobby/transport is closed with the normal `NetworkManager.leave_lobby()` path;
- the Party Lobby is never left or reset;
- the Party match target is cleared for both leaders and followers;
- matchmaking state is reset to idle;
- `GameManager` returns to Lobby state;
- the scene changes back to `res://scenes/lobby/lobby.tscn`;
- the Lobby displays the concrete migration failure reason and confirms that the Party was preserved.

An empty failure reason is normalized to a safe default message. The fallback is terminal for the failed match only; it does not automatically requeue the Party.

## Host migration exit gate

The host migration system is complete when:

- a valid backup can take Steam Lobby ownership;
- it can recreate the gameplay server;
- the seven remaining players can reconnect by stable Steam identity;
- the authoritative match can resume without rerolling roles or resetting the round;
- phase timing resumes from the stored remaining duration;
- failure at any stage returns everyone safely to Lobby without destroying the Party;
- CI remains green.
