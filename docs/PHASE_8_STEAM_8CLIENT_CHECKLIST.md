# FASE 8 — Steam 8-client acceptance checklist

This is the final human exact-8 networking gate for the current Mafia rules.

## Preparation

1. Use the `GodsAndLiars-Steam-Windows` artifact from the exact green commit under test.
2. Confirm `GodsAndLiars.exe`, `steam_api64.dll` and `steam_appid.txt`.
3. Confirm development App ID `480`.
4. Use eight distinct Steam accounts.
5. Launch clients with unique QA labels: `host`, `client2` ... `client8`.
6. Record the tested Git commit before starting.

## Party + Quick Match

- [ ] A solo Party can enter Quick Match.
- [ ] A Party is never split.
- [ ] Exact compositions such as 5+3 can converge to 8/8.
- [ ] Multiple Parties such as 4+2+1+1 can converge to 8/8.
- [ ] Any composition that would exceed 8 is rejected.
- [ ] Search expands CLOSE -> DEFAULT -> FAR -> WORLDWIDE.
- [ ] All members of a Party follow the same compatible Match target.
- [ ] A follower with uncached lobby metadata waits for Steam metadata validation instead of joining blindly or rejecting a valid target prematurely.
- [ ] Protocol mismatch fails closed.
- [ ] No ninth player can enter the Match Lobby.

## Match Lobby

- [ ] All eight clients show the same eight players.
- [ ] `seat_id` values are unique and agree across instances.
- [ ] READY synchronizes.
- [ ] START remains blocked at 7/8.
- [ ] Host can start only at exact 8/8 with the required readiness.

## Roles and privacy

- [ ] All eight enter the table scene.
- [ ] Every player occupies the same seat on every client.
- [ ] Each client receives exactly one private role.
- [ ] No client learns the complete role map.
- [ ] Distribution is exactly 2 Heretics, 1 Priest, 1 Inquisitor, 4 Faithful.
- [ ] Only living Heretics receive the private current-decider identity.
- [ ] Non-Heretics never receive the private decider.
- [ ] Role reveal acknowledgement converges.

## Night 1 — mandatory special rule

- [ ] Exactly one living Heretic is the decider.
- [ ] The decider can target a living non-Heretic.
- [ ] A non-decider Heretic cannot submit the attack.
- [ ] A Heretic cannot target another Heretic.
- [ ] God privately warns the Priest of the intended victim.
- [ ] Priest protection is automatic on that victim.
- [ ] Priest does not manually choose a Night-1 target.
- [ ] Inquisitor does not act on Night 1.
- [ ] Nobody dies on Night 1.
- [ ] All clients converge to the same public night result.

## Night 2+

- [ ] Heretic decider rotates by round.
- [ ] Priest can protect a legal living target.
- [ ] Priest can self-save once per match.
- [ ] A second Priest self-save is rejected.
- [ ] Inquisitor can investigate a legal target.
- [ ] Investigation result appears only on the Inquisitor client.
- [ ] Dead/disconnected players cannot submit night actions.
- [ ] Dead players cannot be selected as legal night targets.
- [ ] Public deaths converge on all clients.

## Voice

- [ ] Voice routing is muted during phases where design requires silence.
- [ ] During day, living players hear living players.
- [ ] Dead players can hear living players.
- [ ] Dead-player voice does not reach living players.
- [ ] Dead players can speak to other dead players.
- [ ] PTT on `V` does not loop local audio.

## Day, voting and sacrifice

- [ ] All living players enter one simultaneous voting window.
- [ ] Every living player may submit at most one vote.
- [ ] A submitted vote cannot be replaced.
- [ ] Self-vote is rejected.
- [ ] Dead players cannot vote.
- [ ] Dead players cannot be valid vote targets.
- [ ] Votes received after leaving VOTING are ignored.
- [ ] Unique top target produces exactly one sacrifice.
- [ ] 2-2-2-2 tie is marked tied and resolves to one of the four tied top targets.
- [ ] 3-3-1-1 tie is marked tied and resolves to one of the two tied top targets.
- [ ] Every client receives the same authoritative tied result.
- [ ] Alive/dead public state agrees across all eight clients.

## Disconnects

- [ ] A disconnected player becomes unavailable/dead for the current match.
- [ ] Pending night actions or votes involving that player are removed as required.
- [ ] Public vote state resynchronizes after a voting disconnect.
- [ ] If the only living Priest disconnects during the Priest phase, the server advances without waiting for an impossible action.
- [ ] Same behavior for the only living Inquisitor.
- [ ] If the active Heretic decider disconnects, another living Heretic is selected without restarting the whole phase.
- [ ] If the host leaves, the current match ends cleanly.
- [ ] Host migration does not occur in the MVP.

## Victory and rematch

- [ ] Faithful win when no Heretics remain.
- [ ] Heretics win when living Heretics reach parity with living non-Heretics.
- [ ] All clients show the same winner.
- [ ] Rematch resets living state and private roles without leaking the previous role map.
- [ ] Match Lobby roster/seats remain coherent through the intended rematch flow.

## Logs and privacy

Compare public events across all clients:

```text
lobby_state
peer_updated
phase_synced
night_resolution
vote_resolution
match_end
rematch
```

Private events are intentionally different:

- `local_role_received` belongs only to that client;
- `local_investigation` appears only for the Inquisitor;
- Priest warning appears only for the Priest;
- private Heretic decider data appears only for Heretics;
- no client log may contain the complete authoritative role map.

## Exit gate

The human FASE 8 gate is GREEN only when one complete exact-8 Steam match finishes without public-state divergence or private-information leakage and the intended rematch/exit flow also succeeds.
