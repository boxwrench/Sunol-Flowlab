# Project Roadmap

This roadmap is the authoritative status and sequencing map. Historical work packages
remain in phase implementation plans. New work uses the numbers defined here without
renumbering history. A WP is complete only after evidence is recorded, pushed to `main`,
and CI is green.

## Status at a glance

| Phase | Scope | Status |
|-------|-------|--------|
| Phase 0 — Foundation | Clock, engine shell, tick pipeline, CI, base classes | ✅ Delivered |
| Phase 1 — Single Storage Unit | Mass balance, configuration, snapshots, verification | ✅ Delivered |
| Phase 2 — Three-Unit Sandbox | Connected flow and closed-loop level control | ✅ Delivered |
| Phase 3 — Headworks + Sedimentation | Reservoirs through applied channel, availability, presentation | 🟨 Implemented; exit gate open |
| WP4.0 — Self-Regulating Hydraulics | `GRAVITY` mode and deterministic port iteration | ✅ Delivered |
| WP4.1 — Headworks Gravity Migration | Convert and re-baseline `phase3_headworks` | 🟨 Implemented; closure verification remains |
| WP4.2–WP4.7 — Audit Closure | Contracts, unsupported modes, startup, alarms, CI, verification | ⬜ Next |
| Phase 4a — Filtration + Clearwell | Twelve filters, clearwell, distribution and minimum control | ⛔ Blocked by WP4.7 |
| Phase 4b — Contact + Treated Water | CT basins, treated storage/demand, one supervisory loop | ⬜ Planned |

## Governing sequence

Build only what makes the next plant section visibly operable and hydraulically correct.
A future capability enters active architecture only when the next playable milestone
requires it or a concrete failing case proves the current solution insufficient.

1. Complete WP4.2 through WP4.7 in order.
2. Close the Phase 3 and WP4.1 gate with recorded evidence.
3. Author the detailed Phase 4a implementation plan.
4. Build filters and clearwell only.

Do not begin another broad subsystem while the audit-closure gate is open.

## Audit-closure work plan

### WP4.2 — Align active documentation with executable reality

**Goal:** Reduce specification drift without changing runtime behavior.

**Scope:**

- Correct README Godot version, main scene, process train, and run steps.
- Resolve authority contradictions in `docs/INDEX.md` and active guides.
- Reduce `docs/REPOSITORY_ARCHITECTURE.md` to current directories, dependency
  boundaries, tick/snapshot boundaries, and invariants. Move future rationale to an
  explicitly non-binding appendix or existing archive.
- Reconcile `docs/PROCESS_UNIT_CONTRACTS.md` with production symbols and schemas.
- Correct stale references and label archived research historical and non-binding.

**Done when:** active documented paths exist; config fields exist in schemas; public
methods match production; future material is non-binding; README steps work from a clean
Godot 4.7 import; documentation links validate.

### WP4.3 — Remove unsupported `COMMANDED` flow mode

**Goal:** Reject a configuration mode that is accepted but not implemented.

**Scope:** remove `COMMANDED` from schema, validator, `FlowLink` fallback, active
rules/contracts, fixtures, and tests. Do not implement it.

**Done when:** no supported path remains; invalid configuration fails clearly; schema,
solver, integration, replay, and mass-balance suites pass; `RESTRICTED` and `GRAVITY`
results are unchanged.

### WP4.4 — Remove inaccessible reverse-flow support

**Goal:** Keep the directed-acyclic hydraulic contract honest.

**Scope:** after a repository-wide reference search, remove `reverse_flow_allowed` and
the negative-head gravity branch from production and current contracts. Negative head
produces zero forward flow. Do not add bidirectional topology semantics.

**Done when:** no production/config contract claims reverse flow; positive, zero, and
negative head tests pass; replay and mass conservation pass; topology remains a DAG.

### WP4.5 — Unify startup state and wire configured alarms

**Goal:** Make the default visual plant start from configuration and expose required alarms.

**Scope:**

- Put demonstration valve positions in
  `config/plants/phase3_headworks/initial_conditions.json`; remove scene-local commands.
- Register loaded alarms through a direct bootstrap loop using existing `ThresholdAlarm`
  and `AlarmEngine`; add no service/registry layer.
- Replace duplicate map JSON loading with `PresentationMapHandler.load_map()`.

**Done when:** first headless/visual snapshots match configuration; both alarm IDs appear;
activation, delay, deadband, clearing, and single-event behavior are tested; the scene
presents alarms; parity and the five-basin outage demonstration pass.

### WP4.6 — Derive the CI test-script count

**Goal:** Preserve defensive GUT validation without a manually maintained total.

**Scope:** derive expected scripts from the runner's `tests/**/test_*.gd` convention.
Retain skipped-test, zero-test, script-error, and loaded-versus-expected checks.

**Done when:** CI prints derived and loaded counts; temporary valid and unparseable scripts
prove count/failure behavior; temporary files are removed; normal CI is green.

### WP4.7 — Close the Phase 3 and WP4.1 gate

**Goal:** Independently prove the shipped headworks/gravity milestone complete.

**Scope:** run full GUT and config suites; reverify replay, mass balance, no negative
storage, 100k-tick soak/churn, headless/visual parity, five-basin outage, configured
startup, and alarms in the actual main scene. Record exact totals.

**Done when:** nonzero tests are collected with zero failures; manual checks are recorded;
CI on `main` is green; Phase 3 and WP4.1 are marked delivered; worktree is clean. If
execution is unavailable, report exactly “Tests written but NOT executed — unverified”
and leave the gate open.

## Phase 4a — Filters and clearwell

Author its detailed plan only after WP4.7. Scope is limited to twelve reusable filters,
existing-solver flow distribution, clearwell storage, minimum operability control,
service state, snapshot-driven visuals, and invariant/integration tests. Do not build a
filter inheritance framework without two concrete behaviors. Backwash and
filter-to-waste are excluded.

## Phase 4b — Contact basins and treated water

After Phase 4a is playable and verified, add two CT basins, treated-water storage/demand,
and one specified supervisory/cascade loop. Close full-train mass balance and availability
demonstrations here.

## Triggered later

| Capability | Revisit trigger |
|------------|-----------------|
| Minimal trend buffer | A current problem cannot be diagnosed from snapshots/tests, or trends become a release criterion |
| Enhanced presentation channels | A current playable milestone needs the channel and its snapshot source, monotone mapping, zero behavior, and validation are specified |
| Interlocks/permissives | A real transition needs a precondition service state/link enablement cannot express |
| Cyclic topology | A committed process path requires a recycle stream |
| Backwash/filter-to-waste | A filter milestone requires it and cyclic topology is specified |
| Pump curves/HGL | A named case defeats current modes and design data exists |
| Chemistry/dosing | A training objective has a measurable result and defensible model/data |
| Historian/export | A real run must be saved, exchanged, compared, or replayed |
| External API/MQTT | A real consumer and versioned message contract exist |
| Reverse flow | A real link needs bidirectional operation and DAG/ledger semantics are specified |
| `COMMANDED` flow | A controller needs direct requests with specified config/integration contracts |

Keep scenario frameworks, other-utility portability, cyber-physical scenarios, detailed
settling, media optimization, and nonessential asset polish parked.

## Protected foundations

- Deterministic fixed-step simulation and explicit 14-step tick.
- Two-pass DAG solver with one grant/proration authority.
- `StorageBalance` as the single volume-mutating authority.
- Mass ledger, invariant assertions, and no-negative-storage guarantee.
- Typed outlet/drain semantics; schemas plus semantic validation.
- Headless/presentation separation and command/snapshot boundaries.
- Monotone, same-tick presentation mappings defined in `PRESENTATION_MAPPING.md`.
- Sorted registries and defensive GUT/CI checks.

## Out of scope for the proof of concept

CFD, pressure networks, detailed pump curves/HGL, detailed chemistry, regulatory CT,
settling-performance models, live SCADA, multiplayer, scoring, scenario platforms,
historian infrastructure, external messaging APIs, and other-utility portability.
