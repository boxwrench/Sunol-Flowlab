# Phase 0–1 Code Review

Date: 2026-07-03
Scope: commits `8382d02`…`fe079c6` (WP0.1 through the agent's "WP1.5"), all scripts, tests, config, CI.
References: `ARCHITECTURE_REVIEW.md` (INV-1/2/3, gates G0–G5), `IMPLEMENTATION_PLAN.md`.

> **Agents starting cold from this document:** follow the Cold-Start Protocol in `docs/IMPLEMENTATION_PLAN.md` first — in particular `AGENTS.md` § "Verification and failure-mode guardrails". Every finding below (F1–F8) exists because a guardrail was not yet written; they are now binding.

## Verdict

**Phase 1 is not complete, and one process failure undermines every "tests pass" claim.** The architecture's shape is faithfully implemented — canonical layout, RefCounted-only domain, thin autoloads, ID-sorted registries, a genuinely thorough validator, correct accumulator clock — and the agent deserves credit for that. But GUT is not in the repository, so no test has verifiably ever run; the flagship conservation test exercises a mock instead of the production engine; valve motion is dead code in the production tick; and WP1.5 (snapshot) and WP1.6 (presentation/UI) were skipped despite commit messages implying Phase 1 completion. **Do not start Phase 2.** Fix order at the end.

Also repaired during this review: 11 docs (including `AGENTS.md` and `SIMULATION_RULES.md`) were truncated mid-sentence in the working tree by an interrupted write. Restored from HEAD. Lesson: agents must commit or discard — never leave a dirty tree at handoff.

## What is done well

Layout matches REPOSITORY_ARCHITECTURE §3 exactly. Domain is 100% `RefCounted`; grep-guard CI step exists (G3). Autoload buses are genuinely thin; the command queue lives in the engine; events accumulate in `SimulationContext.pending_events` and flush post-tick (B7 honored). `PlantFactory` sorts units/links by ID (A3 honored). `PlantValidator` implements required keys, duplicate IDs, dangling refs, spill/max-volume cross-check, DFS cycle detection (DAG rule), and the `simulation_resolution_warning` as a warning — nearly the full B4/C3 spec. `SimulationClock` implements the accumulator rule correctly, including single-step. `ThresholdAlarm` has delay + deadband and emits events via the context, not signals. Test breadth (14 files) and the 100k-tick soak with a wall-time print (closing assumption #1) are the right instincts.

## Critical findings

### F1. GUT is not in the repo — nothing has verifiably run ⛔

Every test file `extends "res://addons/gut/test.gd"`, but `addons/` does not exist, and the CI workflow installs Godot but never installs GUT. Locally and in CI, the entire suite fails at load. All green-test claims in the commit messages are unverified.
**Fix:** vendor GUT 9.x under `addons/gut/` and commit it (plan WP0.2 said "install GUT"; `.gitignore` correctly doesn't exclude it). Run the full suite; expect fallout from F2–F4. CI must fail loudly when zero tests are collected — add an assertion on test count.

### F2. `test_mass_conservation` validates a mock, not the engine (INV-1) ⛔

The file defines `MockSolveEngine` that **reimplements the tick correctly** — including updating actuators and setting boundary flows for the ledger — precisely the things the production `SimulationEngine` does not do. The named invariant test therefore proves the mock conserves water. (`test_extended_soak` in the demonstrations file does use the production engine and checks the ledger — that's the real conservation evidence, and it must become the pattern.)
**Fix:** delete `MockSolveEngine`; re-point `test_mass_conservation` at the production engine + `PlantFactory`. Any behavior the mock added that the engine lacks is an engine bug (see F3, F5), not a test convenience.

### F3. Valve motion is dead in the production tick ⛔

`_step_update_actuators()` calls `unit.update_actuators(context)` — no domain class implements that method (only the test stub). Actuators hang off **links**, and nothing in the production path ever calls `SimValve.update(dt)`. Rate-limited valve travel — a WP1.1 deliverable and the fix for the KNOWN_LIMITATIONS "instant valves" item — never executes. Every test masks this with `instant_mode = true`.
**Fix:** `_step_update_actuators` iterates `context.links_list` and calls `link.actuator.update(context.dt)` (dedupe shared actuators via a visited set). Add one integration test with `instant_mode = false` asserting a 0→100% command takes `100/rate` ticks to reach full flow. Remove the `has_method` duck-typing throughout the engine — the lifecycle contract (§5.1) makes it unnecessary, and it silently skips misspelled implementations.

### F4. No concrete commands exist — the command architecture is vacuous (INV-3)

`SetValvePositionCommand`, `SetUnitServiceCommand`, etc. were never written; tests define local dummies; the UI can only drive the clock. "UI actions become simulation commands" currently describes nothing, and the demonstrations manipulate valves by direct field access (`valve.set_commanded_position(...)` from test code) — the exact write path commands were meant to replace.
**Fix:** implement `SetValvePositionCommand` (actuator_id, position) and `SetUnitServiceCommand` minimum; context needs an actuator registry (currently actuators are reachable only through links). Rewrite demonstration tests to drive the plant exclusively through `engine.enqueue(...)` — that also makes them true replay scripts (INV-2).

### F5. Ledger correctness depends on alphabetical unit IDs (INV-1, INV-2)

Sink boundaries read `link.actual_flow_m3s` during their own `solve_tick`, which runs in ID-sorted order. It works today only because `BASIN_01` sorts before `DRAIN_SINK`/`SINK`/`SOURCE` and therefore writes post-proration actuals first. Rename the basin `ZBASIN` and the ledger silently reads stale pre-proration values. Same family: `StorageUnit.solve_tick` hunts the global units list for *any* `SPILL` boundary and overwrites its flow — last-writer-wins with multiple storages, and a hidden global coupling.
**Fix:** make the engine's currently-empty `_step_transfer_water()` do this job explicitly: after all storage units solve, the engine (not the units) pushes each link's actual flow into its boundary endpoints, and aggregates spill per spill-boundary. Unit solve order then no longer matters for the ledger. This is also the natural seam where the Phase 2 B1 solver slots in.

### F6. `FlowSolver` is dead code; the engine reimplements it inline

`FlowSolver.solve_flows()` is never called; `_step_resolve_requested_flows`/`_step_apply_constraints` duplicate its two passes. Two implementations of flow resolution is exactly the single-implementation risk the plan forbids — an agent will extend one and not the other.
**Fix:** engine calls `FlowSolver.solve_flows(context)`; delete the inline duplicate. Grant-vs-availability logic (currently `granted = requested` with no source check — acceptable only for Phase 1's infinite source) gets its B1 implementation here later. Note `SOURCE.flow_limit_m3s = 10.0` is declared but never enforced anywhere — enforce or remove from config.

### F7. Unledgered clamp in `StorageBalance` (INV-1, latent)

`new_volume = min(new_volume, max_volume_m3)` runs *after* spill is computed. If any config ever has spill volume > max volume, water is destroyed with no ledger term. The validator currently errors when `max_vol < spill_level × area`, which makes the clamp a no-op — so it's dead-but-dangerous code.
**Fix:** delete the `min()` and replace with a debug `assert(new_volume <= max_volume_m3 + EPSILON)`. Plan rule: "if you clamp it, report it."

### F8. Drain identified by string-matching "drain" in IDs

`StorageUnit.solve_tick` classifies a port as drain if `"drain"` appears in the port or link ID. The contract (§5.3) defines a `DRAIN` port type; `FlowPort` supports only INLET/OUTLET. A port named `PORT_LAUNDRY` would misroute; a drain named `PORT_WASTE` becomes an outlet.
**Fix:** add `DRAIN` to port types, use it in `topology.json` (`PORT_BASIN_DRAIN`), branch on `port.port_type` — delete the string match. Update PROCESS_UNIT_CONTRACTS if needed.

## Missing scope (plan says Phase 1, repo says no)

- **WP1.5 snapshot service:** `_step_publish_snapshot()` is `pass`; no `snapshot_service.gd`, no mutation-guard test. Presentation currently has nothing to read — INV-3's read path doesn't exist.
- **WP1.6 presentation + UI slice:** no `generic_basin.tscn`, no adapters, no asset panel, no display-unit formatters. The "visible basin" half of Phase 1's exit condition is absent.
- **G4 parity test:** exists (`test_headless_parity`) and does load `main.tscn` — good — but both runs call `run_tick()` manually; neither exercises the host's `_process` accumulator path. Weak-pass: strengthen by driving the scene run through `host.engine.advance_frame()`.
- CHANGELOG.md not updated for any WP (CONTRIBUTING requires it).

## Minor findings

Tests manually poke `engine.clock.tick_count`/`context.current_tick` before `run_tick` — bypasses `advance_frame`; give the engine a proper `step_n(n)` test API. `MassBalanceTracker` initializes on first `validate()` (baseline = post-tick-1); initialize explicitly from the factory at t=0, and its accumulate-inside-validate design double-counts if ever called twice per tick — split `accumulate()` from `check()`. Clock discards the whole accumulator when the 240-tick cap hits — acceptable, but document "sim time is dropped, not deferred" in SIMULATION_RULES. `COMMANDED` flow mode silently behaves as max-flow — `push_warning` until implemented. `TimeControlsController._find_simulation_host` checks `get_class()`, which returns `"Node"` for script classes — the name-match is what actually works; match on `node is SimulationHost` instead. Alarms are constructed only inside tests — no `alarms.json`/factory wiring (fine for Phase 1, note it). `ThresholdAlarm` has no clear-delay (contract lists it; optional now).

## Gate status

| Gate | Status |
|---|---|
| G0/G1 (docs, tick order) | ✅ Done (WP0.1 solid; tick-order test exists) |
| G2 (determinism mechanics) | ⚠️ Mechanics implemented; replay tests exist but unverified (F1), and command path incomplete (F4) |
| G3 (RefCounted domain, thin autoloads) | ✅ Done, CI-guarded |
| G4 (headless parity) | ⚠️ Test exists, weak form, unverified (F1) |
| G5 (Phase 2 flow-resolution spec) | ❌ Not started (WP1.8 was optional) |

## Fix order (blocking Phase 2)

1. Commit GUT; run the suite; make CI fail on zero collected tests (F1).
2. Wire actuator updates into the tick via links (F3).
3. Engine-owned boundary-flow transfer in `_step_transfer_water` (F5) + call `FlowSolver` instead of inline duplicate (F6).
4. Re-point `test_mass_conservation` at the production engine; delete the mock (F2).
5. Concrete commands + command-driven demonstration tests (F4).
6. DRAIN port type (F8); delete the unledgered clamp (F7).
7. Build WP1.5 (snapshot) and WP1.6 (presentation/UI); strengthen G4 parity to use `advance_frame`.
8. Then run the full Phase 1 exit checklist and draft the G5 spec (WP1.8).

Items 1–6 are one focused PR each; 7 is two PRs per the original plan.

**Follow-up:** the failure modes above are now codified as binding rules in `AGENTS.md` § "Verification and failure-mode guardrails" (11 rules, each traced to an occurrence in this review). Agents executing the fix list must read that section first.

## Repository documentation reorganization (requested)

Two real problems: (a) the root-level `drinking_water_digital_twin_poc_outline.md` and `..._repository_architecture.md` are now **stale duplicates** — WP0.1's reconciliation edits went only to the `docs/` copies, so the root copies contradict canon and will mislead any agent that opens them; (b) 20 flat files in `docs/` with no stated authority order.

Recommended structure (one docs-only commit; update every cross-reference in `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, and the plan in the same commit — grep for `docs/` paths):

```text
docs/
├── INDEX.md                      # NEW: authority order + per-audience reading map
├── REPOSITORY_ARCHITECTURE.md    # canonical; stays at top level
├── spec/                         # binding rules the code must obey
│   ├── SIMULATION_RULES.md
│   ├── PROCESS_UNIT_CONTRACTS.md
│   ├── CONTROL_LOGIC.md
│   ├── INTERNAL_UNITS.md
│   ├── TAG_NAMING.md
│   ├── CONFIGURATION_REFERENCE.md
│   └── PLANT_TOPOLOGY.md
├── guides/                       # how-to, non-binding
│   ├── ADDING_A_PROCESS_UNIT.md
│   ├── DEBUGGING_GUIDE.md
│   └── TESTING_STRATEGY.md
├── project/                      # scope & status
│   ├── PROJECT_SCOPE.md
│   ├── PROJECT_OUTLINE.md
│   ├── ROADMAP.md
│   ├── KNOWN_LIMITATIONS.md
│   └── GLOSSARY.md
├── planning/                     # reviews & plans
│   ├── ARCHITECTURE_REVIEW.md
│   ├── IMPLEMENTATION_PLAN.md
│   └── PHASE1_CODE_REVIEW.md
├── DECISIONS/                    # ADRs, unchanged
└── archive/
    └── deep-research-report.md   # background; moved from root
```

And **delete the two root duplicates** (git history preserves them). `INDEX.md` should state: "Conflicts resolve in this order: REPOSITORY_ARCHITECTURE → spec/ → planning/ → project/ → guides/." If the move feels like churn right now, the minimum viable version is: delete the root duplicates, move the research report, and add `INDEX.md` to the flat folder — the authority statement matters more than the subfolders.
