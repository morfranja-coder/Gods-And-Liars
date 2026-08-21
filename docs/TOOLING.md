# Gods & Liars — Tooling Lock

This file freezes the development tooling used by the 72-hour MVP.

## Engine
- Godot 4.7.x is the project/runtime target.
- Godot 4.6 stable may be installed side-by-side on the Windows workstation as an auxiliary MCP/QA target only. It must not be used to resave the Gods & Liars project.

## Godot addons
- GdUnit4 `v6.2.0`
- Godot State Charts `v0.22.5`
- GodotSteam: runtime dependency, validated separately with Steam
- Maaack Input Remapping: planned, but not promoted to mandatory until it passes a Godot 4.7 smoke test
- Sentry: deferred until before public alpha

Third-party Godot addons are installed locally by:

```powershell
./tools/setup-dev-tools.ps1
```

Use `-Force` to refresh the pinned versions.

## Local visual/runtime QA MCP

- Godot MCP Enhanced is used as the local visual/runtime QA bridge.
- The dedicated Godot 4.6 registration is named `godot46-visual`.
- The helper pins MCP package version `0.26.0` and binds it to the locally installed Godot 4.6 executable.
- Codex remains QA-only for this workflow: screenshots, runtime inspection, visual verification, and diagnostics; it is not the programming/commit agent for Gods & Liars.

Windows setup:

```powershell
./tools/setup-local-godot46-mcp.ps1
./tools/check-local-qa-prereqs.ps1
```

The complete workstation/game testing sequence is documented in `docs/LOCAL_TESTING.md`.

## QA / security
- GdUnit4 for unit/integration/scene tests
- Existing Godot headless smoke tests remain enabled
- gdtoolkit / gdlint in CI
- Gitleaks in CI
- GitHub Actions as the quality gate

## CI order
1. Gitleaks secret scan
2. gdtoolkit / gdlint
3. Install pinned addons
4. Godot 4.7 headless import/parse
5. Existing smoke tests
6. GdUnit4 tests
7. Windows release export
8. GodotSteam multiplayer runtime export

## Why addons are not committed
`addons/gdUnit4/` and `addons/godot_state_charts/` are reproducibly downloaded from pinned GitHub tags. Keeping them out of the repository avoids thousands of third-party files while preserving deterministic setup in local development and CI.

## Current GdUnit4 coverage
- eight-player role distribution
- vote tie behavior
- healer preventing a night kill

Next tests should cover dead-player restrictions, win conditions, READY authority, illegal role actions, disconnects, and full simulated rounds.
