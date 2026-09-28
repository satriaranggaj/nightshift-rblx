# NIGHTSHIFT — test strategy

`tests/` mirrors `src/`; files named `*.spec.luau` (TestEZ, via Wally).

- Install: `rokit install` (tools) then `wally install` (Packages/, gitignored).
- Run in Studio: press Play — `tests/SpecRunner.server.luau` discovers every
  `*.spec` ModuleScript under TestService/Tests and reports via TextReporter.
- Headless CI (when Studio auth allows): build the place and
  `run-in-roblox --place build/NIGHTSHIFT.rbxlx --script tests/SpecRunner.server.luau`.
- Specs stay non-strict by exception (TestEZ injects describe/it/expect);
  selene covers those globals via the `roblox+testez` std layer (testez.yml).
- Gameplay always requires Studio/device validation (mobile + PC); static checks
  never substitute for feel.
