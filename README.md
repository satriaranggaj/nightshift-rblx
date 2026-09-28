# NIGHTSHIFT

Multiplayer open-world street-racing RPG (Roblox/Luau) — mobile-first, arcade handling, fictional vehicles.

## Status

Phase 0 (foundation). No gameplay yet. See `docs/ROADMAP.md`.

## Quickstart (Studio + Rojo)

1. Install Rokit, then project tools:
   - `rokit install`
2. Serve/sync with Roblox Studio (Rojo plugin required):
   - `rojo serve` — connect from Studio, or
   - `rojo build -o build/NIGHTSHIFT.rbxlx` — open the built place in Studio.
3. Checks:
   - `stylua --check src tests`
   - `selene src tests` (config: `selene.toml`)
   - Luau strict (` .luaurc`); Studio script analysis must be clean.
   - `codegraph status` — index healthy; see AGENTS.md workflow.

## Rules

Read `AGENTS.md` before any change. One feature per task; server-authoritative
economy/ownership/rewards; no silent contract, persistence, or economy changes.
