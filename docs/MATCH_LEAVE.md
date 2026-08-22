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

`MatchLeaveManager` captures this invariant immediately before it tears down the local Match transport. After `NetworkManager.leave_lobby()`, `MatchmakingManager.reset()` and `GameManager.reset_match()`, it captures Party state again and verifies exact equality.

A mismatch emits `party_preservation_failed` and a QA-visible engine error. Match leave itself still completes so a preservation diagnostic cannot strand the player inside a broken Match transport.

The invariant deliberately includes `match_target_lobby_id`: an individual player leaving does not rewrite Party-wide routing metadata while other Party members may still be in the same Match.

No Match-leave path calls `PartyManager.leave_party()`, `PartyManager.reset_to_solo()` or replaces `PartyManager.state`.

## Exit gates

### 4A

4A is complete when:

- a non-host with an active Match Lobby can request leave;
- duplicate pending leave requests are rejected;
- the host validates RPC sender ↔ SteamID identity;
- peer `1` cannot use the non-host leave RPC;
- the authoritative roster removal occurs before the client tears down its local transport;
- existing disconnect gameplay rules mark the player dead and continue the match for everyone else;
- the leaving player's Party remains intact;
- CI stays green.

### 4B

4B is complete when:

- a valid host can request leave through migration;
- the host cannot use the non-host RPC path;
- Steam ownership transfer is requested before teardown;
- transfer failure keeps the host connected;
- transfer success releases the old host locally;
- remaining players are left to the 3E–3H migration flow;
- CI stays green.

### 4C

4C is complete when:

- a pre-handoff migration failure cancels only the pending leave;
- the original host remains authoritative and connected;
- no Party or Match state is destroyed by the failed leave request;
- a useful error is retained for UI;
- the leave operation becomes retryable immediately after cancellation;
- post-handoff migration failures remain owned by the 3I fallback;
- CI stays green.

### 4D

4D is complete when:

- Party Lobby ID survives successful Match leave unchanged;
- logical Party ID and leader SteamID remain unchanged;
- Party membership remains byte-for-byte equivalent at the data-model level;
- Party match target remains unchanged;
- an accidental future Party mutation is surfaced through a runtime invariant failure;
- both host and non-host Match exits use the same preservation check;
- CI stays green.
