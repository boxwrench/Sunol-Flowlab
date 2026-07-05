# Sunol FlowLab — Briefing for an Outside Review

Context for an independent reviewer. Form your own judgment; the framing below is descriptive, not
a conclusion. Committed code is authoritative — verify claims against it (read via `git show
HEAD:<path>`; the working tree may be served through a stale mount).

## Overall idea

Sunol FlowLab is a **deterministic drinking-water treatment plant simulator** written in Godot
4.x / GDScript. It models a plant as a directed acyclic graph (DAG) of storage nodes connected by
flow links: raw-water reservoirs → inlet manifold → flash mix → distribution box → five
flocculation/sedimentation basins → applied channel → (later) filters, clearwell, CT basins,
treated-water reservoir. The goal is a *watchable, operable* plant: you can run it at real time or
sped up, take basins in and out of service, drive valves and level controllers, and observe
conservation-correct behavior. Determinism (seeded, bit-exact replayable) and mass conservation
are treated as first-class invariants. The simulation domain is deliberately decoupled from UI:
all domain classes are plain `RefCounted` with no scene, signal, or engine dependencies.

## Methods

**Simulation design.**
- Every wet node is a `StorageUnit`; the outside world is an `ExternalBoundary` tagged with a
  mass-balance ledger category (`SOURCE_INFLOW`, `TREATED_DEMAND`, `PROCESS_WASTE`, `DRAIN`,
  `SPILL`).
- Connectivity is `FlowPort` (one link per port) + `FlowLink` (`max_flow_m3s`, optional actuator,
  `RESTRICTED` flow mode). Flow splitting is handled entirely by a **two-pass DAG solver with
  proration** — no separate splitter logic.
- Fixed timestep; tick-stamped commands; sorted/topological iteration; a single seeded RNG on the
  context; snapshot service for state capture and deterministic replay.
- Configuration-driven: JSON (`plant/topology/initial_conditions/controllers/alarms`) validated in
  two layers — JSON Schema (`additionalProperties:false`) in CI, then `PlantValidator` semantics
  (referential integrity, DAG acyclicity, geometry) — then assembled by `PlantFactory` in a fixed
  build order. `in_service` in initial conditions overrides the topology default.

**Development methodology (agent-driven).**
- Work is decomposed into sequential **work packages (WPs)**, one commit per WP (`WP#.#:` prefix),
  each with an explicit file scope and a "done-when" checklist.
- An **orchestrator/reviewer** gates progression: it audits *committed code and reproduced test
  output* — never implementation summaries — and issues accept/reject verdicts. Per-WP review is
  batched at milestones for Phase 3.
- Spec-first WPs (write the rule into the docs before coding it); guardrails each traceable to a
  real past failure; strict "own nothing outside your WP's file list."
- Verification via GUT test tiers (unit / integration / invariant), a config-validation CI script,
  and long soak tests (100k-tick mass-conservation, availability churn, deterministic replay).

## Plans

Phased roadmap: **Phase 0** foundation (clock, engine shell, CI) → **Phase 1** single storage unit
(mass balance, spill) → **Phase 2** three-unit sandbox (flow propagation, level control) →
**Phase 3 (current)** headworks + five sedimentation trains, in work packages WP3.0–WP3.8:
specs → reservoirs/manifold → flash mix/distribution box → basins + availability + service
commands → applied channel + level alarms → five level controllers → config-schema sync →
verification & soak suite → presentation & parity. **Later**: twelve filters, clearwell, two CT
basins, treated-water reservoir, plant flow control. **Future**: backwash/filter-to-waste,
coagulant dosing/simplified chemistry, hydraulic grade line with pump curves, PID with anti-reset
windup, scenario scripting/training, external integration (MQTT/Node-RED), historian playback.
A stated stretch direction is **porting the engine to other utilities (e.g. wastewater)** — the
solver is claimed utility-agnostic, with only boundary labels and the mass-balance ledger fields
needing change.

## Open questions / things worth an outside eye

- **Control law adequacy.** The shared `LevelController` is a velocity-form integral controller;
  five instances regulating one shared level on a non-self-regulating (fixed-demand) plant
  limit-cycle at any gain. Damping (P/D terms, default-off for backward compatibility) is being
  added. Is that the right fix, or should the loop be restructured (e.g. local per-basin level
  control)? The plan describes these controllers as "proportional" while the code is integral —
  a spec/implementation mismatch.
- **Test-execution debt.** In some environments the implementing agent cannot run Godot, so tests
  are "written but not executed." Several real defects (config/code key drift, capacity mismatch,
  the control-law oscillation) surfaced only when tests were finally run. How much risk does the
  deferred-execution model carry, and is the batch-audit cadence catching it early enough?
- **Hydraulic sizing coherence.** Design flow rates are not specified in the plan; individual WPs
  chose capacities independently, producing an inconsistency (a fixed 15 m³/s downstream demand
  behind a 12 m³/s trunk). Should there be an authoritative plant-wide design-flow spec?
- **Doc-vs-code drift.** Reference contracts are in places broader/aspirational than the code
  (e.g. port-type set, a `JunctionUnit` abstraction realized only as `StorageUnit`). Which is the
  intended source of truth, and how is drift controlled?
- **Environment/tooling fragility.** Recurring issues: stale filesystem-mount views, a
  NUL-corrupted `.git/config`, phantom uncommitted diffs. How much do these threaten reproducibility
  and reviewer trust?
- **Determinism at scale.** Bit-exact replay and conservation are asserted but the 100k-tick soak
  / churn / replay suite (WP3.7) is the real test — not yet run to completion in review.
- **Methodology cost/benefit.** Reviewer/implementer separation and cold-start re-reading add
  rigor but also cost (context re-derivation, round-trips). Is the balance right?
- **Portability claim.** The "~95% portable, three touch points" assessment for a wastewater port
  is asserted from a code scan but unproven — worth independent scrutiny.

## Where to look
`docs/INDEX.md` (authority tiers), `docs/REPOSITORY_ARCHITECTURE.md`, `docs/SIMULATION_RULES.md`,
`docs/PROCESS_UNIT_CONTRACTS.md`, `docs/CONTROL_LOGIC.md`, `docs/PHASE3_IMPLEMENTATION_PLAN.md`,
`docs/ARCHITECTURE_REVIEW.md`, the `docs/PHASE1_CODE_REVIEW.md` / `PHASE2_CODE_REVIEW.md` reviews,
`docs/BUILDING_A_PLANT_SIMULATOR.md` (build guide), and the code under `scripts/simulation/` and
`scripts/configuration/`.
