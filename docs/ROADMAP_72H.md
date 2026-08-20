# Gods & Liars — 72h MVP Roadmap

## Objective
A complete social-deduction match must be playable by real Steam users from lobby creation to rematch.

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
- Integrate GodotSteam.
- Steam initialization.
- App ID 480 for development.
- Create/list/join/leave lobby.
- SteamMultiplayerPeer host/client transport.

Exit gate: two Steam users can join the same lobby and see each other.

## FASE 2 — Lobby + voice
- Player roster and Steam names.
- Ready state.
- Host-only start.
- Push-to-talk voice.
- Disconnect handling before match start.

Exit gate: two users can talk, ready up and start together.

## FASE 3 — Table scene + avatars
- Fixed ritual table scene.
- 10 deterministic seats.
- Spawn one avatar per peer.
- Camera and basic interaction target selection.
- Placeholder modular body/tunic/mask accepted.

Exit gate: all peers see the same seat assignment and avatar roster.

## FASE 4 — Private roles
- Host assigns roles only.
- Each client receives only its own role/private result.
- Role reveal UI.
- Alive/dead state replication without leaking role table.

Exit gate: 6–8 real/simulated players can receive valid secret roles without information leakage.

## FASE 5 — Night loop
- Heretic target selection.
- Healer protection.
- Inquisitor investigation.
- Host validation of legal actions.
- Deterministic night resolution.

Exit gate: protected targets survive, legal kills resolve, investigator receives private result.

## FASE 6 — Day + voting
- Day discussion timer/state.
- Target selection.
- One valid vote per living player.
- Tie handling.
- Sacrifice result.

Exit gate: a full night→day→vote cycle completes without manual intervention.

## FASE 7 — Death, victory, rematch
- Dead player becomes spectator/ghost.
- Dead users cannot vote or use role powers.
- Faithful/heretic win conditions.
- End screen.
- Rematch from same lobby.

Exit gate: a complete match can end and restart.

## FASE 8 — MVP QA + Windows build
- Multiplayer edge cases.
- Disconnect cases.
- UI clarity pass.
- Basic audio/visual feedback.
- Windows export.
- README run instructions.
- MVP tag after validated playtest.

Exit gate: distributable Windows build completes an end-to-end multiplayer playtest.

## Time budget
- F0: 0–6h
- F1: 6–14h
- F2: 14–20h
- F3: 20–28h
- F4: 28–36h
- F5: 36–46h
- F6: 46–55h
- F7: 55–63h
- F8: 63–72h

## Scope lock
Not part of this MVP: dedicated servers, accounts/backend, progression, cosmetics economy, battle pass, matchmaking ranking, anti-cheat beyond host authority, additional game modes, multiple maps, advanced animation, final art.
