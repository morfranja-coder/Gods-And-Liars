# Gods & Liars — Local testing workflow

This document is for the Windows development workstation.

## Engine

Gods & Liars uses Godot 4.7 for development, local QA, MCP, CI and runtime validation. `project.godot` declares Godot 4.7 and the Steam runtime gate is pinned to GodotSteam 4.20 / Godot 4.7 / Steamworks SDK 1.64.

Do not use Godot 4.6 for this project.

## 1. Install Godot 4.7 + QA MCP

From the repository root in PowerShell:

```powershell
.\tools\setup-local-godot47-mcp.ps1
```

This installs the official Godot 4.7 stable Windows x86_64 editor under the current user's LocalAppData and registers a Codex MCP named:

```text
godot47-visual
```

The MCP is pinned to Godot MCP Enhanced 0.26.0 and is configured as a QA-oriented local tool.

Requirements:

- Windows x86_64;
- Node.js 18+ with `npx`;
- Codex CLI available in PATH.

Use Codex only for visual/runtime QA in this project. Programming and repository changes remain outside that QA role.

After setup, run the workstation preflight:

```powershell
.\tools\check-local-qa-prereqs.ps1
```

Expected final line:

```text
GREEN: local QA workstation prerequisites are ready.
```

## 2. Get the Steam-capable Windows artifact

Open the latest green GitHub Actions run for branch `phase-0-bootstrap` and download:

```text
GodsAndLiars-Steam-Windows
```

Extract it to a dedicated QA folder, for example:

```text
C:\GodsAndLiars-QA\host
```

The folder must contain:

```text
GodsAndLiars.exe
steam_api64.dll
steam_appid.txt
```

`steam_appid.txt` must contain development App ID `480`.

## 3. Layer A — one-client smoke test

Start Steam and sign in. Then:

```powershell
.\tools\run-steam-qa-client.ps1 `
  -BuildDir "C:\GodsAndLiars-QA\host" `
  -ClientLabel "host"
```

Validate:

- the process opens without an immediate crash;
- Steam initializes;
- the current lobby / transitional entry screen loads;
- hosting a match lobby does not throw an error;
- the client identity/name is populated;
- closing/leaving returns cleanly.

The QA logger is enabled automatically.

Expected log location:

```text
%APPDATA%\Godot\app_userdata\Gods & Liars\qa-session-host.log
```

## 4. Layer B — two real Steam clients

Use two different Steam accounts. Prefer two computers.

Validate:

- host creates a match lobby;
- second client can discover/join it;
- both see the same identities and seat assignments;
- READY synchronizes;
- PTT voice on `V` works;
- disconnect/leave returns cleanly to lobby state.

Two clients are intentionally insufficient to press gameplay START. This layer validates transport and voice only.

## 5. Layer C — rule/failure QA with fewer than eight

Four clients or synthetic peers may still be used to exercise isolated networking, disconnect, vote, night-action and privacy paths where the test harness does not require a valid commercial match start.

This is no longer a complete Mafia acceptance gate.

## 6. Layer D — eight-client full Mafia acceptance

The current commercial Mafia match target is exactly eight players. Use eight distinct Steam accounts for the real end-to-end acceptance run.

Run clients labeled:

```text
host
client2
client3
client4
client5
client6
client7
client8
```

Execute `docs/PHASE_8_STEAM_8CLIENT_CHECKLIST.md`.

The eight logs must agree on public state transitions while private events remain private:

- each client receives only its own role;
- only the Inquisitor log receives `local_investigation`;
- night deaths are identical across all logs;
- vote resolution is identical across all logs;
- match winner is identical across all logs;
- rematch resets life/roles while retaining the final Match Lobby peers/seats.

## 7. Party + Quick Match transition

The old lobby browser is transitional/debug infrastructure. The commercial entry architecture is documented in `docs/MATCHMAKING_ARCHITECTURE.md`:

`Party -> Quick Match -> Match Found -> Match Lobby -> Match`

Progressive search expands CLOSE -> DEFAULT -> FAR -> WORLDWIDE while preserving complete Parties and the exact target of eight players.

## 8. Assets from Blender

Rigged character assets should be exported as GLB/glTF 2.0 following `docs/ASSET_CONTRACT.md`.

Do not overwrite the placeholder architecture while validating the network loop. Import the real Body/Tunic/Mask assets through the existing modular avatar slots so networking and gameplay QA remain isolated from art iteration.
