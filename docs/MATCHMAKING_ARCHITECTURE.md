# Gods & Liars — Party + Quick Match architecture

## Goal
The commercial Mafia flow targets exactly 8 players without forcing users to browse public rooms or wait inside a half-empty lobby.

The player-facing model is:

`Party -> Quick Match -> Match Found -> Match Lobby -> Role Reveal -> Match -> Rematch`

Steam lobbies remain an implementation detail. The public UI is not a server browser.

## 1. Party
A Party is a persistent group of 1–8 players who want to stay together.

Rules:
- a solo player is a Party of 1;
- a Party is never split by matchmaking;
- the Party leader starts or cancels Quick Match;
- all Party members are moved into the same final Match Lobby;
- leaving a match should preserve the Party when possible;
- Party membership is independent from Steam friendship.

A player does not need to add another player as a Steam friend to remain grouped with them after a match. Steam friendship is only a convenience for the normal friend-invite overlay.

`PartyState` is the transport-independent source model. `PartyManager` owns the Steam Party Lobby lifecycle.

## 2. Match target
For the current Mafia stage:

`TARGET_PLAYERS = 8`

Valid compositions include:
- 5 + 3
- 6 + 2
- 4 + 4
- 4 + 2 + 1 + 1
- 3 + 3 + 2
- 2 + 2 + 2 + 2
- eight solo players

A composition is valid only when the complete Parties total exactly 8. Parties are never split to make the number fit.

`MatchSession.MIN_PLAYERS` and `MatchSession.MAX_PLAYERS` are locked to 8 for the current commercial flow.

## 3. Progressive / expansive search
Quick Match starts narrow and expands with elapsed queue time:

- 0–10 seconds: CLOSE
- 10–20 seconds: DEFAULT
- 20–40 seconds: FAR
- 40+ seconds: WORLDWIDE

The distance constants mirror the Steam lobby distance tiers. Expansion changes only who may be matched; it never splits a Party or changes the 8-player target.

`QuickMatchRules.distance_tier_for_elapsed()` owns the deterministic timing rule. `MatchmakingManager` owns runtime queue state.

## 4. Steam lobby separation
Steam lobby types are deliberately separated.

### Party Lobby
- Steam type: `Private`.
- Metadata `game=GodsAndLiarsMVP` and `kind=party`.
- Steam lobby owner is the Party leader.
- Membership is invitation-based, not friendship-based.
- The Steam friend overlay remains available as a convenience for inviting existing friends.
- `InviteUserToLobby` can target exact Steam IDs already known from the current match roster, which supports post-match retained groups even when those players are not Steam friends.
- Member names are mirrored through lobby member data.
- Party leader publishes `target_match_id` only after a Match Lobby is created or a reservation is accepted.

### Match Lobby
- Quick Match uses Steam type `Invisible`.
- Metadata `game=GodsAndLiarsMVP`, `kind=match`.
- Capacity is exactly 8.
- `match_state=open|started` prevents started matches from returning in searches.
- `open_slots` subtracts both connected peers and Party seats already reserved while members are in transit.
- `anchor_party_size` records the Party size that created an anchor and is used to identify pure anchors for convergence.

The Party Lobby remains alive while members join the invisible Match Lobby.

## 5. Matchmaking strategy
The leader presses **Buscar partida**.

1. Search only compatible `kind=match`, `match_state=open` lobbies.
2. Reject candidates that cannot fit the complete Party.
3. Prefer the smallest sufficient `open_slots` value.
4. Repeat the search while progressively expanding the distance tier.
5. If no compatible match is observed after a short deterministic backoff, create an invisible Match Lobby as an anchor.
6. Once a candidate reservation succeeds or an anchor is created, publish `target_match_id` to the Party Lobby.
7. Party members detect the target and join it automatically.

The short Steam-ID-derived anchor jitter reduces the probability that several waiting Parties create anchors in the same instant.

## 6. Host-authoritative Party reservation
The Match host arbitrates Party capacity; clients do not reserve seats by merely reading `open_slots`.

Every client joining a Match Lobby publishes member metadata:
- `party_size`
- `party_token`

The first member of an external Party is normally its leader. Before adding that peer to the authoritative roster, the host checks whether the entire Party fits.

If it fits:
- leader is accepted;
- host reserves `party_size - 1` remaining seats under the Party token;
- advertised `open_slots` immediately excludes those seats;
- subsequent members carrying the same Party token consume the reservation one by one.

If it does not fit:
- the reservation is rejected;
- the peer is disconnected from the Match transport;
- the leader clears the stale Party target and resumes Quick Match search;
- the Party is not split.

When a Party creates an anchor itself, the host already knows the Steam IDs of its own Party members and removes those in-transit seats from advertised capacity immediately.

## 7. Anchor convergence
Anchor convergence prevents two compatible Parties from remaining stranded in separate Match Lobbies when both created anchors during the same Steam search window.

Rules:
- only `match_state=open` anchors participate;
- a local anchor continues periodic discovery while it contains only its originating Party;
- an anchor is considered pure when `open_slots == 8 - anchor_party_size`;
- compatible pure anchors may merge only if their complete Parties fit within 8 players;
- the lower Steam Lobby ID wins deterministically;
- only the Party in the higher Lobby ID migrates, so reciprocal migration cannot occur;
- the losing Party updates `target_match_id`, leaves its old anchor and joins the winning anchor as one Party;
- the winning Match host applies the normal authoritative Party reservation before accepting the group;
- once another Party begins joining an anchor, it stops being pure and convergence stops for that Match Lobby;
- if the reservation loses a last-moment capacity race, the stale target is cleared and Quick Match resumes.

Examples:
- 5-player anchor + 3-player anchor -> converge to one 8-player Match Lobby;
- 4 + 4 -> converge;
- 6 + 3 -> do not converge;
- an anchor whose advertised capacity already shows another Party/reservation -> do not migrate it as a pure anchor.

`AnchorConvergenceRules` owns the deterministic decision and is covered by unit tests.

## 8. Host authority
The final Match Lobby remains host-authoritative for the MVP.

The host owns:
- authoritative peer roster;
- Party slot reservations;
- roles;
- night actions;
- votes;
- deaths;
- winner;
- rematch state.

Host migration remains outside the current MVP.

## 9. Player-facing lobby UI
The old Create / Refresh / Lobby List / Join browser is removed from the normal flow.

Primary actions are:
- **Invitar amigos**
- **Buscar partida**
- **Cancelar búsqueda**

The screen shows Party membership separately from the forming Match roster. READY/START controls appear only after entering a Match Lobby. START remains host-only and requires exactly 8 connected READY players.

## 10. Rematch / retention loop
After a match:
- players may rematch with the same 8;
- players may leave back to their original Party;
- players who were not previously grouped may choose **Seguir juntos**;
- the retained players form a new Private Party through exact-Steam-ID invitations, without requiring Steam friendship;
- the retained Party can queue again to fill missing seats.

Example: 8 play, 2 leave, 6 choose to stay together -> those 6 form a Party and Quick Match searches for compatible complete Parties totaling 2.

The post-match retention flow should collect each player's explicit in-game opt-in before creating or joining the retained Party.
