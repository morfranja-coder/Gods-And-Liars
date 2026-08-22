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

That migration call now performs only the ownership handoff. It does not tear down the old host by itself.

The sequence is:

1. the current host must still own an active multiplayer transport;
2. the existing host-migration backup must be connected and hold a valid authoritative snapshot;
3. Steam `setLobbyOwner` transfers Match Lobby ownership to that backup;
4. `voluntary_transfer_completed` is emitted only after Steam accepts the transfer request;
5. only then does `MatchLeaveManager` close the old host's Match Lobby/transport and return that local player to Lobby;
6. the remaining clients observe the old gameplay server disappearing and continue through the existing 3E–3H migration pipeline;
7. the old host's Party Lobby remains untouched.

If the transfer cannot be started or Steam rejects it, `leave_pending` is cleared and the host remains in the match. The failure path is intentionally handled before local teardown so a failed voluntary transfer cannot destroy the match.

### 4B safety rules

- host leave requires a valid Match Lobby and active multiplayer peer;
- only the current host can enter the host-leave path;
- duplicate host-leave requests are rejected while one is pending;
- ownership transfer happens before local host teardown;
- a rejected transfer leaves the old host connected;
- the Party is preserved;
- the existing migration pipeline, not the old host, reconstructs authority for the seven remaining players.

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
