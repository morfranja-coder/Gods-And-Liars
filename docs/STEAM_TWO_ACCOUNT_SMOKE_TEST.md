# Gods & Liars — Steam two-account smoke test

## Purpose

This is the first real Steam transport smoke test for the Party -> Quick Match -> Match Lobby flow.

It does **not** replace the final 8-account acceptance test. Its purpose is to prove that two independent Steam identities can:

1. initialize the game through Steam;
2. enter the same Private Party Lobby;
3. preserve Party membership while matchmaking starts;
4. create/join an Invisible Match Lobby;
5. synchronize SteamMultiplayerPeer transport and roster identity;
6. leave the Match while preserving the Party.

Use a DEV/debug build. The lobby shows a `DEV NET` line containing the runtime identifiers needed for diagnosis. This line is hidden in non-debug builds.

## Preconditions

Use two different Steam accounts. Prefer two computers for the cleanest transport test.

Both machines must use:

- the same commit/build;
- Godot 4.7 runtime compatible with SteamMultiplayerPeer;
- Steam running and logged in;
- the same Steam test App ID configured by the project;
- no old Gods & Liars process still running.

Record the tested Git commit before starting.

## DEV NET fields

The debug lobby exposes:

- `steam`: local SteamID;
- `party`: Private Party Lobby ID;
- `target`: Match Lobby ID published by the Party leader;
- `match`: Match Lobby currently joined by this client;
- `queue`: MatchmakingManager runtime state;
- `scope`: current Steam distance search tier;
- `peers`: authoritative Match roster count;
- `open`: host-advertised free Match seats, or `remote` for a client;
- `host`: whether this client owns the Match transport;
- `started`: whether gameplay has started.

Never treat two accounts showing the same `steam` value as a valid test.

## Test A — Steam identity

On Account A and Account B:

1. Launch the same DEV build through the Steam-capable runtime.
2. Wait for the lobby screen.
3. Confirm the identity line shows the correct Steam persona and a positive SteamID.
4. Confirm the two SteamIDs differ.

Pass:

- Steam is available on both clients;
- both SteamIDs are positive and different;
- `party=0`, `target=0`, `match=0` before creating a Party.

Capture both lobby screens if this fails.

## Test B — Private Party invite

Account A:

1. Press `Invitar amigos`.
2. Let the Private Party Lobby be created.
3. Invite Account B from the Steam overlay.

Account B:

1. Accept the invite.
2. Return to the game.

Pass:

- both clients show `TU GRUPO — 2/8`;
- both clients show the same non-zero `party` Lobby ID;
- Account A is the Party leader;
- `match=0` on both clients;
- friendship is not part of Party correctness beyond using the overlay as an invitation convenience.

Capture both `DEV NET` lines if Party membership differs.

## Test C — Party Quick Match handoff

Account A, as Party leader:

1. Press `Buscar partida`.
2. Do not cancel the queue.
3. Watch the `queue`, `target`, and `match` values on both clients.

Expected behavior with only this Party available:

1. Account A searches for an open Match Lobby.
2. After the deterministic anchor delay, Account A creates an Invisible Match Lobby.
3. Account A publishes that Match Lobby through the Private Party `target_match_id`.
4. Account B observes the Party target and joins the same Match Lobby automatically.
5. SteamMultiplayerPeer connects B to A.

Pass:

- both clients eventually show the same non-zero `target`;
- both clients eventually show the same non-zero `match`;
- Account A shows `host=yes`;
- Account B shows `host=no`;
- both Match rosters eventually contain 2 peers;
- Account A advertises `open=6` after both Party members are represented;
- Party Lobby remains alive and both clients still show the same non-zero `party` ID.

Important: this smoke test intentionally does **not** start Mafia gameplay because the commercial gate requires exactly 8 ready players.

## Test D — READY must not bypass the 8-player gate

On both accounts:

1. Press `Listo`.

Pass:

- both players can become READY;
- host still cannot start the ritual with only 2/8;
- no client enters the table scene;
- `started=no` remains true on both clients.

This proves the real Steam transport does not accidentally bypass the commercial 8-player start rule.

## Test E — Leave Match, keep Party

Account B:

1. Press `Salir de la partida`.

Pass:

- B leaves the Match Lobby/transport;
- the Private Party remains intact;
- Account A and Account B still show the same non-zero Party Lobby ID after Party synchronization settles;
- B can return to the Party flow without recreating Steam friendship state.

Then let Account A leave/cancel the Match and return to Party state as well.

## Optional voice transport check

While both accounts are in the same Match Lobby:

1. Hold `V` on Account A and speak.
2. Confirm Account B hears A and its voice indicator identifies A.
3. Repeat B -> A.

Pass:

- no feedback/loop from the sender's own voice;
- the remote talking indicator identifies the correct peer;
- audio does not arrive from an unknown peer.

A headset on at least one machine is strongly recommended to avoid acoustic feedback.

## Failure triage

If Steam identity fails, capture:

- identity line;
- `DEV NET` line;
- console output from startup.

If Party join fails, capture from both clients:

- Party member list;
- `DEV NET` line;
- visible status/error text.

If Match handoff fails, capture from both clients at the same moment:

- `party`;
- `target`;
- `match`;
- `queue`;
- `peers`;
- `host`;
- visible status/error text.

Interpretation shortcuts:

- same `party`, `target=0`: leader never published/created a Match target;
- same non-zero `target`, B `match=0`: Party propagation worked, Match join failed;
- same `match`, B never reaches 2 peers: Steam lobby join worked but transport/identity synchronization failed;
- different non-zero `match` values: Match handoff/convergence is wrong;
- `started=yes` at 2/8: critical start-gate regression.

## Acceptance result

Mark this smoke test PASS only if Tests A through E pass on two independent Steam accounts.

After PASS, the next real-network milestones are:

- two independent Parties converging into one Match Lobby;
- 4-account Party/reservation testing;
- mixed Party compositions;
- final exact 8-account commercial acceptance.
