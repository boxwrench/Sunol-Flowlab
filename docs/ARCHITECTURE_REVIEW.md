# Architecture Review — Drinking Water Digital Twin POC

Date: 2026-07-03
Scope: All 16 docs in `docs/` (incl. `DECISIONS/0001-godot.md`), root duplicates, `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `THIRD_PARTY_NOTICES.md`, asset manifest, and the deep-research report (background only).
Audience: Solo orchestrator + AI coding agents (Claude Code, Codex).

## Verdict Summary

The architecture is fundamentally sound. Simulation-first separation, fixed-tick determinism, command/event/snapshot boundaries, data-driven configuration, and the single-basin-first sequencing are all correct decisions and mutually reinforcing. The problems are not in the direction — they are in **contradictions between documents** (which will cause AI agents to diverge) and **one under-specified algorithm** (the flow solver) that sits directly on top of both core invariants. Fix the doc conflicts before Phase 0 code; specify the solver before Phase 2.

Core invariants referenced throughout:

- **INV-1 Water conservation** — no unexplained creation or loss of water.
- **INV-2 Determinism** — same config + commands + timestep → identical results.
- **INV-3 One-way dependency** — presentation/UI → simulation, never the reverse.

---

## Tier A — Resolve before writing Phase 0 code

### A1. Two conflicting repository layouts

- **[Component]** Repo tree: `PROJECT_OUTLINE.md` §10 vs `REPOSITORY_ARCHITECTURE.md` §3 vs `TESTING_STRATEGY.md` vs `AGENTS.md`.
- **[Assessment]** The outline puts code under `res://simulation/` with tests in `simulation/tests/`. The repo architecture puts code under `scripts/simulation/` with tests in `tests/`. `TESTING_STRATEGY.md`, `README.md`, and `CONTRIBUTING.md` all reference `res://simulation/tests/test_runner.gd` (a custom runner) while the repo architecture ships GUT under `addons/gut/`. `ADDING_A_PROCESS_UNIT.md` references the outline layout (`simulation/components/`, `simulation/core/plant_network.gd`, `scenes/modules/`) plus classes (`plant_network.gd`) that don't exist in the repo-architecture tree. `AGENTS.md` says code "belongs under `simulation/`".
- **[Risk]** Each AI agent will pick whichever doc it read last. You will get duplicate parallel trees and orphaned tests within days. Violates the premise that agents can "identify the correct layer and folder for a requested change" (§26).
- **[Recommendation]** Declare `REPOSITORY_ARCHITECTURE.md` §3 canonical. Update `PROJECT_OUTLINE.md` §10, `TESTING_STRATEGY.md` (paths + GUT command line, e.g. `godot --headless -s addons/gut/gut_cmdln.gd` — verify exact invocation against GUT 9.x docs), and `AGENTS.md` to reference it. Add one line to `AGENTS.md`: "On any structural conflict between docs, REPOSITORY_ARCHITECTURE.md wins."
- **Action item:** Doc reconciliation pass across `PROJECT_OUTLINE.md` §10, `TESTING_STRATEGY.md`, `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, and `ADDING_A_PROCESS_UNIT.md`. Supports INV-3 (agents can't respect boundaries they can't locate).

### A2. Two conflicting tick orders

- **[Component]** `simulation/core/simulation_engine.gd` — `SIMULATION_RULES.md` "Order of operations" (5 steps, controllers first) vs `REPOSITORY_ARCHITECTURE.md` §6 (14 steps, actuators updated *before* controllers evaluate).
- **[Assessment]** These produce different results. In the §6 order, a controller's output moves the actuator on the *next* tick (one-tick control latency); in SIMULATION_RULES order it acts the same tick. Both are defensible; having both documented is not — §6 itself says "the order must be documented and tested because changing it can change simulation results."
- **[Risk]** Direct INV-2 violation vector: an agent "fixing" a lag it perceives will silently reorder the tick and change every regression baseline.
- **[Recommendation]** Pick one canonical order (recommend §6's 14-step list, with the one-tick actuator latency explicitly documented as intended behavior — it also mimics real control-loop scan lag). Rewrite SIMULATION_RULES "Order of operations" to match verbatim, and add a unit test that asserts the step sequence (e.g., systems record their invocation order into the context; test asserts the array).
- **Action item:** Reconcile SIMULATION_RULES §Order-of-operations with REPOSITORY_ARCHITECTURE §6; add `tests/unit/simulation/test_tick_order.gd`.

### A3. Determinism is asserted but not specified

- **[Component]** `simulation_clock.gd`, `command_bus.gd`, `simulation_engine.gd`.
- **[Assessment]** INV-2 needs four concrete mechanisms none of the docs pin down: (1) **Command tick-stamping** — UI commands arrive on arbitrary render frames; they must be queued and applied at the start of a specific tick, and replay means re-applying the same commands at the same tick numbers. (2) **Speed semantics** — speed multiplies the *simulated time accumulated per real second* (`accumulator += frame_delta × speed`; run whole fixed-dt ticks from the accumulator), never dt; at dt = 1 s, 60× ≈ 60 ticks per real second. (3) **Iteration order** — the engine must iterate units/links in a defined order (sorted or insertion-ordered arrays of IDs), not "whatever order a dictionary yields". Godot 4 Dictionaries do preserve insertion order, but relying on that implicitly is fragile under agent edits. (4) **Seeded RNG** — no `randf()`/`randi()` in the domain; when instrument noise arrives later, inject a seeded `RandomNumberGenerator` owned by the engine.
- **[Risk]** Without (1) and (2), `test_deterministic_replay.gd` is unwritable. Without (3), an agent refactoring a Dictionary into different construction order changes results with zero test failures elsewhere.
- **[Recommendation]** Add a short "Determinism Mechanics" section to SIMULATION_RULES covering the four points. Implement tick-stamped command queue inside the engine in Phase 0. Cap ticks-per-frame (e.g., 240) to avoid a spiral at high speed on slow frames — at your scale (~25 units, ≤60 ticks/s at 60×) cost is trivial, but see Assumptions. Note: `DEBUGGING_GUIDE.md` says "use `_physics_process()` with a fixed delta" — that couples the sim rate to the physics tick rate and fights the speed-as-ticks-per-frame model. Correct it: the `SimulationHost` runs N fixed-dt ticks per rendered frame from its own accumulator; which engine callback drives it is irrelevant to results because dt is a constant, never the callback's delta.
- **Action item:** SIMULATION_RULES addition + Phase 0 command queue + `test_deterministic_replay` (run same command script twice, hash all volumes, assert equal).

### A4. Domain object base class and autoload coupling

- **[Component]** `scripts/simulation/domain/*`, autoloads `EventBus`/`CommandBus` (§10).
- **[Assessment]** §4.1 allows "lightweight Nodes where genuinely required" in the domain. In practice nothing in the domain requires Node: Node drags in scene-tree lifecycle, manual `free()` (leak risk), and `_process` callbacks that tempt frame coupling. Separately, if the domain references the `CommandBus`/`EventBus` autoloads, the simulation depends on scene-tree singletons and can't be instantiated cleanly in headless tests.
- **[Risk]** INV-3 erosion (domain → global scene state) and INV-2 erosion (frame-coupled callbacks). This is the single most common Godot architectural leak.
- **[Recommendation]** Harden the rule: domain classes extend `RefCounted` (or `Resource` for config), **never** `Node`, no exceptions in the POC. The engine owns its own command queue and event list; the autoload buses are thin forwarders that call `engine.enqueue(cmd)` / relay published events. Dependency direction: autoload → engine, never engine → autoload. Add this to AGENTS.md prohibited actions.
- **Action item:** Amend §4.1 restriction list + AGENTS.md; enforce with a grep-based CI check (`extends Node` forbidden under `scripts/simulation/`).

---

## Tier B — Specify before Phase 2 (multi-unit networks)

### B1. The flow solver is the architecture's biggest unspecified algorithm

- **[Component]** `hydraulics/splitter_solver.gd`, tick steps 5–7 ("resolve requested flows → apply constraints → transfer water").
- **[Assessment]** Nothing defines what happens when multiple links draw from one source in the same tick (applied channel → 12 filters; clearwell → 2 CT basins), or how a zero-storage junction's outflow is resolved when it depends on same-tick upstream inflow. Sequential first-come-first-served link resolution makes results depend on link ordering (INV-2) and makes "fair" starvation impossible (filter 1 always wins).
- **[Risk]** This is where INV-1 and INV-2 actually live or die. It won't surface in Phase 1 (one basin) — it will surface in Phase 2–3 as mysterious oscillation or ordering-dependent redistribution.
- **[Recommendation]** Specify a **two-pass request/grant solve over a topologically ordered DAG**: pass 1, every link computes its requested flow (setpoint, valve restriction, capacity); pass 2, each source compares total requested withdrawal against available volume (`volume/dt` plus same-tick granted inflow for junctions) and **prorates grants proportionally** when over-committed. The solver produces granted flows only and never mutates volume; `storage_balance.gd` performs the single volume mutation (one mutator, one ledger — no double-integration path). Declare the POC topology a DAG solved upstream→downstream, and state it as explicit scope: for Phases 1–5 the topology must remain acyclic — recirculation (backwash recovery, filter-to-waste return, sludge return, recycle streams) is out of scope until a cyclic-network resolution strategy is specified. Document proration as the fairness rule in SIMULATION_RULES.
- **Action item:** New "Flow Resolution" section in SIMULATION_RULES + `splitter_solver.gd` spec + unit tests: over-committed source prorates; results identical under permuted link declaration order.

### B2. Junction vs storage contradiction (distribution box)

- **[Component]** `JunctionNode` contract (PROCESS_UNIT_CONTRACTS) vs outline §6.4.
- **[Assessment]** The junction contract has no storage, but §6.4 says excess flow "should cause the distribution-box level to rise." A zero-storage node cannot have a level, and zero-storage pass-through inside one tick creates the same-tick dependency problem in B1.
- **[Risk]** An agent implementing §6.4 will bolt storage onto JunctionNode ad hoc, breaking the mass-balance ledger (INV-1) because junction terms aren't in it.
- **[Recommendation]** Simplest consistent fix: model the inlet manifold, distribution box, and filter effluent header as **small StorageUnits** (a few minutes' volume). Every wet node is then in the storage ledger, INV-1 stays trivially checkable, and the DAG solve needs no algebraic pass-through. Reserve pure JunctionNode for true zero-volume tees, or drop it from the POC entirely.
- **[Action item]** Update PROCESS_UNIT_CONTRACTS + PLANT_TOPOLOGY: distribution box / manifold become StorageUnits; note minimum-volume sizing rule (see B4).

### B3. Storage update semantics: withdrawal priority and same-tick spill

- **[Component]** `hydraulics/storage_balance.gd`.
- **[Assessment]** SIMULATION_RULES caps outflow at available volume, but doesn't say who wins when **outflow + drain** together exceed available water, nor whether spill is computed before or after the volume integration within a tick.
- **[Risk]** Two agents will implement two different priority rules in basin vs filter code — INV-1 holds locally but scenario baselines become irreproducible (INV-2), and drain-down Scenario 7 behaves differently per unit.
- **[Recommendation]** Specify once, in SIMULATION_RULES: (1) competing withdrawals (outflow, drain) are **prorated** against available volume (consistent with B1); (2) integration order per tick: apply inflows/outflows → if volume > spill volume, excess becomes spill_flow this tick and volume clamps to spill volume → clamp `[0−ε]` to 0. Spill is passive and never competes with withdrawals.
- **Action item:** SIMULATION_RULES storage-update subsection + shared `storage_balance.gd` used by every storage unit (no per-unit reimplementation) + unit tests for the over-withdrawal case.

### B4. Small volumes + 1 s tick = stability cliff

- **[Component]** Flash mix model, any "small but visible volume" unit; `simulation_clock.gd`.
- **[Assessment]** Explicit Euler with dt = 1 s is fine when volumes are large relative to `max_flow × dt`. A flash mix at 100 MGD (~4.4 m³/s) with, say, a 30 m³ volume turns over in ~7 s; combined with proportional level control it can fill/empty/oscillate tick-to-tick. This isn't a solver bug — it's a configuration constraint nobody wrote down.
- **[Risk]** Presents as "unstable calculations" (POC failure criterion §14) and tempts agents to add adaptive timesteps — which would destroy INV-2.
- **[Recommendation]** Add a `simulation_resolution_warning` to `plant_validator.gd` when `max_inflow × dt > k × operating_volume` (k ≈ 0.2) — a **warning, not a rejection**: clamped explicit-Euler mass balance is not numerically unstable here, just coarse, and fast-turnover units (flash mix) can be legitimate. Reserve hard failures for physically impossible or unsupported configurations. Fix findings by sizing config volumes up, never by varying dt. Add a second cross-check while you're there: `CONFIGURATION_REFERENCE.md` defines spill onset twice (`maximum_volume_m3` "before spill calculations begin" *and* `spill_level_m`) — validate that `spill_level_m` × geometry equals `maximum_volume_m3`, or drop one field, so the two can't drift apart (INV-1: two spill definitions means two mass-balance behaviors). Same logic gates the future gravity-flow mode: clamp head to ≥ 0 before `sqrt` (NaN guard — INV "no NaN") and cap per-tick transfer at the head-equalizing volume to prevent flip-flop oscillation.
- **Action item:** Validation rule in `configuration/plant_validator.gd` + note in SIMULATION_RULES; NaN guard listed in `gravity_flow_model.gd` spec even though the mode is deferred.

### B5. Mass-balance tracker needs a cumulative ledger, not a per-tick check

- **[Component]** `simulation/core/mass_balance_tracker.gd`.
- **[Assessment]** §1.7 defines the per-tick equation. A per-tick epsilon (SIMULATION_RULES suggests 1e-9) can pass every tick while a systematic bias drifts unbounded over a million accelerated ticks. Also, 1e-9 m³ is too tight as an absolute tolerance for a plant holding ~1e5 m³ in double precision over long runs.
- **[Risk]** INV-1 silently violated in exactly the long accelerated runs the completion criteria (§14) require.
- **[Recommendation]** Tracker keeps a **cumulative ledger** from t=0 with **mutually exclusive typed external-flow categories** (`SOURCE_INFLOW`, `TREATED_DEMAND`, `PROCESS_WASTE`, `DRAIN`, `SPILL`): `initial_storage + Σsource_inflow − Σtreated_demand − Σprocess_waste − Σdrain − Σspill − current_storage`, with tolerance scaled as `ε_rel × plant_volume × sqrt(tick_count)`. No generic `external_out` term exists, so spill/drain can never be double-counted; the separate fields also map directly to a UI ledger display. Debug builds fail fast (assert), release builds raise the `MassBalanceViolation` event.
- **Action item:** `mass_balance_tracker.gd` spec in SIMULATION_RULES; `test_mass_conservation.gd` runs ≥ 1e5 ticks accelerated.

### B6. Snapshot immutability is by convention only, and per-tick publishing is wasteful

- **[Component]** `snapshot_service.gd`, §13.
- **[Assessment]** Godot has no frozen Dictionary; a snapshot handed to UI as a Dictionary is mutable, and a shallow copy still shares nested dictionaries. Also, publishing a full deep snapshot every tick means 60 snapshot builds per rendered frame at 60×, with the presentation layer reading only the last one.
- **[Risk]** A UI widget writing into a shared nested dict is a backdoor INV-3 violation the dependency rules can't catch.
- **[Recommendation]** Build the snapshot **on demand, once per rendered frame** (latest completed tick), as a `duplicate(true)` deep copy — presentation never holds domain references. Telemetry records per tick directly from domain state inside the engine (it's part of the tick, step 12), independent of snapshot publishing. Add a debug-mode check comparing snapshot hash before/after a UI frame to detect mutation.
- **Action item:** §13 amendment + `snapshot_service.gd` "pull, per-frame, deep-copy" spec.

### B7. Synchronous signals can re-enter the tick

- **[Component]** `events/*`, `event_bus.gd`, alarm engine.
- **[Assessment]** Godot signals are synchronous by default: emitting `AlarmActivated` mid-tick executes connected UI/presentation callables immediately, inside the simulation step — foreign code runs with the plant in a half-updated state, and can even enqueue commands that same tick.
- **[Risk]** INV-3 breach (simulation execution interleaved with UI code) and heisenbugs that vanish headless.
- **[Recommendation]** Events are **collected during the tick into a list and flushed after step 13 (invariant validation)** — i.e., step 14's snapshot publish also publishes the event batch. Domain objects never call `emit_signal` on external buses; they append event records to the `SimulationContext`. The application layer flushes them (optionally via `call_deferred`).
- **Action item:** Event-flush rule in REPOSITORY_ARCHITECTURE §12 + AGENTS.md ("domain code never emits signals to external objects").

---

## Tier C — Hygiene (fix opportunistically)

### C1. Naming drift and GDScript global class namespace

- **[Component]** Domain class names: outline says `StorageNode`/`JunctionNode`; repo architecture says `StorageUnit`/`JunctionUnit`; PROCESS_UNIT_CONTRACTS, GLOSSARY, and ADDING_A_PROCESS_UNIT use the outline names.
- **[Assessment]** Beyond the inconsistency, `class_name` in GDScript is globally scoped: generic names (`Alarm`, `Controller`, `Instrument`) pollute the global namespace and risk collisions with addons or future Godot built-ins. The `*Node` suffix also invites confusion with Godot `Node`.
- **[Risk]** Agents create duplicate/conflicting `class_name` declarations → parse errors project-wide; conceptual confusion between sim "nodes" and scene nodes erodes INV-3 discipline.
- **[Recommendation]** Canonical names: `StorageUnit`, `JunctionUnit` (repo-arch wins, per A1); prefix generic domain classes (`SimAlarm`, `SimController`, `SimInstrument`) or use `preload` constants instead of `class_name` for domain internals. Pick **one** ID key type (`StringName`) and use it everywhere — mixing String/StringName as dict keys has caused subtle lookup bugs across Godot versions.
- **Action item:** Naming table in TAG_NAMING.md or PROCESS_UNIT_CONTRACTS; update contracts to repo-arch names.

### C2. Over-scaffolding invites agent boilerplate

- **[Component]** Repo tree §3 (~40 pre-named scripts incl. `sequence_controller.gd`, `lead_lag_controller.gd`, `interlock.gd`, `permissive.gd`, `scenarios/`, `telemetry/`, `tools/config_editor/`).
- **[Assessment]** Phase 0–1 needs perhaps a dozen scripts. Pre-created empty files/folders are attractive nuisances for AI agents, which tend to "helpfully" fill them.
- **[Risk]** Unused speculative code that still must honor invariants but has no tests; review burden for a solo orchestrator.
- **[Recommendation]** Keep §3 as the *map* in the doc; create directories/files only in the phase that needs them. Add to AGENTS.md: "Do not create files for future phases; do not implement modules not required by the current phase's exit condition."
- **Action item:** AGENTS.md addition; Phase 0 creates only the Phase 0–1 subset.

### C3. JSON Schema validation doesn't exist in Godot

- **[Component]** `config/schemas/*.schema.json`, `configuration/schema_validator.gd`.
- **[Assessment]** Godot 4.x has no built-in JSON Schema validator; an agent asked to "validate against the schema" may hallucinate a library or import a heavyweight addon.
- **[Risk]** Invented dependency, or silent no-op validation → bad config reaches the engine and manifests as INV-1 violations at runtime.
- **[Recommendation]** Write a small hand-rolled validator in GDScript (required keys, types, ranges, cross-references — matching §14.2's excellent checklist), and/or run real JSON Schema validation in CI via a Python step under `tools/ci/`. Keep the `.schema.json` files as documentation + CI input.
- **Action item:** `schema_validator.gd` scope note in REPOSITORY_ARCHITECTURE §14.2; CI script stub.

### C4. Docs describe an implementation that doesn't exist yet

- **[Component]** `KNOWN_LIMITATIONS.md` ("Valves move instantly in the *current implementation*"), `TESTING_STRATEGY.md` (custom `test_runner.gd`).
- **[Assessment]** Minor drift, but agents treat these docs as ground truth about code state.
- **[Risk]** An agent may "preserve" fictional current behavior (instant valves) instead of implementing the documented target (rate-limited valves), contradicting the outline §5.1.
- **[Recommendation]** Rephrase KNOWN_LIMITATIONS entries as scope statements, not implementation states; fix TESTING_STRATEGY per A1.
- **Action item:** Doc pass alongside A1.

---

## Assumptions (unproven, flagged per your verification rule)

1. **Performance:** ~25 storage units + ~40 links at ≤60 ticks/s (60× speed, dt = 1 s) in typed GDScript is assumed trivially cheap. Almost certainly true at this scale, but unmeasured — validate with a Phase 1 micro-benchmark (headless, 1e6 ticks, wall-clock).
2. **GUT on Godot 4.x headless:** GUT 9.x supports `--headless` CLI runs; exact invocation must be verified when wiring CI.
3. **Float determinism:** IEEE-754 double determinism on a single platform (Windows) is assumed; cross-platform bit-exact replay is *not* claimed and shouldn't be tested for.
4. **Godot 4 Dictionary insertion-order stability** is documented behavior but should not be load-bearing (see A3).

---

## Phase 0 / Phase 1 Decision Framework

**Is the approach sound? Yes — conditional go.** The phase contents and exit conditions are right; the single-basin-first strategy will surface storage-math problems early. The conditions below exist because three defects (A1, A2, A3) would otherwise be *baked into* Phase 0 artifacts, and one (B1) must be specified before the first multi-unit network.

| Gate | Condition | Blocks |
|---|---|---|
| G0 | A1 doc reconciliation done (one canonical layout, one test runner) | Phase 0 start |
| G1 | A2 canonical tick order written into both docs | Phase 0 simulation-clock/engine code |
| G2 | A3 determinism mechanics (tick-stamped commands, accumulator-based speed with fixed dt, ordered iteration) specified; command queue in Phase 0 scope | Phase 0 exit |
| G3 | A4 RefCounted-only domain + engine-owned queue rule in AGENTS.md | Phase 0 exit |
| G4 | Phase 1 exit adds: headless run of the same basin scenario produces identical results with and without the 3D scene loaded | Phase 1 exit |
| G5 | B1 flow-resolution spec + B2 junction decision + B3 storage semantics written | Phase 2 start (not Phase 0/1) |

Suggested Phase 0 exit condition (amended): blank 3D sandbox runs; simulation clock starts/stops/steps at fixed dt with speed via the accumulator rule (dt never scaled); tick-stamped command queue exists; GUT runs headless in CI; `test_deterministic_replay` and `test_tick_order` pass against a stub plant.

Suggested Phase 1 exit condition (amended): outline §12 demonstrations, plus mass-balance ledger (B5) holds over ≥1e5 accelerated ticks, plus the G4 headless-parity check.

Everything in Tier B other than B1's *specification* can be implemented during Phases 1–2; Tier C is opportunistic.
