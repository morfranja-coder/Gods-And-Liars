# FASE 7 — Endgame / Ghost / Rematch Gate

FASE 7 closes the MVP match lifecycle after night and voting.

## Automated/code gate

- WIN_CHECK runs after night resolution and after sacrifice.
- Faithful side wins when no Heretics remain alive.
- Heretics win when living Heretics reach parity with the living faithful side.
- If no winner exists after night, the match enters DAY_DISCUSSION.
- If no winner exists after voting, the host starts the next night round.
- MATCH_END is synchronized by the host.
- All clients receive the same public winner value.
- Dead players remain connected as ghosts/spectators.
- Ghost voice routing remains separated from living-player transmission rules.
- Only the host can request a rematch.
- Rematch preserves Steam lobby, peers and authoritative seat IDs.
- Rematch clears local role, winner, votes, night actions and previous life state.
- Rematch revives all connected peers publicly before a fresh role reveal.
- Match end overlay is mounted in the table scene.

## Automated checks

Run locally from PowerShell:

```powershell
.\tools\verify-local.ps1
```

Expected result:

```text
GREEN: local quality gate passed.
```

GitHub CI must also remain green.

## Human gate

Use a real Steam match with at least four players/clients.

1. Reach a state where all Heretics are dead; every client must see Faithful victory.
2. Reach a state where living Heretics equal the remaining faithful side; every client must see Heretic victory.
3. A dead player remains in the table as a ghost/spectator and cannot act or vote.
4. A living player still follows normal day voice routing; dead players only speak to dead players.
5. Only the host sees/uses the rematch control.
6. Host starts rematch without leaving/recreating the Steam lobby.
7. All peers keep their synchronized seats.
8. Every peer is alive again.
9. Old roles/results are gone and a new private role reveal is delivered.
10. The new match can continue into the first night without restarting the game.

## Exit gate

FASE 7 is CLOSED when automated CI is green and the human Steam lifecycle above passes.
