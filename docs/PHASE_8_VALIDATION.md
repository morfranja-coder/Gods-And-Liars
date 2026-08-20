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

## 2. Local quality gate

From PowerShell:

```powershell
.\tools\verify-local.ps1
```

Expected final line:

```text
GREEN: local quality gate passed.
```

## 3. GodotSteam dependency gate

A normal Godot export can succeed without the Steam GDExtension, but that build is not a functional Steam multiplayer build.

The pinned MVP target remains:

- GodotSteam GDExtension 4.20.1.
- Steamworks SDK 1.64.
- Godot 4.7.x.
- Development App ID 480 until a real Steam App ID is assigned.

Install the official pinned ZIP locally with:

```powershell
.\tools\install-godotsteam.ps1 -ZipPath "C:\path\to\official-godotsteam-4.20.1.zip"
```

The installer must produce:

```text
addons/godotsteam/godotsteam.gdextension
```

Do not mix the GDExtension package with a GodotSteam module/custom engine build.

## 4. Windows build

After Godot export templates are installed:

```powershell
.\tools\build-windows.ps1
```

Expected output:

```text
build/windows/GodsAndLiars.exe
```

## 5. Final release-readiness gate

Run:

```powershell
.\tools\release-check.ps1
```

It checks:

1. the local automated quality gate;
2. the Windows export preset;
3. development App ID 480;
4. the GodotSteam GDExtension is actually present;
5. a Windows release export is produced.

Expected final line:

```text
GREEN: release readiness gate passed.
```

## 6. Human multiplayer acceptance gate

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
- `release-check.ps1` is green with GodotSteam installed;
- the real four-client Steam acceptance loop passes.

Until those three gates pass, the repository is code-complete for the MVP loop but not yet declared release-ready.
