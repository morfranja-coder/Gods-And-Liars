# FASE 3 — Table + Avatars Validation Gate

FASE 3 covers the synchronized ritual table, fixed seats and modular technical avatars. Real GLB art may be swapped in later as long as it follows `docs/ASSET_CONTRACT.md`.

## Automated/code gate

- Exactly 10 deterministic seat markers exist.
- The host assigns `seat_id`; clients render that synchronized value instead of recalculating locally.
- Seats are unique while a peer is connected and can be reused after disconnect.
- The lobby roster displays the synchronized seat number.
- START transitions every client from lobby to `res://scenes/table/table.tscn`.
- Each roster peer with a valid seat gets exactly one avatar.
- Avatars update when `NetworkManager.peer_updated` fires.
- Technical body placeholder remains visible until a real `body_scene` is assigned.
- Runtime avatar slots remain `Body`, `Tunic`, `Mask`.
- Left-click raycasts only against avatar selection areas and resolves a peer id locally.
- No continuous player transforms are sent over the network.

## Automated checks

Run locally from PowerShell:

```powershell
.\tools\verify-local.ps1
```

GitHub CI must keep both `Secret scan` and `Godot quality gate` green.

## Human Steam gate

Use two PCs / two Steam accounts.

1. Complete the FASE 2 lobby gate and press `Iniciar` as host.
2. Both machines change to the ritual table scene.
3. Both machines show the same roster players at the same seat positions.
4. No two players occupy the same seat.
5. Player names appear above the correct technical avatars.
6. Clicking another avatar selects that peer locally without moving either avatar.
7. Disconnect the client before a new match, reconnect, and verify the host assigns an available seat cleanly.
8. Replace one technical avatar slot with a contract-compliant GLB and verify table/network code does not need modification.

## Exit gate

FASE 3 is CLOSED when CI is green and steps 1–7 pass on real Steam clients. Step 8 is the art-pipeline integration gate and may use the first rigged production GLB when available.
