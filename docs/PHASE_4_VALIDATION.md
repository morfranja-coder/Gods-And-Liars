# FASE 4 — Private Roles Validation Gate

FASE 4 covers authoritative role assignment and private role reveal only. Night actions are FASE 5.

## Automated/code gate

- Only the host builds and owns the complete `MatchSession` role map.
- Clients never receive the role map.
- Each peer receives one reliable targeted RPC containing only its own role value.
- Client-side `MatchAuthority` stores only `local_role`; `_session` remains null.
- Invalid role values are rejected.
- Authoritative `seat_id` values are preserved when the host builds the match session.
- Role reveal UI reads only the validated local role.
- Leaving/failing/disconnecting clears local private role state.
- Table scene mounts the private role reveal overlay.
- Role assignment requires at least 4 players; the 2-player lobby gate remains available only for earlier transport validation.

## Automated checks

Run locally from PowerShell:

```powershell
.\tools\verify-local.ps1
```

GitHub CI must remain green for Gitleaks, gdlint, Godot import/parse, smoke tests and GdUnit4.

## Human multiplayer gate

Use at least 4 connected players/clients for actual role assignment.

1. Host starts the ritual with 4+ READY players.
2. Every client transitions to the table.
3. Every client sees exactly one private role panel.
4. The role is one of: Fiel, Hereje, Sanador, Inquisidor.
5. No client UI exposes another player's role.
6. Inspecting client-side gameplay state must not reveal a role dictionary/map; only `local_role` exists.
7. Closing the panel hides it without changing the role.
8. Leaving the lobby and joining a new session clears the previous role before a new reveal.

## Exit gate

FASE 4 is CLOSED when automated CI is green and the 4+ client private-role gate passes without cross-client role leakage.
