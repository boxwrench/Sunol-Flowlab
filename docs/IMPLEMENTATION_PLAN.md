# Implementation Plan — Phase 0 → Phase 1

Date: 2026-07-03
Prerequisite reading: `docs/ARCHITECTURE_REVIEW.md` (defines gates G0–G5 and invariants INV-1/2/3), `docs/REPOSITORY_ARCHITECTURE.md` (canonical layout).
Audience: AI coding agents (Claude Code, Codex) executing work packages; solo orchestrator reviewing.

## How to Use This Plan

- **WP-1 (before anything else): make the initial git commit.** As of 2026-07-03 the repository has zero commits — all docs, including `ARCHITECTURE_REVIEW.md` and this plan, are untracked. Agents can't follow gates from uncommitted specs, and WP feature branches need a `main` to branch from.
- Work packages (WPs) are executed **in order**. Each WP is sized for one small PR/work unit.
- Each WP lists: goal, files touched, steps, tests, and a done-when checklist. Do not start a WP until the previous WP's done-when list passes.
- **Do not create files or folders beyond those listed** (review item C2). The full tree in REPOSITORY_ARCHITECTURE §3 is a map, not a scaffold.
- Layout authority: `REPOSITORY_ARCHITECTURE.md` §3 (`scripts/simulation/...`, tests in `tests/`). On any doc conflict, REPOSITORY_ARCHITECTURE.md wins (established in WP0.1).
- All domain code: `extends RefCounted`, SI units with unit-suffixed names (`volume_m3`, `flow_m3s`), `StringName` IDs, typed GDScript throughout.

Gate map: G0→WP0.1 · G1→WP0.1 · G2→WP0.3/0.4 · G3→WP0.1/0.3 · G4→WP1.7 · G5→Phase 2 pre-work (not in this plan; spec drafted in WP1.8 if time allows).

---

# PHASE 0 — Project Foundation

**Amended exit condition (from review):** blank 3D sandbox runs; simulation clock starts/stops/steps at fixed dt with speed via the accumulator rule (dt never scaled); tick-stamped command queue exists; GUT runs headless in CI; `test_deterministic_replay` and `test_tick_order` pass against a stub plant.

## WP0.1 — Documentation Reconciliation (gates G0, G1, G3-spec)

**Goal:** One consistent documentation set before any code exists. This WP touches only `.md` files.

**Files:** `PROJECT_OUTLINE.md` §10, `TESTING_STRATEGY.md`, `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `ADDING_A_PROCESS_UNIT.md`, `SIMULATION_RULES.md`, `PROCESS_UNIT_CONTRACTS.md`, `GLOSSARY.md`, `KNOWN_LIMITATIONS.md`, `DEBUGGING_GUIDE.md`, `TAG_NAMING.md`, new `docs/DECISIONS/0002...0006` ADRs.

**Steps:**

1. Replace PROJECT_OUTLINE §10's tree with a pointer to REPOSITORY_ARCHITECTURE §3. Add to AGENTS.md: *"On any structural conflict between docs, REPOSITORY_ARCHITECTURE.md wins."*
2. Fix all references to `res://simulation/tests/test_runner.gd` (TESTING_STRATEGY, README, CONTRIBUTING) → GUT headless invocation (exact CLI verified in WP0.2). Fix ADDING_A_PROCESS_UNIT paths (`simulation/components/` → `scripts/simulation/domain/`; `plant_network.gd` → `plant_model.gd`; `scenes/modules/` → `scenes/process_units/`; fixtures path → `tests/fixtures/`).
3. Rewrite SIMULATION_RULES "Order of operations" to match REPOSITORY_ARCHITECTURE §6's 14-step tick verbatim. Add an explicit note: *actuators integrate before controllers evaluate; controller output therefore takes effect on the next tick (intended one-tick scan lag).* (Review A2.)
4. Add a **"Determinism Mechanics"** section to SIMULATION_RULES (review A3): commands are tick-stamped and applied at tick start; simulation speed scales *accumulated simulated time*, never dt — `accumulator_s += frame_delta_s × speed_multiplier`, then run whole fixed-dt ticks while `accumulator_s ≥ dt_s` (capped by `MAX_TICKS_PER_FRAME`), so at dt = 1 s, 1× ≈ 1 tick per real second and 60× ≈ 60 ticks per real second; unit/link iteration uses explicitly ordered arrays sorted by ID; no unseeded RNG in the domain; replay = same config + same (tick, command) sequence.
5. Add a **"Flow Resolution"** placeholder section to SIMULATION_RULES stating the Phase-2 rule now so no agent invents one: two-pass request/grant over a topologically ordered DAG with proportional proration on over-committed sources (review B1); competing withdrawals from one storage (outflow, drain) prorate; spill is passive, computed after integration, never competing (review B3). Include two hard boundaries: (a) **single-mutator rule** — the FlowSolver calculates requests, applies capacities, and produces granted flows, but never modifies stored volume; `storage_balance.gd` consumes granted flows, performs the *only* volume mutation, and returns actual outflow/drain/spill; (b) **DAG constraint** — *for Phases 1–5 the hydraulic topology must be a directed acyclic graph; recirculation loops (backwash recovery, filter-to-waste returns, sludge return, recycle streams) are out of scope until a cyclic-network resolution strategy is specified.*
6. Naming table (review C1) in TAG_NAMING.md or PROCESS_UNIT_CONTRACTS: canonical class names `StorageUnit`, `JunctionUnit`, `FlowLink`, `FlowPort`, `SimValve`, `SimController`, `SimAlarm`, `SimInstrument`, `ProcessUnit`. Update PROCESS_UNIT_CONTRACTS/GLOSSARY/ADDING_A_PROCESS_UNIT from `StorageNode`/`JunctionNode`. Rule: no `class_name` with a generic or Godot-colliding identifier; `*Node` suffix reserved for actual Godot Nodes.
7. AGENTS.md additions (reviews A4, B7, C2): domain classes extend `RefCounted` only, never `Node`; domain code never references autoloads and never emits signals to external objects (events are appended to the SimulationContext and flushed after invariant validation); do not create files for future phases or implement modules not required by the current phase's exit condition.
8. Fix DEBUGGING_GUIDE: remove the `_physics_process()` prescription; state that `SimulationHost` runs N fixed-dt ticks per rendered frame from its own accumulator (review A3 note). Rephrase KNOWN_LIMITATIONS entries as scope statements, not implementation states (review C4).
9. Write ADRs 0002–0006 (fixed-step simulation; SI internal units; simulation/presentation separation; command/event boundary; JSON plant configuration) — short, using the existing ADR template.

**Done when:** grep finds no reference to `test_runner.gd`, `simulation/components`, `plant_network.gd`, or `StorageNode` outside historical/ADR context; SIMULATION_RULES and REPOSITORY_ARCHITECTURE state the identical tick order; AGENTS.md contains the four new rules.

## WP0.2 — Godot Project Skeleton + CI (gate G0)

**Goal:** Runnable empty project, GUT wired, headless tests green in CI.

**Files (create only these):**

```text
project.godot
addons/gut/                      (install GUT 9.x for Godot 4)
scenes/application/main.tscn
scripts/application/app_bootstrap.gd
tests/unit/test_sanity.gd
tools/ci/run_tests.(sh|ps1)
.github/workflows/tests.yml
```

**Steps:**

1. Create Godot 4.x project; Main scene = empty `Node3D` + `app_bootstrap.gd` (prints version, nothing else yet).
2. Install GUT; verify the headless CLI locally (expected form: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`; confirm against installed GUT version — flagged assumption #2 in the review). Record the verified command in TESTING_STRATEGY, README, CONTRIBUTING (closing WP0.1 step 2).
3. `test_sanity.gd`: one assert-true test, plus one test that `load()`s every script under `scripts/` (parse check).
4. CI workflow: download Godot headless, run the test script, fail on nonzero exit. Add a grep step enforcing G3: `extends Node` is forbidden under `scripts/simulation/` (review A4).
5. Project settings: enable GDScript warnings (treat untyped declarations as warnings at minimum).

**Done when:** CI passes on a clean clone; sanity test runs headless locally.

## WP0.3 — Core Utilities + Command/Event Base (gates G2, G3)

**Goal:** The engine's plumbing, no hydraulics yet.

**Files:**

```text
scripts/utilities/unit_conversion.gd      # constants + MGD↔m3s, ft↔m, MG↔m3
scripts/simulation/core/simulation_context.gd
scripts/simulation/commands/simulation_command.gd
scripts/simulation/events/simulation_event.gd
scripts/application/command_bus.gd        # autoload: thin forwarder only
scripts/application/event_bus.gd          # autoload: thin relay only
tests/unit/utilities/test_unit_conversion.gd
```

**Steps:**

1. `unit_conversion.gd`: static class, constants from INTERNAL_UNITS.md. Round-trip tests (MGD→m³/s→MGD within 1e-12 relative).
2. `SimulationCommand` (RefCounted): `command_id`, `issued_tick: int`, `apply_tick: int`, abstract `execute(context) -> void` and `validate(context) -> Array[String]`.
3. `SimulationEvent` (RefCounted): `event_type: StringName`, `tick: int`, `payload: Dictionary`.
4. `SimulationContext` (RefCounted): holds dt, current tick, references to unit/link registries (ordered arrays + lookup dicts), a `pending_events: Array[SimulationEvent]` the domain appends to (review B7), and the seeded `RandomNumberGenerator` (unused for now, owned here per A3).
5. Autoload buses: `CommandBus.submit(cmd)` calls `engine.enqueue(cmd)` — the queue lives **inside the engine**; `EventBus` re-emits event batches the engine hands it after each tick. Dependency direction enforced: autoload → engine only (review A4).

**Done when:** conversion tests pass; buses contain no state beyond an engine reference; nothing under `scripts/simulation/` references an autoload (grep-checked in CI).

## WP0.4 — Simulation Clock, Engine Shell, Tick Pipeline (gates G1, G2)

**Goal:** A deterministic engine that ticks a stub plant in the canonical 14-step order.

**Files:**

```text
scripts/simulation/core/simulation_clock.gd
scripts/simulation/core/simulation_engine.gd
scripts/simulation/core/mass_balance_tracker.gd   # skeleton: ledger fields + report(), no checks yet
tests/unit/simulation/test_tick_order.gd
tests/unit/simulation/test_command_queue.gd
tests/invariants/test_deterministic_replay.gd
tests/helpers/stub_unit.gd
```

**Steps:**

1. `SimulationClock` (RefCounted): fixed `dt_s := 1.0`, `tick_count: int`, `speed_multiplier` (0 = paused, single-step flag, 1×…60×), and the accumulator loop: `accumulator_s += frame_delta_s * speed_multiplier`; `while accumulator_s >= dt_s and ticks_this_frame < MAX_TICKS_PER_FRAME: run_tick(dt_s); accumulator_s -= dt_s`. Hard cap `MAX_TICKS_PER_FRAME := 240`. dt never changes; speed only changes how much simulated time accumulates per real second.
2. `SimulationEngine` (RefCounted): owns clock, context, command queue (array sorted by `apply_tick`, FIFO within a tick), subsystem call sequence exactly per REPOSITORY_ARCHITECTURE §6's `run_tick()` skeleton. Subsystems that don't exist yet are no-op calls kept in order.
3. Command handling: `enqueue(cmd)` stamps `apply_tick = current_tick + 1` (or as commanded for scenario scripts); step 1 of the tick applies all commands stamped for that tick, in enqueue order.
4. Event flush: after invariant step, engine drains `context.pending_events` and returns the batch (application layer relays to EventBus) — never mid-tick (review B7).
5. `stub_unit.gd`: records which lifecycle phase touched it and mutates a counter deterministically.
6. Tests: **tick order** — stub subsystems append their name to an array during one tick; assert the exact 14-step sequence. **Command queue** — command enqueued during tick N executes at start of N+1; two commands same tick preserve order. **Deterministic replay** — build two engines from the same stub config, feed identical (tick, command) scripts, run 10,000 ticks, compare a state hash (concatenated stub counters) for exact equality; then permute stub registration order and assert results unchanged (ordered-iteration proof, review A3).

**Done when:** all three tests pass headless; engine has zero references to Node, scenes, or autoloads.

## WP0.5 — SimulationHost, Camera, Time Controls UI

**Goal:** The blank 3D sandbox of the Phase 0 exit condition. First and only Phase-0 scene work.

**Files:**

```text
scenes/application/main.tscn                 (extend)
scripts/application/simulation_host.gd       # Node; owns engine instance, accumulator loop
scenes/cameras/orbit_camera.tscn + scripts/presentation/camera/orbit_camera.gd
scenes/ui/controls/time_controls.tscn + scripts/ui/controllers/time_controls.gd
scenes/environment/placeholder_environment.tscn   (ground plane, light, sky)
```

**Steps:**

1. `SimulationHost` (Node, application layer — allowed): instantiates `SimulationEngine` in `_ready()`; per rendered frame feeds `frame_delta_s` into the clock's accumulator and runs the owed whole ticks; exposes pause/play/step/speed by issuing engine calls. The engine itself never touches the scene tree.
2. Orbit camera: orbit/pan/zoom/reset only (bookmarks and focus-on-asset are Phase 6 per outline — do not build).
3. Time controls UI: Pause/Play/Step buttons + speed selector (1/5/10/30/60×) + tick counter label. Buttons call `CommandBus`/host methods — UI never touches the engine directly (INV-3).
4. Manual check: run at 60×, verify tick counter advances 60 ticks/s of wall time (±frame jitter) and pausing freezes it.

**Done when:** Phase 0 exit condition passes in full: sandbox runs, time starts/stops/steps at fixed dt with accumulator-based speed, command queue live, CI green including `test_deterministic_replay` and `test_tick_order`.

**⛔ Phase 0 gate check (G0–G3):** review each done-when list above before starting Phase 1.

---

# PHASE 1 — Single Storage-Unit Prototype

**Amended exit condition (from review):** the five outline §12 demonstrations pass as automated tests; mass-balance ledger (B5) holds over ≥1e5 accelerated ticks; headless run of the same scenario produces results identical to a run with the 3D scene loaded (G4).

Topology under test (all links user-controllable):

```text
EXTERNAL_SOURCE ──[inlet valve]──> BASIN_01 ──[outlet valve]──> EXTERNAL_SINK
                                     ├──[drain valve]────────> EXTERNAL_SINK (waste)
                                     └──[spill, passive]─────> EXTERNAL_SINK (spill)
```

## WP1.1 — Domain Base Classes

**Goal:** The minimal domain vocabulary, per PROCESS_UNIT_CONTRACTS (as renamed in WP0.1).

**Files:**

```text
scripts/simulation/domain/process_unit.gd     # lifecycle per §5.1 contract
scripts/simulation/domain/storage_unit.gd
scripts/simulation/domain/external_boundary.gd  # EXTERNAL_SOURCE / EXTERNAL_SINK unit
scripts/simulation/domain/flow_port.gd
scripts/simulation/domain/flow_link.gd
scripts/simulation/domain/actuator.gd          # SimValve behavior: rate-limited travel
tests/unit/simulation/test_actuator.gd
tests/unit/simulation/test_flow_link.gd
```

**Steps:**

1. `ProcessUnit` (RefCounted): `unit_id: StringName`, `display_name`, `in_service`, `operating_state`, lifecycle `initialize(config) / pre_tick / solve_tick / post_tick / get_snapshot / validate` per contract §5.1.
2. `StorageUnit`: geometry (surface area, bottom/spill/high/low levels, max volume), `volume_m3`, derived `level_m`; exposes `available_withdrawal_m3(dt)` and `available_receiving_m3(dt)`; owns ports. **No integration math here** — it delegates to `storage_balance.gd` (WP1.2) so five basins and twelve filters later share one implementation (review B3).
3. `ExternalBoundary`: infinite (or configured-rate) source/sink, typed with a **mutually exclusive ledger category** — `SOURCE_INFLOW`, `TREATED_DEMAND`, `PROCESS_WASTE`, `DRAIN`, or `SPILL`; the mass-balance ledger's external terms come only from these categories (INV-1).
4. `SimValve` (actuator): commanded vs actual position, open/close rates in %/s, `update(dt)` moves actual toward commanded, `get_effective_opening()`. Instant mode behind a debug flag, default off (fixes KNOWN_LIMITATIONS drift, review C4).
5. `FlowLink`: source port → destination port, `max_flow_m3s`, flow mode (`restricted` only in Phase 1: `flow = max_flow × opening`), computes **requested** flow; granted flow set by the solver step; records `constraint_reason`.
6. Tests: valve travel time (0→100% at 5%/s takes 20 ticks); clamping [0,1]; link request honors closed valve (=0), capacity cap, disabled state.

**Done when:** unit tests pass; every class extends RefCounted; CI grep-guards still green.

## WP1.2 — Storage Balance + Mass-Balance Ledger (INV-1 core)

**Goal:** The one function that moves water, and the ledger that proves it.

**Files:**

```text
scripts/simulation/hydraulics/storage_balance.gd
scripts/simulation/core/mass_balance_tracker.gd   (complete the WP0.4 skeleton)
tests/unit/hydraulics/test_storage_balance.gd
tests/invariants/test_mass_conservation.gd
tests/invariants/test_no_negative_storage.gd
```

**Steps:**

1. `storage_balance.gd` static integration, per WP0.1's B3 spec, exact order: (a) sum granted inflows; (b) sum requested withdrawals (outflow + drain), **prorate proportionally** if total > available volume this tick; (c) integrate `volume += (in − out − drain) × dt`; (d) if `volume > spill_volume`, excess becomes `spill_m3s` this tick and volume clamps to spill volume; (e) clamp `[0, ε)` to exactly 0; below `min_operating_level`, outflow forced to 0 next-tick via `available_withdrawal`.
2. Every clamped/prorated quantity is *returned*, not discarded — the ledger consumes the same numbers the integration used (no second computation to drift from the first).
3. `MassBalanceTracker`: cumulative ledger from t=0 with **mutually exclusive categories** — `initial_storage + Σsource_inflow − Σtreated_demand − Σprocess_waste − Σdrain − Σspill − current_storage`; there is no generic `external_out` term, so drain and spill can never be double-counted; the separate fields feed the UI ledger display directly; tolerance `1e-9 × max(total_volume, 1.0) × sqrt(tick_count)` (review B5); debug assert on violation, `MassBalanceViolation` event in release; runs as tick step 13.
4. Tests: fill/drain/spill unit cases; over-withdrawal proration (outlet requests 3, drain requests 2, only 4 available → granted 2.4/1.6); **conservation invariant**: randomized-but-seeded valve command script, 1e5 ticks at dt=1, ledger within tolerance every 1000 ticks; negative-storage invariant under aggressive simultaneous outflow+drain.

**Done when:** all tests pass; `test_mass_conservation` runs ≥1e5 ticks in CI in acceptable wall time (this doubles as the performance micro-benchmark — record the wall time, closing review assumption #1).

## WP1.3 — Minimal Config Loading + Validation

**Goal:** The basin is built from JSON, not hard-coded (data-driven principle from day one).

**Files:**

```text
config/plants/phase1_single_basin/plant.json
config/plants/phase1_single_basin/topology.json
config/plants/phase1_single_basin/initial_conditions.json
scripts/configuration/config_loader.gd
scripts/configuration/plant_validator.gd
scripts/configuration/plant_factory.gd
tests/unit/configuration/test_plant_validator.gd
tests/fixtures/  (invalid-config fixtures)
```

**Steps:**

1. JSON files follow CONFIGURATION_REFERENCE.md fields; IDs per TAG_NAMING.md (`BASIN_01`, `GV_BASIN_01_IN`, `LINK_SRC_TO_BASIN_01`, …).
2. `plant_validator.gd` is **hand-rolled** (review C3 — no JSON Schema library exists in Godot): required keys, types, ranges, plus cross-checks: duplicate IDs; dangling port/actuator references; initial volume ≤ max; `spill_level_m` consistent with `maximum_volume_m3` via geometry (review B4 second check); **topology cycle detection** — hard fail, per the Phases 1–5 DAG constraint (WP0.1 step 5); and a `simulation_resolution_warning` when `max_inflow × dt > 0.2 × operating_volume` — **warning, not rejection**: a small flash-mix chamber may legitimately exchange more than 20% of its volume per tick; hard failures are reserved for physically impossible or unsupported configurations. Errors abort load with specific messages; warnings are logged and surfaced to the user.
3. `plant_factory.gd`: validated config → domain objects registered into the context's **ID-sorted ordered arrays** (determinism, A3).
4. Tests: each invalid fixture produces its specific error; valid fixture builds a plant whose snapshot matches initial conditions.

**Done when:** engine boots the basin purely from `phase1_single_basin/`; all validator tests pass.

## WP1.4 — Solver Step (Phase-1 Degenerate Case) + Alarms

**Goal:** Wire flows through the tick pipeline; alarms as domain logic.

**Files:**

```text
scripts/simulation/hydraulics/flow_solver.gd     # Phase-1: single-source trivial case of the B1 two-pass design
scripts/simulation/alarms/alarm_engine.gd
scripts/simulation/alarms/threshold_alarm.gd
tests/unit/alarms/test_threshold_alarm.gd
tests/unit/simulation/test_tick_integration.gd
```

**Steps:**

1. `flow_solver.gd`: implements the two-pass request/grant structure from the WP0.1 Flow Resolution spec, even though Phase 1 has no competition — pass 1 collects link requests, pass 2 grants against source availability. The solver produces granted flows only — it **never mutates stored volume**; `storage_balance.gd` (WP1.2) is the single place volume changes (single-mutator rule from WP0.1 step 5). Building the *shape* now means Phase 2 fills in proration and topological ordering without restructuring (G5 ramp).
2. `ThresholdAlarm`: high/low level with activation delay and deadband per Alarm contract; evaluated by `alarm_engine.gd` at tick step 11; state changes append `AlarmActivated`/`AlarmCleared` events to the context (B7 — no signals).
3. `test_tick_integration`: full engine + basin config; assert the canonical step interaction — a valve command issued at tick N changes actual flow no earlier than N+1 (A2 latency documented behavior).

**Done when:** alarm delay/deadband tests pass; integration test confirms command→effect latency exactly as documented.

## WP1.5 — Snapshot Service (INV-3 boundary)

**Goal:** The read-only window presentation will use.

**Files:**

```text
scripts/application/snapshot_service.gd
tests/unit/simulation/test_snapshot.gd
```

**Steps:**

1. Pull model (review B6): presentation asks once per rendered frame; service builds from the latest completed tick, `duplicate(true)` deep copy; format per REPOSITORY_ARCHITECTURE §13 (`units`, `actuators`, `alarms`, `plant_totals` incl. ledger summary).
2. Debug-mode mutation guard: hash the published snapshot, re-hash next frame before replacement, assert unchanged (catches UI writes, INV-3).
3. Telemetry is **not** built in Phase 1 (C2) — the ledger lives in the tracker, trends come later.

**Done when:** snapshot reflects known state after scripted ticks; mutation guard test passes.

## WP1.6 — Presentation + UI Slice

**Goal:** The visible basin: moving water, valve handles, level readout, alarm light. First INV-3 proof in pixels.

**Files:**

```text
scenes/process_units/basins/generic_basin.tscn
scripts/presentation/adapters/storage_visual_adapter.gd
scripts/presentation/adapters/water_surface_adapter.gd
scripts/presentation/adapters/valve_visual_adapter.gd
scenes/ui/asset_panel/asset_panel.tscn + scripts/ui/controllers/asset_panel.gd
scripts/ui/formatters/display_units.gd     # SI → MGD/ft/MG via unit_conversion
```

**Steps:**

1. `generic_basin.tscn` from Godot primitives per §9.2 pattern (StaticGeometry, WaterSurface plane, valve visuals, AlarmIndicator, SelectionCollider, LabelAnchor, VisualAdapter). `@export var unit_id: StringName` binds it to config — placeholder box now, Blender later, zero sim impact (§20.3).
2. Adapters read the per-frame snapshot only; water plane Y from `level_m`; valve handle rotation from actual position; alarm light from alarm state. **No arithmetic beyond visual mapping** (§9.3).
3. Asset panel: click-select basin → shows name/state/level/volume/in-out flows/valve positions in display units (formatters convert; simulation stays SI — INV boundary per INTERNAL_UNITS.md). Valve sliders and drain button issue `SetValvePositionCommand` etc. via CommandBus.
4. Manual check at 1× and 60×: level visibly rises/falls consistent with panel numbers.

**Done when:** every §9.3 "may not" rule holds (verified by reading the three adapter scripts — they contain no volume/flow math); commands are the only write path from UI.

## WP1.7 — Phase 1 Verification Suite (gate G4)

**Goal:** The outline's five required demonstrations + review-amended checks, all automated.

**Files:**

```text
tests/integration/single_basin/test_demonstrations.gd
tests/invariants/test_headless_parity.gd
```

**Steps:**

1. Demonstration tests (outline §12 Phase 1), each from the JSON initial state via commands only: (a) inflow > outflow ⇒ level rises; (b) outflow > inflow ⇒ level falls; (c) outlet closed with inflow sustained ⇒ level reaches spill elevation ⇒ spill flow starts, high-level alarm active; (d) drain opened, inflow stopped ⇒ basin empties to exactly 0, no negative volume; (e) displayed volume consistent with flow balance ⇒ ledger check every tick of every demonstration.
2. `test_headless_parity` (G4): run demonstration (c) headless via engine directly; run it again with `main.tscn` loaded and `SimulationHost` driving the same command script; compare final state hashes for exact equality. Proves rendering does not perturb simulation (INV-2 + INV-3 in one test).
3. Extended soak: demonstration script loop for 1e5 ticks at max speed; assert no NaN/inf, ledger in tolerance, wall time recorded.

**Done when:** Phase 1 amended exit condition fully green in CI.

## WP1.8 (optional, time-permitting) — Draft the Phase 2 Flow-Resolution Spec (gate G5 prep)

Turn the WP0.1 step-5 placeholder into the full SIMULATION_RULES "Flow Resolution" section with worked examples (two links on one source, prorated; junction-as-small-storage per review B2), plus the PLANT_TOPOLOGY/PROCESS_UNIT_CONTRACTS updates making the inlet manifold and distribution box small StorageUnits. No code. This is the G5 gate artifact; Phase 2 must not start without it.

---

# Sequencing Summary

| # | WP | Layer | Gate | Depends on |
|---|----|-------|------|------------|
| 1 | 0.1 Doc reconciliation | docs | G0, G1 | — |
| 2 | 0.2 Skeleton + CI | infra | G0 | 0.1 |
| 3 | 0.3 Utilities + command/event base | sim core | G2, G3 | 0.2 |
| 4 | 0.4 Clock + engine + determinism tests | sim core | G1, G2 | 0.3 |
| 5 | 0.5 Host + camera + time UI | app/presentation | — | 0.4 |
| — | **Phase 0 gate check** | | G0–G3 | 0.1–0.5 |
| 6 | 1.1 Domain base classes | domain | — | 0.4 |
| 7 | 1.2 Storage balance + ledger | hydraulics | — | 1.1 |
| 8 | 1.3 Config load + validation | configuration | — | 1.1 |
| 9 | 1.4 Solver step + alarms | hydraulics/alarms | — | 1.2, 1.3 |
| 10 | 1.5 Snapshot service | application | — | 1.4 |
| 11 | 1.6 Presentation + UI slice | presentation/ui | — | 1.5 |
| 12 | 1.7 Verification suite | tests | G4 | 1.6 |
| 13 | 1.8 Flow-resolution spec (optional) | docs | G5 prep | 1.2 |

Each WP = one branch (`feature/wp0-4-simulation-engine` style) = one PR following CONTRIBUTING.md and the §22 PR checklist (state layer touched, tests added, mass-balance result for hydraulic changes).

# Standing Rules for Agents Executing This Plan

1. Read `AGENTS.md` and `ARCHITECTURE_REVIEW.md` before any WP.
2. Never modify tick order, iteration order, or dt to fix a bug — file the bug against the responsible WP instead (INV-2).
3. Any water that moves must appear in the ledger terms (INV-1). If you clamp it, report it.
4. If a needed rule is missing from the docs, add it to the correct doc in the same PR — do not improvise silently.
5. Create nothing outside the current WP's file list.
