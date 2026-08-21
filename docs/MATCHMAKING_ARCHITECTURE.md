# Gods & Liars — Party + Quick Match architecture

## Goal
The commercial Mafia flow targets exactly 8 players without forcing users to browse public rooms or wait inside a half-empty lobby.

The player-facing model is:

`Party -> Quick Match -> Match Found -> Match Lobby -> Role Reveal -> Match -> Rematch`

Steam lobbies remain an implementation detail. The public UI should not be a server browser.

## 1. Party
A Party is a persistent group of 1–8 players who want to stay together.

Rules:
- a solo player is a Party of 1;
- a Party is never split by matchmaking;
- the Party leader starts or cancels Quick Match;
- all Party members are moved into the same final Match Lobby;
- leaving a match should return the player to their Party when possible.

`PartyState` is the transport-independent source model. Steam friend invites / Party Lobby transport are the next wiring layer.

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

`MatchSession.MIN_PLAYERS` and `MatchSession.MAX_PLAYERS` are therefore both locked to 8 for the current commercial flow.

## 3. Progressive / expansive search
Quick Match starts narrow and expands with elapsed queue time:

- 0–10 seconds: CLOSE
- 10–20 seconds: DEFAULT
- 20–40 seconds: FAR
- 40+ seconds: WORLDWIDE

The distance constants mirror the Steam lobby distance tiers. Expansion changes only who may be matched; it never splits a Party or changes the 8-player target.

`QuickMatchRules.distance_tier_for_elapsed()` owns the deterministic timing rule. `MatchmakingManager` owns runtime queue state.

## 4. Matchmaking strategy
The Steam-facing implementation should prefer an existing forming Match Lobby that can accept the entire Party.

Candidate priority:
1. exact fill to 8;
2. smallest remaining number of seats after the Party joins;
3. older waiting match / Party;
4. closest currently allowed distance tier.

If no compatible forming Match Lobby exists, the Party leader may create a forming Match Lobby and publish its available capacity.

A reservation step must be added before moving multi-player Parties so two Parties cannot race for the same remaining seats.

## 5. Steam lobby separation
Do not reuse one lobby object for every concept.

Planned separation:
- Party Lobby: friends/group membership and invitations; no gameplay authority;
- Match Lobby: exactly up to 8 players; owns the SteamMultiplayerPeer match transport;
- matchmaking metadata: mode, build compatibility, state, occupied/reserved slots, Party reservation.

This separation is important because Party membership must survive matchmaking and should not be destroyed merely because the player joins a match.

## 6. Host authority
The final Match Lobby remains host-authoritative for the MVP.

The host owns:
- authoritative peer roster;
- roles;
- night actions;
- votes;
- deaths;
- winner;
- rematch state.

Host migration remains out of the current MVP. Party leader and Match host do not have to be the same person in the future.

## 7. Rematch / retention loop
After a match:
- players may rematch with the same 8;
- players may leave back to their original Party;
- a retained temporary group may queue again to fill missing seats.

Example: 8 play, 2 leave, 6 remain -> Quick Match searches for a Party of 2 or compatible complete Parties totaling 2.

## 8. Current implementation status
Implemented now:
- exact 8-player commercial match lock;
- PartyState domain model;
- exact-fill Party composition rules;
- progressive CLOSE -> DEFAULT -> FAR -> WORLDWIDE timing;
- MatchmakingManager queue state and candidate composition logic;
- tests for 5+3, 4+2+1+1, party limits and expansion timing;
- Steam Match Lobby capacity aligned to 8.

Next wiring step:
- Steam Party Lobby / friend invites;
- Match Lobby metadata and reservation tokens;
- Party leader moves all members atomically into selected Match Lobby;
- replace the current public lobby-browser UI with Party + Quick Match UI;
- end-to-end real Steam test with 8 accounts.
