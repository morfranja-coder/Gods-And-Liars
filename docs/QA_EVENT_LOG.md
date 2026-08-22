# Gods & Liars — QA Networking Event Log

## Purpose

`QAEventLog` records one JSON object per line so multiplayer failures can be reconstructed as a timeline instead of inferred from screenshots or player reports.

The logger is disabled by default and writes only when `GODS_LIARS_QA_LOG=1` is present in the environment.

Each record includes common context:

- monotonic milliseconds for ordering events inside one process;
- Unix wall-clock time for comparing different clients;
- QA client label;
- local SteamID and current Godot peer ID;
- Match Lobby ID;
- whether the process currently believes it is host;
- phase and round;
- event-specific payload.

Voice audio and voice packet contents are never logged.

## Important event families

### Network roster

- `lobby_state`
- `peer_joined`
- `peer_left`
- `peer_updated`

### Match authority

- `local_role_received`
- `phase_synced`
- `phase_timeout`
- `night_action_accepted`
- `local_night_action_result`
- `night_resolution`
- `local_investigation`
- `vote_accepted`
- `vote_resolution`
- `match_end`
- `rematch`

### Host migration

- `migration_backup_changed`
- `migration_voluntary_transfer_completed`
- `migration_voluntary_transfer_failed`
- `migration_host_loss_detected`
- `migration_promotion_ready`
- `migration_recovery_timed_out`
- `migration_transport_ready`
- `migration_transport_failed`
- `migration_reconnect_started`
- `migration_identity_restored`
- `migration_reconnect_completed`
- `migration_reconnect_failed`
- `migration_match_restored`
- `migration_restore_failed`
- `migration_fallback_started`
- `migration_fallback_completed`

### Match leave

- `match_leave_started`
- `match_leave_completed`
- `match_leave_rejected`
- `host_leave_cancelled`
- `party_preservation_failed`

## Two-account smoke setup

For the future Steam smoke, launch each build with a unique client label, for example `host` and `client-b`, while setting `GODS_LIARS_QA_LOG=1`.

The files are written separately as:

- `user://qa-session-host.log`
- `user://qa-session-client-b.log`

Because every line is standalone JSON, the two logs can later be sorted by wall-clock timestamp and compared with monotonic ordering inside each process.

## Exit gate

Point 5 is complete when CI confirms that the expanded logger parses, the record contract tests pass, and networking/migration/leave signals can be connected without runtime signature mismatches. The real two-account validation remains point 6.
