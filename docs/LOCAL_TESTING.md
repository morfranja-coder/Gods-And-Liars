# Gods & Liars — Local testing workflow

This document is for the Windows development workstation.

## Engine separation

Gods & Liars remains a Godot 4.7 project. `project.godot` declares Godot 4.7 and the Steam runtime gate is pinned to GodotSteam 4.20 / Godot 4.7 / Steamworks SDK 1.64.

Godot 4.6 is installed side-by-side only as an auxiliary editor/MCP target. Do not resave Gods & Liars scenes or `project.godot` from Godot 4.6.

## 1. Install Godot 4.6 + QA MCP

From the repository root in PowerShell:

```powershell
.\tools\setup-local-godot46-mcp.ps1
```

This installs the official Godot 4.6 stable Windows x86_64 editor under the current user's LocalAppData and registers a separate Codex MCP named:

```text
godot46-visual
```

The MCP is pinned to Godot MCP Enhanced 0.26.0 and is configured as a QA-oriented local tool. It does not change the Gods & Liars engine target.

Requirements:

- Windows x86_64;
- Node.js 18+ with `npx`;
- Codex CLI available in PATH.

Use Codex only for visual/runtime QA in this project. Programming and repository changes remain outside that QA role.

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
- the lobby screen loads;
- hosting a lobby does not throw an error;
- the client identity/name is populated;
- closing/leaving returns cleanly.

The QA logger is enabled automatically.

Expected log location:

```text
%APPDATA%\Godot\app_userdata\Gods & Liars\qa-session-host.log
```

## 4. Layer B — two real Steam clients

Use two different Steam accounts. Prefer two computers.

Host:

```powershell
.\tools\run-steam-qa-client.ps1 `
  -BuildDir "C:\GodsAndLiars-QA\host" `
  -ClientLabel "host"
```

Second machine/client:

```powershell
.\tools\run-steam-qa-client.ps1 `
  -BuildDir "C:\GodsAndLiars-QA\client2" `
  -ClientLabel "client2"
```

Validate:

- host creates lobby;
- client can discover/join it;
- both see the same identities and seat assignments;
- READY synchronizes;
- PTT voice on `V` works;
- disconnect/leave returns cleanly to lobby state.

Two clients are intentionally insufficient to press gameplay START. The full Mafia match requires four players.

## 5. Layer C — four-client full Mafia acceptance

Use four distinct Steam accounts. Run the same launcher with labels `host`, `client2`, `client3`, and `client4`.

Execute the complete checklist in `docs/PHASE_8_STEAM_4CLIENT_CHECKLIST.md`.

The four logs must agree on public state transitions while private events remain private:

- each client receives only its own role;
- only the Inquisitor log receives `local_investigation`;
- night deaths are identical across all logs;
- vote resolution is identical across all logs;
- match winner is identical across all logs;
- rematch resets life/roles while retaining lobby/peers/seats.

## 6. Assets from Blender

Rigged character assets should be exported as GLB/glTF 2.0 following `docs/ASSET_CONTRACT.md`.

Do not overwrite the placeholder architecture while validating the network loop. Import the real Body/Tunic/Mask assets through the existing modular avatar slots so networking and gameplay QA remain isolated from art iteration.
