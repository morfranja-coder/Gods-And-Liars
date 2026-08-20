# FASE 2 — Validation Gate

FASE 2 covers only the pre-match multiplayer lobby. Table, avatars and roles are out of scope.

## Automated/code gate

- Roster is synchronized by the host.
- READY changes are requested by clients and replicated by the host.
- READY RPC requests are rate-limited on the host.
- Only the host may start.
- Start requires at least two connected peers and every peer READY.
- Host start is replicated to every peer.
- Lobby becomes frozen after START: no late joins, no READY changes, no double start.
- Client disconnect removes it from the roster and clears rate-limit state.
- Host disconnect tears down the client session and preserves a visible host-disconnected state.
- Re-entry starts with a clean roster, READY state, lobby-started flag and rate-limit state.
- A Steam identity can rejoin after its previous peer disconnects, but duplicate live Steam IDs are rejected.
- New peers cannot exceed the 10-player lobby capacity.
- Invalid, blank or oversized identities are rejected/sanitized.
- Push-to-talk uses Steam voice capture and unreliable RPC packets.
- Voice packets from unknown peers are rejected.
- Compressed and decompressed voice payloads have hard size limits.

## Automated checks

Run locally from PowerShell:

```powershell
.\tools\verify-local.ps1
```

The gate must complete with:

```text
GREEN: local quality gate passed.
```

GitHub CI performs the equivalent layers: Gitleaks, gdlint, Godot 4.7 import/parse, smoke tests and GdUnit4 tests.

## Human Steam gate

Use two PCs / two Steam accounts with Steam open and a GodotSteam build compatible with Godot 4.7.

1. Host creates a ritual.
2. Client refreshes and joins it.
3. Both machines show the same two Steam names in the roster.
4. Client presses `Listo`; both machines show that client as `LISTO`.
5. Host presses `Listo`; both machines show both players as `LISTO`.
6. Only the host has an enabled `Iniciar` button.
7. Host presses `Iniciar`; both machines show `FASE 2 OK: inicio sincronizado por el host.`
8. READY and START controls remain locked after start.
9. Hold `V` on host and speak. Client must hear host.
10. Hold `V` on client and speak. Host must hear client.
11. Client leaves. Host roster returns to one player.
12. Repeat a join/leave cycle once to verify clean re-entry.
13. In a fresh lobby, host disconnects. Client must show `El host abandonó el ritual. Volviste al lobby.` and roster must return to zero.
14. Without restarting the client, refresh/create/join another lobby to prove session state was fully cleared.

## Exit gate

FASE 2 is CLOSED only when the automated quality gate is green and steps 1–14 pass on real Steam clients.
