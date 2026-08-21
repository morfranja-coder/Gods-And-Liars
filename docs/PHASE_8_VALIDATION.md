# FASE 8 — QA final, hardening y build Windows

FASE 8 cierra el MVP técnico. No publica una release ni sube nada a Steam.

## 1. Automated quality gate

GitHub Actions must keep these jobs green:

- Secret scan / Gitleaks.
- GDScript lint.
- Godot 4.7 import/parse.
- Smoke tests.
- GdUnit4 unit/scene tests.
- Windows release export.
- Steam multiplayer runtime export.

The Windows export job proves that the project parses, tests and exports. The Steam runtime job separately proves that the selected runtime exposes both `Steam` and `SteamMultiplayerPeer` and assembles the Steam-capable Windows artifact.

## 2. Local quality gate

From PowerShell:

```powershell
.\tools\check-local-qa-prereqs.ps1
```

Expected final line:

```text
GREEN: local QA workstation prerequisites are ready.
```

## 3. Steam runtime dependency gate

Pinned MVP target:

- Godot 4.7.x;
- Steamworks SDK 1.64;
- GodotSteam 4.20 / compatible MultiplayerPeer runtime;
- development App ID 480 until a real Steam App ID is assigned.

The intended runtime must expose both:

- `Steam` for identity, lobbies, callbacks and voice;
- `SteamMultiplayerPeer` for Godot high-level multiplayer over Steam.

Do not combine overlapping GodotSteam module and normal API GDExtension bindings.

## 4. Party + Quick Match gate

The commercial entry flow is:

`Party -> Quick Match -> Match Found -> Match Lobby -> Role Reveal -> Match`

Current Mafia target is exactly 8 players.

Required behavior:

1. Party size may be 1–8.
2. A Party is never split.
3. Match composition must total exactly 8.
4. Search expands CLOSE -> DEFAULT -> FAR -> WORLDWIDE over time.
5. Existing compatible forming Match Lobbies should be preferred before creating another one.
6. Multi-player Parties require a reservation step before moving members to avoid overfill races.
7. A Match Lobby must reject a ninth player.

See `docs/MATCHMAKING_ARCHITECTURE.md`.

## 5. Windows build

After the matching GodotSteam runtime/templates are available, the Steam CI path produces:

```text
GodsAndLiars.exe
steam_api64.dll
steam_appid.txt
```

The artifact is published internally as:

```text
GodsAndLiars-Steam-Windows
```

`steam_appid.txt` must contain `480` during development.

## 6. Human multiplayer acceptance gate

Testing layers are intentionally different:

- 1 real Steam client: local launch / Steam smoke.
- 2 real Steam clients: transport, roster, seat and voice gate.
- 4 clients or synthetic peers: isolated rule and disconnect QA only.
- 8 real Steam clients: full Mafia acceptance gate.

The full gate is `docs/PHASE_8_STEAM_8CLIENT_CHECKLIST.md`.

At 8/8 validate:

1. Party / Quick Match delivers all eight users into the same Match Lobby.
2. All identities and seats match on every client.
3. START stays blocked at 7/8 and is available only at 8/8 with all required readiness satisfied.
4. Every client receives exactly one private role.
5. Distribution is 2 Herejes, 1 Sanador, 1 Inquisidor, 4 Fieles.
6. Night phases and private investigation behave correctly.
7. Day voice routing follows living/dead rules.
8. Voting and sacrifice synchronize.
9. Win condition resolves identically on every client.
10. Rematch retains the Match Lobby and resets the match state.
11. Disconnects do not freeze ACK/action/vote quorum.
12. Host disconnect terminates the current match cleanly; host migration remains out of MVP.

## Exit gate

FASE 8 is CLOSED only when:

- CI is green including Windows and Steam runtime export jobs;
- local QA prerequisites are green;
- the real 8-client Steam acceptance loop passes;
- Party + Quick Match no longer relies on the public server-browser UI for the commercial path.

Until those gates pass, the repository is implementation-in-progress and must not be called release-ready.
