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

### Host rule

The active gameplay host cannot use the 4A path. `MatchLeaveManager` emits `host_leave_requires_migration`; gate 4B will route that case through the host-migration system before allowing the old host to exit.

## 4A exit gate

4A is complete when:

- a non-host with an active Match Lobby can request leave;
- duplicate pending leave requests are rejected;
- the host validates RPC sender ↔ SteamID identity;
- peer `1` cannot use the non-host leave RPC;
- the authoritative roster removal occurs before the client tears down its local transport;
- existing disconnect gameplay rules mark the player dead and continue the match for everyone else;
- the leaving player's Party remains intact;
- CI stays green.
