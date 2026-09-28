# NIGHTSHIFT — test strategy (Phase 0)

`tests/` mirrors `src/`; files named `*.spec.luau`.

- No test runner is vendored yet (deliberate: no gameplay to test).
- Phase 1 will adopt a runner (TestEZ via Wally is the likely default) and add
  the first specs for the `VehicleInput` abstraction (bounds, clamping, adapter parity).
- Until then, verification is: `rokit install`, `rojo build`, `stylua --check`,
  `selene`, Luau strict typecheck in Studio, and CodeGraph index status.
- Gameplay always requires Studio/device validation (mobile + PC); static checks
  never substitute for feel.
