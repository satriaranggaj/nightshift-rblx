# NIGHTSHIFT — Architecture

Phase-0 foundation. Intended dependency direction; deviations need justification.

## Layout

```
src/
  client/            StarterPlayerScripts/Client (Rojo: src/client)
    controllers/     per-feature client logic (vehicle, garage, race UI glue)
    input/           touch + keyboard + gamepad → VehicleInput
    camera/          chase/drift/nitro feel cameras
    ui/              HUD, menus (display only; no authority)
  server/            ServerScriptService/Server (Rojo: src/server)
    services/        Remote boundaries: validate, then delegate to domain
    systems/         world/race/garage orchestration
    security/        rate limits, ownership checks, transition guards
  shared/            ReplicatedStorage/Shared (Rojo: src/shared)
    config/          data tables only (no behavior)
    types/           contracts: Types.luau (VehicleInput, RaceState, identity)
    networking/      Remote names + payload shapes (deferred to Phase 11/14)
    vehicle/         shared vehicle math helpers + stat interfaces (deferred)
tests/               mirrors src/, *.spec.luau (runner chosen at Phase 1)
docs/                ARCHITECTURE.md, ROADMAP.md
```

## Dependency direction (game systems)

```
UI (display only)
  ↓ calls
Client Controllers (input aggregation, prediction display)
  ↓ invokes
Networking abstraction (Remotes; validated boundary)
  ↓ handled by
Server Services (validate identity/ownership/state/rate → delegate)
  ↓ calls
Domain modules (races, vehicles, economy rules; server-authoritative)
  ↓ persists via
Persistence (DataStores; schema-versioned, migrated explicitly)
```

Rules: UI never touches Remotes directly except through controllers; services
never trust client values; domain never depends on UI/controllers; config never
imports runtime. No cycles; `Shared/Types` is depended upon, depends on nothing.

## Vehicle pipeline (all platforms, one physics)

```
Mobile (touch/tilt) ──┐
PC (keyboard) ────────┼──> VehicleInput ──> VehicleController ──> Vehicle Simulation ──> Vehicle State
Controller (gamepad) ─┘       (normalized)      (arcade)               (single impl)          (replicated)
```

- `VehicleInput`: `{ throttle 0..1, brake 0..1, steer -1..1, drift bool, nitro bool }`.
  Platform layers adapt (auto-throttle, smoothing, speed-sensitive steer);
  physics never branches per platform.
- Phase 2 realized the pipeline with concrete modules (no contract change):
  `client/input/*` → `shared/vehicle/VehicleInput` (sanitize) →
  `client/controllers/VehicleController` (lifecycle + force application) →
  `shared/vehicle/ArcadeChassis.step` (pure policy: forward/brake/reverse/coast
  targets, smoothed steer, standstill-scaled yaw) + `shared/config/ChassisConfig`
  (data only; `TEST_BLOCKOUT` rig values) → single-assembly VectorForce /
  AngularVelocity / AlignOrientation constraints. Rotational separation is
  structural: AngularVelocity owns yaw; AlignOrientation owns upright ONLY via
  primary-axis alignment (attachment X rolled onto chassis up, goal = world up),
  so it can never command yaw. Driver's client simulates via
  NetworkOwnership; server re-simulation/plausibility is a Phase 11 concern.

## Why this structure (Roblox fit)

- Matches Rojo service mapping (Client/Server/Shared) so sync is 1:1 and Studio
  stays an editor/tester, never a code store.
- Keeps server authority legible: every client→server crossing sits in
  `services/` + `security/` where review checklists apply.
- Defers what is unknown (networking payloads, persistence schema, stat math)
  to the phases that need them, instead of speculative abstractions now.
