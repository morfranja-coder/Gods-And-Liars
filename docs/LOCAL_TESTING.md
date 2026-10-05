# Gods & Liars — Local testing workflow

This is the canonical Windows QA sequence after the multiplayer P0 hardening pass.

## Engine and runtime

Gods & Liars uses:

- Godot 4.7.x;
- GodotSteam 4.20;
- Steamworks SDK 1.64;
- development Steam App ID 480 until the production App ID is assigned.

Do not use Godot 4.6 for this project.

## Layer 0 — repository quality gate

From the repository root in PowerShell:

```powershell
.\tools\verify-local.ps1
```

This runs the local lint/import/smoke/GdUnit gate. GitHub CI remains the canonical acceptance gate for the full multi-process D1-D11 suite.

Expected final line:

```text
GREEN: local quality gate passed.
```

## Layer 1 — one human + seven bots

This is the first gameplay test to run locally.

It uses `PracticeManager` with an offline host and seven deterministic/synthetic participants. It validates gameplay presentation and the human interaction loop without requiring Steam networking.

Launch each role separately from PowerShell:

```powershell
godot --path . -- PRACTICA1_HEREJE
godot --path . -- PRACTICA1_FIEL
godot --path . -- PRACTICA1_SACERDOTE
godot --path . -- PRACTICA1_INQUISIDOR
```

If `godot` is not in PATH, replace it with the Godot 4.7 executable path.

For every role validate:

- table scene opens correctly;
- role reveal is readable and private;
- phase labels and buttons match the active role;
- dead players cannot act or vote;
- day/vote/sacrifice transitions do not freeze;
- win screen appears and the session can exit cleanly.

### Canonical Night 1

Night 1 is intentionally special:

1. one Heretic decider chooses a victim;
2. God warns the Priest who will be attacked;
3. the Priest automatically protects that victim;
4. the Inquisitor rests;
5. nobody dies;
6. Day 1 begins.

Do not report the lack of a manual Priest/Inquisitor Night-1 action as a bug.

### Night 2+

Validate:

- Heretic decider rotates by round;
- only the current decider can submit the Heretic action;
- Heretic cannot target another Heretic;
- Priest can protect a legal target;
- Priest can self-save only once per match;
- a second self-save attempt is rejected;
- Inquisitor can investigate on Night 2+;
- private investigation result appears only for the Inquisitor.

### Voting

Validate:

- all living players vote in the same voting window;
- one vote per living player;
- a submitted vote cannot be replaced;
- self-vote is rejected;
- dead voter and dead target are rejected;
- a vote after the voting phase has ended is ignored;
- a unique top target is sacrificed;
- tied top targets are resolved by the authoritative server RNG and all clients must converge to the same result.

Practice mode does **not** validate Steam identity, lobby metadata, relay transport or voice.

## Layer 2 — local workstation preflight

Before real Steam tests:

```powershell
.\tools\check-local-qa-prereqs.ps1
```

Expected final line:

```text
GREEN: local QA workstation prerequisites are ready.
```

The optional Godot visual-QA MCP setup remains available through:

```powershell
.\tools\setup-local-godot47-mcp.ps1
```

## Layer 3 — Steam-capable Windows artifact

Use the `GodsAndLiars-Steam-Windows` artifact from the exact green commit you want to test.

After this branch is merged, use the latest green integration-branch artifact rather than an older build.

Extract the artifact to a dedicated QA folder, for example:

```text
C:\GodsAndLiars-QA\host
```

The folder must contain:

```text
GodsAndLiars.exe
steam_api64.dll
steam_appid.txt
```

`steam_appid.txt` must contain `480` during development.

Launch:

```powershell
.\tools\run-steam-qa-client.ps1 `
  -BuildDir "C:\GodsAndLiars-QA\host" `
  -ClientLabel "host"
```

## Layer 4 — two independent Steam accounts

Use two different Steam accounts, preferably on two computers.

Run `docs/STEAM_TWO_ACCOUNT_SMOKE_TEST.md`.

This layer validates:

- Steam identity;
- Party invite;
- protocol-compatible Match Lobby handoff;
- SteamMultiplayerPeer connection;
- authoritative roster/seats;
- READY staying blocked from starting gameplay below 8/8;
- basic push-to-talk voice;
- leaving the Match while preserving the Party.

Two accounts are not a complete Mafia gameplay acceptance gate.

## Layer 5 — exact-8 human Steam acceptance

The final commercial networking gate still requires eight independent Steam identities.

Run:

```text
docs/PHASE_8_STEAM_8CLIENT_CHECKLIST.md
```

Synthetic bots and CI prove rules and authorization, but they cannot prove real Steam lobby membership, relay behavior, eight independent identities or real voice routing.

## Failure capture

For local practice failures capture:

- human role;
- current round and phase;
- action attempted;
- visible result;
- console error/stack trace.

For Steam failures also capture:

- exact Git commit/build;
- Steam IDs involved;
- Party Lobby ID;
- Match Lobby ID;
- queue state;
- peer count;
- host/client status;
- QA session logs.

Do not fix a local failure by weakening an automated gate. Reproduce the mismatch, identify whether runtime or the checklist is stale, then change one canonical source.
