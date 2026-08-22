# Gods & Liars — Match Leave

## 4A — Non-host player leaves an active match

`MatchLeaveManager` owns the controlled leave flow for a regular client.

The client does not immediately close its multiplayer peer. It first sends a reliable leave request to the authoritative host containing only its SteamID.

The host validates the request against the authoritative `NetworkManager.peers` entry for the RPC sender. A client cannot leave on behalf of another Steam identity and peer `1` cannot use this path.

When accepted:

1. the host acknowledges the request;
2. the host broadcasts the authoritative roster removal through the existing `_remove_peer` RPC;
3. `NetworkManager.peer_left` fires on the host;
4. `MatchAuthority` applies the existing disconnect policy, marks that player dead and resumes/finishes the current phase if required;
5. the leaving client closes only its Match Lobby/transport;
6. local matchmaking and match state return to Lobby;
7. the Party Lobby is preserved.

### Party rule

A single player leaving a match does **not** clear `PartyManager.match_target_lobby_id`.

That target belongs to the Party as a whole and other Party members may still be playing the same match. This is especially important when the leaving client happens to be the Party leader.

## 4B — Host leaves voluntarily

The gameplay host never uses the regular client-leave RPC.

When the host requests leave, `MatchLeaveManager` enters a pending host-leave state and calls `HostMigrationManager.request_voluntary_host_exit()`.

That migration call performs only the ownership handoff. It does not tear down the old host by itself.

The sequence is:

1. the current host must still own an active multiplayer transport;
2. the existing host-migration backup must be connected and hold a valid authoritative snapshot;
3. Steam `setLobbyOwner` transfers Match Lobby ownership to that backup;
4. `voluntary_transfer_completed` is emitted only after Steam accepts the transfer request;
5. only then does `MatchLeaveManager` close the old host's Match Lobby/transport and return that local player to Lobby;
6. the remaining clients observe the old gameplay server disappearing and continue through the existing 3E–3H migration pipeline;
7. the old host's Party Lobby remains untouched.

## 4C — Failed host leave / migration boundary

A failed voluntary handoff **before ownership changes** must not invoke the terminal host-migration fallback. At that point the original host is still the valid gameplay authority and the safest action is to cancel only the leave attempt.

When `request_voluntary_host_exit()` fails because the backup/snapshot is unavailable, Steam is unavailable, `setLobbyOwner` is unavailable, or Steam rejects the transfer:

- `leave_pending` is cleared;
- the host-leave flag is cleared;
- the Match Lobby remains joined;
- the current `SteamMultiplayerPeer` remains active;
- `NetworkManager.is_host` is unchanged;
- Match state and phase are not reset;
- Party state and Party match target are untouched;
- the concrete failure reason is stored for UI and emitted through `leave_rejected` / `host_leave_cancelled`;
- the host may retry leaving later after the backup becomes valid again.

If Steam has already accepted the ownership handoff and the old host subsequently leaves, responsibility changes: failures while the remaining seven players promote/reconnect/restore are handled by the existing 3I fallback on those clients. The old host does not attempt to reclaim authority.

An empty transfer failure reason is normalized to a safe message explicitly stating that the match remains active.

## 4D — Preserve Party across match leave

Leaving a Match and leaving a Party are separate operations.

`MatchLeavePartyInvariant` captures the complete Party identity that must survive a successful local Match exit:

- Party Lobby ID;
- Party match target Lobby ID;
- logical Party ID;
- Party leader SteamID;
- complete Party member map.

`MatchLeaveManager` captures this invariant immediately before it tears down the local Match transport. After local Match cleanup it captures Party state again and verifies exact equality.

A mismatch emits `party_preservation_failed` and a QA-visible engine error. Match leave itself still completes so a preservation diagnostic cannot strand the player inside a broken Match transport.

No Match-leave path calls `PartyManager.leave_party()`, `PartyManager.reset_to_solo()` or replaces `PartyManager.state`.

## 4E — Explicit local cleanup

Successful Match leave uses one deterministic cleanup sequence instead of relying on autoload signal ordering.

The local client explicitly clears:

- active voice capture/playback state;
- Match Lobby and `SteamMultiplayerPeer`;
- local Match roster;
- private role and Heretic teammate data;
- public alive/dead map and winner;
- authoritative `MatchSession`, acknowledgements, night actions, votes and deadlines;
- host-migration backup/snapshot state;
- host-promotion and reconnect state/maps;
- stale host-migration fallback reason;
- matchmaking state;
- local round and phase back to Lobby.

`MatchLeaveCleanupRules` validates the postcondition: no Match lobby, peers, role, public alive map, migration backup/reconnect map or active matchmaking state may remain, and local round/phase must be reset. Party state is intentionally outside this cleanup and remains protected by 4D.

## 4F — Leave button / UI integration

The real UI never performs an unconfirmed destructive leave.

### Active match / table

`scenes/table/table.tscn` exposes a top-right `Abandonar partida` control and a `ConfirmationDialog`.

- regular clients see a confirmation that their Party will be preserved;
- the host sees an explicit warning that authority will be transferred before leaving;
- confirming calls only `MatchLeaveManager.request_leave_match()`;
- while the request is pending the button is disabled;
- a regular client sees `Abandonando partida...`;
- the host sees `Transfiriendo host...`;
- a rejected leave re-enables the button and displays the concrete reason without removing the player from the match.

### Pre-match Match Lobby

The existing Lobby `Salir de la partida` button now also requires confirmation.

Before gameplay has started there is no authoritative match snapshot to migrate, so leaving this staging Match Lobby uses the simple Match-Lobby teardown path rather than host migration. It resets only local Match/matchmaking state and preserves the Party. The old direct button path that also cleared Party match routing metadata is removed.

When a successful active-match leave changes back to the Lobby scene, the persisted `MatchLeaveManager` success/error message is consumed and displayed there.

## Exit gates

### 4A

- a non-host with an active Match Lobby can request leave;
- duplicate pending leave requests are rejected;
- the host validates RPC sender ↔ SteamID identity;
- peer `1` cannot use the non-host leave RPC;
- authoritative roster removal occurs before local teardown;
- disconnect gameplay rules continue the match for everyone else;
- Party remains intact;
- CI stays green.

### 4B

- a valid host can request leave through migration;
- Steam ownership transfer is requested before teardown;
- transfer failure keeps the host connected;
- transfer success releases the old host locally;
- remaining players continue through 3E–3H;
- CI stays green.

### 4C

- a pre-handoff migration failure cancels only the pending leave;
- the original host remains authoritative and connected;
- no Party or Match state is destroyed;
- a useful error is retained for UI;
- retry is possible after cancellation;
- post-handoff failures remain owned by 3I;
- CI stays green.

### 4D

- Party Lobby ID, Party ID, leader, members and match target survive successful Match leave unchanged;
- accidental Party mutation is surfaced through a runtime invariant failure;
- host and non-host exits use the same preservation check;
- CI stays green.

### 4E

- local Match transport, roster, private/public gameplay state, migration state, voice state and matchmaking state are explicitly reset;
- the cleanup postcondition is validated;
- Party state remains excluded from cleanup;
- CI stays green.

### 4F

- active-match leave is reachable from the table UI;
- staging Match Lobby leave remains reachable from Lobby UI;
- both require confirmation;
- active-match host/client paths route through `MatchLeaveManager`;
- pending leave disables repeat clicks;
- failure is visible and non-destructive;
- successful leave feedback survives the scene change;
- CI stays green.
