# FASE 2 — Validation Gate

FASE 2 covers only the pre-match multiplayer lobby. Table, avatars and roles are out of scope.

## Automated/code gate

- Roster is synchronized by the host.
- READY changes are requested by clients and replicated by the host.
- Only the host may start.
- Start requires at least two connected peers and every peer READY.
- Host start is replicated to every peer.
- Client disconnect removes it from the roster.
- Host disconnect returns clients to the offline lobby state.
- Push-to-talk uses Steam voice capture and unreliable RPC packets.

## Human Steam gate

Use two PCs / two Steam accounts with Steam open and a GodotSteam build compatible with Godot 4.7.

1. Host creates a ritual.
2. Client refreshes and joins it.
3. Both machines show the same two Steam names in the roster.
4. Client presses `Listo`; both machines show that client as `LISTO`.
5. Host presses `Listo`; both machines show both players as `LISTO`.
6. Only the host has an enabled `Iniciar` button.
7. Host presses `Iniciar`; both machines show `FASE 2 OK: inicio sincronizado por el host.`
8. Hold `V` on host and speak. Client must hear host.
9. Hold `V` on client and speak. Host must hear client.
10. Client leaves. Host roster returns to one player.

## Exit gate

FASE 2 is CLOSED only when steps 1–10 pass on real Steam clients.
