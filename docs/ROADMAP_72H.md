# Gods & Liars — MVP Roadmap

## Objective
A complete 8-player social-deduction match must be playable by real Steam users from Party / Quick Match through rematch.

The commercial player-facing entry flow is now:

`Party -> Quick Match -> Match Found -> Match Lobby -> Role Reveal -> Match -> Rematch`

The old public lobby browser is retained only as transitional/debug infrastructure until the Party + Quick Match Steam wiring replaces it.

## FASE 0 — Technical bootstrap
- Godot 4.7 project boots.
- Git hygiene and CI.
- Steam/network adapters isolated from gameplay.
- Authoritative player/session models.
- Role assignment and win rules.
- Night resolution.
- Vote resolution.
- Headless smoke tests.

Exit gate: repository parses in Godot and gameplay smoke tests pass in CI.

## FASE 1 — Steam transport
- GodotSteam integration.
- Steam initialization.
- App ID 480 for development.
- Steam lobby primitives.
- SteamMultiplayerPeer host/client transport.

Exit gate: two Steam users can connect and see each other.

## FASE 2 — Party + Quick Match + voice
- PartyState for 1–8 players.
- Party is never split by matchmaking.
- Quick Match target is exactly 8 players.
- Progressive search: CLOSE -> DEFAULT -> FAR -> WORLDWIDE.
- Exact-fit composition: examples 5+3, 4+2+1+1, 3+3+2.
- Steam Party Lobby / friend invite wiring.
- Forming Match Lobby metadata and Party reservation.
- Player roster and Steam names.
- Push-to-talk voice.
- Disconnect handling before match start.

Exit gate: Parties and solo players can be combined into one 8-player Match Lobby without browsing public rooms.

## FASE 3 — Table scene + avatars
- Fixed ritual table scene.
- 10 deterministic seat markers retained for layout extensibility; current match uses seats 1–8.
- Spawn one avatar per peer.
- Camera and basic interaction target selection.
- Placeholder modular body/tunic/mask accepted.

Exit gate: all peers see the same seat assignment and avatar roster.

## FASE 4 — Private roles
- Host assigns roles only.
- Each client receives only its own role/private result.
- Role reveal UI.
- Alive/dead state replication without leaking role table.

Exit gate: 8 players receive valid secret roles without information leakage.

## FASE 5 — Night loop
- Heretic target selection.
- Healer protection.
- Inquisitor investigation.
- Host validation of legal actions.
- Deterministic night resolution.

Exit gate: protected targets survive, legal kills resolve, investigator receives private result.

## FASE 6 — Day + voting
- Day discussion state.
- Target selection.
- One valid vote per living player.
- Tie handling.
- Sacrifice result.

Exit gate: a full night -> day -> vote cycle completes without manual intervention.

## FASE 7 — Death, victory, rematch
- Dead player becomes spectator/ghost.
- Dead users cannot vote or use role powers.
- Faithful/heretic win conditions.
- End screen.
- Rematch with the same 8 when accepted.
- Players who leave can return to their Party; retained players may queue to refill missing seats.

Exit gate: a complete match can end and restart or refill through Quick Match.

## FASE 8 — MVP QA + Windows build
- Multiplayer edge cases.
- Party merge / reservation races.
- Disconnect cases.
- UI clarity pass.
- Basic audio/visual feedback.
- Windows export.
- Steam runtime export.
- MVP tag only after validated playtest.

Exit gate: distributable Windows Steam build completes an end-to-end 8-player multiplayer playtest.

## Testing distinction
- 1 client: local Steam smoke test.
- 2 clients: transport / lobby / voice test.
- 4 clients or synthetic peers: isolated rule and failure-path QA only.
- 8 real Steam clients: full commercial Mafia acceptance gate.

## Scope lock
Not part of this MVP: dedicated servers, proprietary accounts/backend, progression, cosmetics economy, battle pass, matchmaking ranking/MMR, advanced anti-cheat beyond host authority, additional game modes, multiple maps, advanced animation, final art, host migration.

See `docs/MATCHMAKING_ARCHITECTURE.md` for the Party + Quick Match design lock.
