# NIGHTSHIFT — Roadmap (incremental, testable)

Each milestone: goal · scope · excluded · prerequisites · acceptance · Studio validation.
Do not jump ahead; one milestone per task.

## Phase 0 — Project foundation ✅ (this bootstrap)

- Goal: AI-friendly, CodeGraph-aware Rojo repo.
- Scope: git, Rojo map, stylua/selene/rokit, AGENTS.md, ARCHITECTURE.md, ROADMAP.md, `Types.luau` contracts, empty module dirs.
- Excluded: gameplay, Remotes, persistence, TestEZ/content.
- Acceptance: `rokit install` → `rojo build` succeeds; stylua/selene clean; CodeGraph indexes Luau; Studio syncs empty base.
- Studio: connect Rojo plugin, sync, playtest empty base (no errors in output).

## Phase 1 — Vehicle input abstraction ✅

- Goal: all platforms produce `VehicleInput` (Types.luau).
- Scope: input module + keyboard + stub touch/gamepad adapters, clamping/validation unit tests.
- Excluded: chassis, movement, UI polish.
- Prereq: Phase 0.
- Acceptance: same logical gesture → identical `VehicleInput` on all adapters; bounds enforced; tests green.
- Studio: PC keyboard drives a debug readout; mobile emulator shows touch stub values.

## Phase 2 — Basic arcade chassis ✅

- Goal: one test block-car moves from `VehicleInput` (PC-first, touch-compatible).
- Scope: single physics impl (accel/brake/grip baseline), spawn-on-pad harness.
- Excluded: drift, nitro, tuning, camera work.
- Acceptance: throttle/brake/steer responsive at low speed; no platform branches in physics.
- Studio: drive on flat baseplate, PC + mobile emulator.

## Phase 3 — Mobile steering

- Goal: touch steering feels responsive.
- Scope: touch steer widget + smoothing + speed-sensitive curve; auto-throttle hook point.
- Excluded: tilt, drift/nitro.
- Acceptance: full-lock at low speed, damped at high speed; no oscillation.
- Studio: human feel test on real mobile-sized viewport + PC regression.

## Phase 4 — Acceleration / braking / reverse

- Scope: throttle curve, brake vs reverse state, stopped→reverse transition guard.
- Excluded: drift, nitro.
- Acceptance: predictable stop, no accidental reverse at speed; mobile buttons + PC keys both work.
- Studio: 0→top→stop→reverse runs, both platforms.

## Phase 5 — Speed-sensitive steering

- Scope: steer-angle vs speed curve + smoothing params as data (not hardcoded per platform).
- Excluded: drift/nitro/camera.
- Acceptance: stable at top speed, agile at low speed; params reviewable in one config.
- Studio: slalom feel check, mobile + PC.

## Phase 6 — Assisted drift

- Scope: drift flag → grip/angle assist on the single chassis; touch-friendly tap-hold.
- Excluded: nitro, scoring.
- Acceptance: beginners can hold slides, experts can modulate; no spin-out lottery.
- Studio: figure-8 drift feel, mobile first.

## Phase 7 — Nitro

- Scope: nitro state, charge/regen rules (server-authoritative later), FOV/speed feedback hooks.
- Excluded: economy, persistence.
- Acceptance: boost is legible + interruptible; no client-granted charge.
- Studio: straight-line + corner-exit checks.

## Phase 8 — Arcade camera

- Scope: chase cam (lag, FOV-with-speed, shake limits), mobile-readable framing.
- Excluded: photo mode.
- Acceptance: speed communicated without motion sickness; HUD readable on phones.
- Studio: human feel pass, small + large screens.

## Phase 9 — Enter / exit vehicle

- Scope: proximity prompt → seat → leave, single test vehicle; ownership stub.
- Excluded: garage, persistence.
- Acceptance: no stuck states; replicated seat state.
- Studio: walk→enter→drive→exit loop, multiplayer smoke (2 players).

## Phase 10 — Vehicle configuration framework

- Scope: data-driven vehicle params + ONE stat-calc path (server domain module; UI calls it).
- Excluded: purchasable parts, full tuning list.
- Acceptance: two configs feel different; no duplicated stat math.
- Studio: A/B drive of two configs.

## Phase 11 — Multiplayer replication / authority review

- Scope: input replication, server reconciliation review, exploit pass (speed/teleport/rate).
- Excluded: new features.
- Acceptance: 2+ players drive together; impossible transitions rejected server-side.
- Studio: multi-client playtest.

## Phase 12 — Garage prototype (physical)

- Scope: walk-in spot, inspect/select/spawn one vehicle.
- Excluded: tuning visuals, selling, capacity progression.
- Acceptance: select→spawn→drive→return loop works.
- Studio: in-world flow test.

## Phase 13 — Small open-world district

- Scope: one drivable block (roads, lot for meets, collision sanity).
- Excluded: city scale, traffic.
- Acceptance: 60s loop drivable, meet spot fits 4+ cars.
- Studio: drive + meet smoke test.

## Phase 14 — Player-created race prototype

- Scope: create (sprint, checkpoints, 2+ players) → state machine → host start → finish detection → spectate.
- Excluded: all race types, wagering, rewards economy.
- Acceptance: full `CREATED→…→FINISHED|CANCELLED` transitions enforced server-side; client `I won` ignored.
- Studio: 2-player race + 1 spectator.

## Phase 15 — Economy (server-authoritative)

- Scope: currency, purchase/reward flows, server-validated grants; DataStore schema v1 (versioned).
- Excluded: P2P transfers, premium monetization.
- Acceptance: no client path grants value; double-grant/retry safe.
- Studio: earn→buy smoke; exploit attempt (forged Remote) rejected.

## Phase 16 — Tuning (performance, data-driven)

- Scope: parts list wired through the single stat path + eligibility/ownership checks.
- Excluded: visual parts.
- Acceptance: parts change handling measurably; no UI-side stat forks.
- Studio: before/after drive comparison.

## Phase 17 — Visual customization (display only)

- Scope: appearance parts as replicated display state; no stat effect.
- Excluded: livery editor depth.
- Acceptance: visuals replicate; stats provably unchanged.
- Studio: meet show-off pass.

## Phase 18+ — Progression, dealerships, larger world, social

- Gated on: economy + authority review + district stability. Design doc per feature; no silent contract changes.
