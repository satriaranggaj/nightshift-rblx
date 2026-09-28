# NIGHTSHIFT — AGENTS.md

Multiplayer open-world street-racing RPG (Roblox/Luau). Fictional vehicles only.
Mobile-first (Mobile > PC > Controller), arcade handling. Repo is source of truth; Studio is for world edit + playtest via Rojo sync.

## Architecture principles

- Modular service/controller layout: `src/client/` (controllers,input,camera,ui), `src/server/` (services,systems,security), `src/shared/` (config,types,networking,vehicle). See `docs/ARCHITECTURE.md`.
- One major feature per task. Extend abstractions, don't rewrite working systems or duplicate logic.
- Explicit module APIs, no hidden globals, no circular deps. Config separate from runtime.
- Vehicle stat calculation has ONE authoritative path (server domain module). UI/garage/controllers call it; never reimplement.
- Vehicle pipeline: `Platform Input → VehicleInput → VehicleController → Vehicle Simulation → Vehicle State`. One physics impl for all platforms.
- Race lifecycle is an explicit state machine (`CREATED→WAITING→READY→COUNTDOWN→RUNNING→FINISHED|CANCELLED`, see `src/shared/Types.luau`). No scattered booleans.

## Client / server authority

- Server decides: currency, prices, purchases, ownership, rewards, upgrades, progression, race results/membership/state.
- Client NEVER grants or determines the above. Never trust client prices, rewards, or `I won` claims.
- RemoteEvents/Functions are untrusted boundaries. Validate identity, ownership, race membership/state, eligibility, rate limits, and impossible transitions server-side.
- No wagering/gambling-like systems, no irreversible P2P vehicle transfers (deferred; needs transactional design + policy review).

## Networking rules

- Changing a Remote contract, persistence format, or economy behavior is BREAKING: call it out, migrate explicitly, never silently.
- Keep client/server responsibilities explicit. Security-sensitive math stays on server.

## Vehicle rules

- Normalized input only: `throttle 0..1, brake 0..1, steer -1..1, drift bool, nitro bool` (`src/shared/Types.luau`). Platform layers (touch/keyboard/gamepad) adapt to this; physics never branches per platform.
- Arcade feel, sophisticated internals (torque/grip/traction/steer curve/brake/drift/nitro params) when phases demand. No sim physics unless asked.
- Owned vehicles are unique assets (`vehicleUuid, ownerUserId, modelId` + parts/state), never a bare `owns Model X` flag. Full schema deferred to Garage/Tuning phases.

## Mobile-first

- Every driving/camera/UI change must consider touch: auto-throttle compat, speed-sensitive + smoothed steering, readable HUD, no keyboard-only flows. Note PC/controller impact in the PR/test steps.

## Required change workflow (existing systems)

1. Read this file. 2. `git status`. 3. Identify target modules/symbols.
4. Query CodeGraph (callers/callees/deps/impact; check for cycles). If Luau syntax misparses, note it and fall back to `rg`/reads — never invent graph results.
5. Read the implementation. 6. Bounded plan. 7. Minimal edits. 8. `stylua` + `selene` + typecheck. 9. Relevant tests. 10. Re-check impact. 11. Review `git diff`. 12. Studio/manual steps (required for gameplay; never claim feel from static code).

## Tests

- `tests/` mirrors `src/`; name `*.spec.luau`. Shared/domain changes need tests. Gameplay needs device/Studio validation (mobile + PC at minimum).

## Scope rules

- No unrelated refactors, no speculative abstractions, no silent contract/format/economy changes. Conflicts with architecture → explain before coding.

## Definition of done

Architecture understood · scope bounded · formatted · lint/type/tests green · no new cycles · network boundaries validated · diff reviewed · Studio steps provided · mobile (+PC/controller) considered.

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
