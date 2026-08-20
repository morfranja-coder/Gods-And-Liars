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

The Windows export job uploads `GodsAndLiars-Windows` as an internal GitHub Actions artifact.

Important: this CI job uses official Godot and proves that the project can parse, test, and export a valid Windows PE executable. It does not by itself prove that Steam networking is available in that executable.

## 2. Local quality gate

From PowerShell:

```powershell
.\tools\verify-local.ps1
```

Expected final line:

```text
GREEN: local quality gate passed.
```

## 3. Steam runtime dependency gate

Gods & Liars currently uses two runtime capabilities:

- the `Steam` singleton for lobbies, identity, callbacks, and voice;
- `SteamMultiplayerPeer` for Godot high-level multiplayer over Steam.

The normal GodotSteam GDExtension exposes the Steam API but does not provide the GodotSteam `SteamMultiplayerPeer` implementation used by this project. Installing only `addons/godotsteam/godotsteam.gdextension` is therefore not sufficient for the current networking stack.

The pinned MVP target is:

- Godot 4.7.x;
- Steamworks SDK 1.64;
- GodotSteam 4.20 / 4.20.1 compatible runtime;
- a GodotSteam MultiplayerPeer/module build that exposes both `Steam` and `SteamMultiplayerPeer`;
- development App ID 480 until a real Steam App ID is assigned.

Reference naming used by the GodotSteam 4.7 builds:

```text
g47   = Godot 4.7
s164  = Steamworks SDK 1.64
gs420 = GodotSteam 4.20
```

Do not combine a GodotSteam module/MultiplayerPeer build with the normal GodotSteam API GDExtension. They implement overlapping Steam bindings.

The legacy helper `tools/install-godotsteam.ps1` installs only the API GDExtension and now prints an explicit warning. It is not the release path for the current MVP architecture.

## 4. Verify Steam runtime

With the intended GodotSteam editor/runtime binary:

```powershell
& "C:\path\to\godotsteam.exe" --headless --path . --script res://tools/verify-steam-runtime.gd
```

Expected output:

```text
GREEN: Steam runtime exposes Steam + SteamMultiplayerPeer
```

If either capability is absent, release validation must stop.

## 5. Windows build

After the matching export templates for the selected GodotSteam runtime are installed:

```powershell
.\tools\build-windows.ps1 -GodotBinary "C:\path\to\godotsteam.exe"
```

Expected output:

```text
build/windows/GodsAndLiars.exe
```

The build script validates that the result exists, is non-trivial in size, and has a Windows PE `MZ` header.

## 6. Final release-readiness gate

Run the gate with the intended GodotSteam runtime binary:

```powershell
.\tools\release-check.ps1 -GodotBinary "C:\path\to\godotsteam.exe"
```

It checks:

1. the local automated quality gate;
2. the Windows export preset;
3. development App ID 480;
4. `Steam` is present;
5. `SteamMultiplayerPeer` is present;
6. a Windows release export is produced and retained.

Expected final line:

```text
GREEN: release readiness gate passed.
```

## 7. Human multiplayer acceptance gate

Use real Steam clients. Four players are the minimum for the complete Mafia loop.

1. Host creates lobby.
2. Three clients join.
3. All four identities and seats match on every client.
4. All players READY.
5. Host starts.
6. All clients enter the ritual table.
7. Every client receives exactly one private role.
8. Every client confirms role reveal.
9. Night phases advance in order.
10. Only the active role can submit its action.
11. Night deaths synchronize on every client.
12. Inquisitor result is visible only to the Inquisitor.
13. Day voice routing follows living/dead rules.
14. Host opens voting.
15. Every living player votes; invalid/dead votes are rejected.
16. Sacrifice or tie synchronizes correctly.
17. Win condition resolves identically on every client.
18. Dead players remain ghosts/spectators.
19. Host starts rematch.
20. Same lobby/peers/seats are retained, everyone is alive again, and new roles are dealt.
21. Host disconnect ends the session cleanly for clients.

## Exit gate

FASE 8 is CLOSED only when:

- CI is green including the Windows export job;
- `release-check.ps1` is green using a runtime that exposes both Steam capabilities;
- the real four-client Steam acceptance loop passes.

Until those three gates pass, the repository is code-complete for the MVP loop but not yet declared release-ready.
