# Implementation Plan — Phase 3: Headworks & Five Sedimentation Trains

> **Amendments applied**: P3-A1 through P3-A7 per reviewer commit `446546e`.

This document defines the work-package (WP) breakdown for Phase 3 of Sunol FlowLab.
The goal of Phase 3 is to build the full headworks topology and five parallel sedimentation
trains: two source reservoirs, inlet manifold, flash mix, distribution box, five floc/sed basins,
and the applied channel. This introduces flow splitting across parallel trains and basin
availability (in-service / out-of-service toggling at runtime).

**Presentation scope (P3-A7, resolved by orchestrator 2026-07-04)**: Phase 3 **includes**
headworks visuals as its final work package, **WP3.8**, mirroring WP2.5's pattern
(presentation_map-driven visual adapters, asset panel reuse, headless/visual parity test).
WP3.0–WP3.7 remain simulation-domain and configuration only — no scene files, visual
adapter scripts, or `tscn` assets before WP3.8. Phase 3's exit is a watchable plant:
toggle a basin out of service and see flow redistribute across the remaining four.

**Gate prerequisite**: WP2.2-R reviewed (G5 gate closed ✅). Reviews of WP2.3–2.6 must
follow, one per cycle, in order. Phase 3 execution is gated on completion of all outstanding
Phase 2 reviews.

---

## 1. Architecture & Rules Map

### 1.1 How Phase 3 features map onto existing invariants and classes

| Feature | Binding constraint | Implementation |
|---|---|---|
| All wet nodes | Every junction is a `StorageUnit` (SIMULATION_RULES Example 2) | Manifold, flash mix, distribution box → small `StorageUnit` with small surface area |
| Flow splitting (5 basins) | **FlowSolver proration is the only splitter algorithm** (guardrail 5, Edge Rule 2) | Distribution box is a `StorageUnit` with 5 OUTLET ports; FlowSolver prorates them naturally |
| Basin availability | `is_enabled` on links + `in_service` flag on the basin unit, routed through the existing disabled-link path (F2.2-2 fix is a prerequisite) | Disable all links attached to an out-of-service basin; FlowSolver zeros their flows |
| Applied channel | `StorageUnit` receiving flows from all 5 basin outlets | Normal StorageUnit; level-control alarm threshold set per spec |
| Topology | Strict DAG — no recirculation or backwash in Phase 3 | Validated at plant build by `PlantValidator` cycle-detection |
| Tick order / dt | Unchanged (INV-2) | No changes to engine step sequence or dt |
| Domain / presentation | Simulation never references presentation (INV-3) | No autoloads, no Node inheritance in domain |

### 1.2 All wet nodes are `StorageUnit`s

Per SIMULATION_RULES Example 2 (Junction-as-Small-Storage): every physical junction,
manifold, and distribution box is modeled as a small `StorageUnit`. This preserves the pure
DAG and enables single-pass non-iterative solving.

**Sizing rule (`simulation_resolution_warning`)**: a junction `StorageUnit` with
`surface_area_m2 = 1.0 m²` and `maximum_volume_m3 = 10.0 m³` introduces at most
`10.0 / dt` m³/s of buffering lag — at `dt = 1.0 s` that is 10 m³ of water, which is
negligible relative to the 5-basin train volumes. Units must satisfy:

```
surface_area_m2 ≤ 1.0          (junction nodes)
maximum_volume_m3 ≤ 10.0       (junction nodes)
min_operating_level_m = 0.0    (junction nodes — no low-low cutoff)
```

New Phase 3 units using these sizing parameters:
- `MANIFOLD_01` (Inlet Manifold)
- `FLASH_MIX_01`
- `DIST_BOX_01` (Distribution Box)

### 1.3 Flow splitting is FlowSolver proration — no second implementation

The five floc/sed basins receive flow from `DIST_BOX_01` via five OUTLET ports. The
FlowSolver already prorates over-committed sources proportionally (Edge Rule 2). No new
splitter class, splitting coefficient array, or second proration pass is added. If a WP
appears to need a splitter algorithm, the WP is wrong.

Operator-specified percentage splits are approximated by adjusting the `max_flow_m3s` or
valve opening on each outlet gate to produce the desired request ratio; FlowSolver then
prorates the totals if supply is insufficient. This is RESTRICTED-mode control, not a new
algorithm.

### 1.4 Basin availability semantics

> **This subsection defines binding rules that WP3.0 will write into SIMULATION_RULES and
> PROCESS_UNIT_CONTRACTS before any code WP.**

**P3-A1 note**: `in_service: bool` already exists on `ProcessUnit` (declared and config-loaded
since Phase 1). It is currently **loaded-but-unenforced** — a standing guardrail-10 debt that
Phase 3 finally pays. WP3.3 does **not** redeclare the field; it wires enforcement through
`SetBasinServiceCommand`. WP3.0 must document this existing-field-now-enforced pattern.

A floc/sed basin is considered **available** when both:
1. Its inherited `in_service` boolean flag is `true` (from `ProcessUnit`), AND
2. All links attached to its INLET and OUTLET ports have `is_enabled = true`.

Taking a basin **out of service** means:
- Setting `unit.in_service = false` (the field inherited from `ProcessUnit` — no redeclaration).
- Setting `is_enabled = false` on every `FlowLink` connected to the basin's **INLET and OUTLET**
  ports. This causes FlowSolver (F2.2-2 fix) to zero all three flow fields (`requested`,
  `granted`, `actual`) on those links and exclude them from proration sets.
- **DRAIN links remain enabled** (P3-A2). A basin being taken out of service must still be
  drainable; disabling its DRAIN link would prevent emptying and is operationally incorrect.
- **Spill is not a link** (P3-A3). Spill is handled by per-unit `spill_destination_id`
  engine routing — there is no "spill link" to enable or disable. Spill will continue to be
  routed by `_step_calculate_levels_spills()` regardless of `in_service` state. An operator
  who wants to stop spill must drain the basin below `spill_level_m` first.
- The basin's own `solve_tick` continues to run but receives zero inflows and grants zero
  outflows (INLET/OUTLET disabled), so its volume changes only via DRAIN or passive spill.
- The basin does **not** get removed from the topological list; the DAG remains static.

**F2.2-2 fix is a prerequisite for basin availability** (G5 gate closed ✅; prerequisite met).

Taking a basin **back into service** reverses the above: re-enable its INLET and OUTLET links.
FlowSolver then begins granting flow naturally on the next tick.

### 1.5 Topology remains a DAG

No recirculation, backwash, or filter-to-waste paths are introduced in Phase 3. The
`PlantValidator` cycle-detection assert must pass at every plant load. Backwash is explicitly
out of scope until a cyclic-network spec exists (ROADMAP.md).

---

## 2. Spec-first WP (WP3.0)

Before any code WP, binding rules for Phase 3 are written into the existing spec documents.
This is the mandatory first deliverable.

---

## 3. WP Sequencing Summary

| WP | Title | Layer | Primary Files | Depends On |
|---|---|---|---|---|
| **WP3.0** | Spec: basin-availability semantics + small-storage sizing | Documentation | `SIMULATION_RULES.md`, `PROCESS_UNIT_CONTRACTS.md` | WP2.3–2.6 all reviewed |
| **WP3.1** | Source Reservoirs & Inlet Manifold config + wiring | Configuration / Data | `config/plants/phase3_headworks/` | WP3.0 |
| **WP3.2** | Flash Mix & Distribution Box config + wiring | Configuration / Data | `config/plants/phase3_headworks/` | WP3.1 |
| **WP3.3** | Five Floc/Sed Basins — config, wiring, availability | Configuration / Domain | plant config, `set_basin_service_command.gd` (wires inherited `in_service`) | WP3.2 |
| **WP3.4** | Applied Channel config + level alarm | Configuration / Domain | plant config, alarm config | WP3.3 |
| **WP3.5** | Five LevelControllers for applied-channel level regulation | Automation / Commands | `level_controller.gd` ×5 instances, `controllers.json` | WP3.4 |
| **WP3.6** | Config schema sync (all Phase 3 new fields) | Configuration / Schema | `config/schema/`, `plant_validator.gd` | WP3.4, WP3.5 |
| **WP3.7** | Phase 3 Verification & Soak Suite | Verification / Tests | `tests/integration/phase3_headworks/` | WP3.6 |
| **WP3.8** | Headworks Presentation & Parity | Presentation / UI | `scenes/plant/headworks.tscn`, `presentation_map.json`, parity test | WP3.7 |

---

## 4. Per-WP Sections

---

### WP3.0 — Spec: Basin-Availability Semantics + Small-Storage Sizing (docs-only)

**Goal**: Write all new binding rules into `SIMULATION_RULES.md` and `PROCESS_UNIT_CONTRACTS.md`
before any code is written. This is the spec-first guardrail for Phase 3.

**Files**:
- `docs/SIMULATION_RULES.md` — new subsection: **Basin Availability Semantics**
- `docs/PROCESS_UNIT_CONTRACTS.md` — update `StorageUnit` contract; new `SetBasinServiceCommand`

**Steps**:

1. Add to `SIMULATION_RULES.md` § Basin Availability Semantics (new subsection after
   Determinism and Edge Rules), stating explicitly:
   - `in_service` is **inherited from `ProcessUnit`** (exists since Phase 1; previously
     loaded-but-unenforced, guardrail-10 debt). Phase 3 wires enforcement — no redeclaration.
   - Out-of-service precondition: `is_enabled = false` on all INLET and OUTLET links.
     DRAIN links remain enabled (draining must remain possible). Spill cannot be disabled
     (it is engine-routed via `spill_destination_id`, not a link).
   - Tick behavior when out of service: INLET/OUTLET links carry zero flow; basin volume
     changes only via DRAIN or passive spill; the unit remains in the topological list.
   - Define the `simulation_resolution_warning` sizing rule for junction `StorageUnit`s:
     `surface_area_m2 ≤ 1.0 m²`, `maximum_volume_m3 ≤ 10.0 m³`, `min_operating_level_m = 0.0`.

2. Update `PROCESS_UNIT_CONTRACTS.md`:
   - In `StorageUnit` contract: note that `in_service` is **inherited from `ProcessUnit`**,
     was previously unenforced, and Phase 3 wires it. Do not re-list it as a new field.
   - Add `SetBasinServiceCommand`: toggles `in_service` flag AND sets `is_enabled` on
     INLET/OUTLET links; leaves DRAIN links enabled.
   - Confirm out-of-service does **not** remove the unit from `topological_units_list`.

3. Cross-reference INDEX.md (already links both spec documents).

**Tests**: None — docs-only WP.

**Done when**:
- `SIMULATION_RULES.md` contains the Basin Availability Semantics subsection matching §1.4
  of this plan with P3-A1/A2/A3 corrections applied.
- `PROCESS_UNIT_CONTRACTS.md` updated with `SetBasinServiceCommand` contract.
- No contradictions with existing rules in either document.
- Commit message begins `spec:`. No code, config, or test files in this commit.

---

### WP3.1 — Source Reservoirs & Inlet Manifold Config + Wiring

**Goal**: Create the Phase 3 plant configuration for the two source reservoirs and inlet
manifold. Verify that dual-reservoir flow combines correctly in the manifold and reaches the
flash mix port.

**Files**:
- `config/plants/phase3_headworks/plant.json`
- `config/plants/phase3_headworks/topology.json`
- `config/plants/phase3_headworks/initial_conditions.json`
- `tests/integration/phase3_headworks/test_reservoir_manifold.gd`

**Steps**:

1. Create `config/plants/phase3_headworks/` directory and initial config files:
   - **Topology**: Two `ExternalBoundary` source inflows → `RESERVOIR_01` (`StorageUnit`,
     full-size) and `RESERVOIR_02` (`StorageUnit`, full-size) → `MANIFOLD_01` (small
     `StorageUnit`: `surface_area_m2 = 1.0`, `maximum_volume_m3 = 10.0`,
     `min_operating_level_m = 0.0`).
   - `MANIFOLD_01` has one OUTLET port connecting to `FLASH_MIX_01` (placeholder boundary
     until WP3.2).
   - Each reservoir → manifold link is `RESTRICTED` mode with an explicit `max_flow_m3s`.
   - All `StorageUnit`s declare `spill_destination_id` resolving to a named boundary.

2. Update `config/schema/topology.schema.json` to allow `in_service` boolean field on
   `StorageUnit` entries (add with default `true` so existing configs continue to pass).

3. Create `tests/integration/phase3_headworks/test_reservoir_manifold.gd`:
   - `test_dual_reservoir_flow_combines`: open both reservoir outlet valves fully, run 100
     ticks, assert `MANIFOLD_01.inflow_m3s ≈ sum(RESERVOIR_01 outflow + RESERVOIR_02 outflow)`
     within EPSILON.
   - `test_single_reservoir_starvation`: set `RESERVOIR_01` volume to 0; assert only
     `RESERVOIR_02` contributes after one tick.
   - `test_manifold_mass_conservation_1k_ticks`: run 1000 ticks, assert ledger error ≤
     tolerance.

**Tests**:
- `test_dual_reservoir_flow_combines`
- `test_single_reservoir_starvation`
- `test_manifold_mass_conservation_1k_ticks`

**Done when**:
- `phase3_headworks` config loads and validates (`tools/ci/validate_configs.sh` passes).
- All three integration tests pass headless. Report contains **pasted GUT Run Summary
  including Scripts count** (must include this new script). 0 failing.
- `git status` clean.

---

### WP3.2 — Flash Mix & Distribution Box Config + Wiring

**Goal**: Add flash mix and distribution box to the Phase 3 topology. The distribution box
must have five OUTLET ports (one per floc/sed basin placeholder). Verify that flow propagates
from manifold through flash mix into distribution box and that the five-outlet proration
produces deterministic splits.

**Files**:
- `config/plants/phase3_headworks/topology.json` (update)
- `tests/integration/phase3_headworks/test_distribution_box.gd`

**Steps**:

1. Extend the topology to add:
   - `FLASH_MIX_01`: small `StorageUnit` (`surface_area_m2 = 1.0`, `maximum_volume_m3 = 10.0`).
   - `DIST_BOX_01`: small `StorageUnit` (`surface_area_m2 = 1.0`, `maximum_volume_m3 = 10.0`),
     five OUTLET ports (`PORT_BASIN_01` … `PORT_BASIN_05`) connecting to five `ExternalBoundary`
     sinks (placeholder until WP3.3).
   - Links: `MANIFOLD_01` → `FLASH_MIX_01` → `DIST_BOX_01` (RESTRICTED mode).
   - The five outlet links from `DIST_BOX_01` each have `max_flow_m3s` set to the per-basin
     design capacity.

2. Create `tests/integration/phase3_headworks/test_distribution_box.gd`:
   - `test_equal_split_five_basins`: configure all five outlet links with identical
     `max_flow_m3s`. Run solver. Assert each link's granted flow is within EPSILON of
     1/5 of the total granted outflow from `DIST_BOX_01`.
   - `test_proportional_split_capacity`: configure outlet links with capacities
     4:2:2:1:1. Assert granted flows are prorated proportionally to their requests.
   - `test_dist_box_mass_conservation_1k_ticks`: run 1000 ticks, assert ledger ≤ tolerance.

**Tests**:
- `test_equal_split_five_basins`
- `test_proportional_split_capacity`
- `test_dist_box_mass_conservation_1k_ticks`

**Done when**:
- Updated topology validates. All three integration tests pass headless (pasted GUT Run
  Summary with Scripts count required). 0 failing.

---

### WP3.3 — Five Floc/Sed Basins — Config, Wiring & Availability

**Goal**: Replace the five placeholder sink boundaries with five full `StorageUnit` basins.
Implement `SetBasinServiceCommand` which wires the **existing inherited** `in_service` flag
by toggling `is_enabled` on INLET/OUTLET links. Wire the command into `PlantFactory` and
`PlantValidator`.

**Prerequisite**: WP3.0 spec must be committed; the Basin Availability Semantics section in
`SIMULATION_RULES.md` must be accepted before writing any availability code.

**P3-A1**: Do **not** add `var in_service: bool = true` to `storage_unit.gd` — that field
is already declared on `ProcessUnit` and already config-loaded. Adding it to `StorageUnit`
would be a parse error (duplicate declaration in subclass). Use the inherited field as-is.

**Files**:
- `scripts/simulation/commands/set_basin_service_command.gd` (new)
- `scripts/configuration/plant_factory.gd` — register new command type
- `scripts/configuration/plant_validator.gd` — validate `in_service` field type (already
  accepted by `ProcessUnit.initialize()`; add an explicit boolean type-check here)
- `config/plants/phase3_headworks/topology.json` (update — replace placeholder sinks)
- `tests/unit/domain/test_basin_availability.gd` (new)
- `tests/integration/phase3_headworks/test_basin_availability_integration.gd` (new)

**Steps**:

1. Create `set_basin_service_command.gd` (`extends SimulationCommand`):
   - Fields: `target_unit_id: StringName`, `put_in_service: bool`.
   - `execute(context)`:
     1. Resolve `target_unit_id` → `StorageUnit` (assert it is one).
     2. Set `unit.in_service = put_in_service` (writes the inherited field).
     3. For each port on the unit, if `port.connected_link != null`:
        - If port type is **INLET or OUTLET**: `link.is_enabled = put_in_service`.
        - If port type is **DRAIN**: leave `is_enabled` unchanged (P3-A2 — drain must
          remain available for emptying an out-of-service basin).
        - Spill is not a link; no spill path exists to toggle (P3-A3).
   - `validate(context)`: verify `target_unit_id` resolves to a `StorageUnit`.

2. Extend `config/plants/phase3_headworks/topology.json`:
   - Replace five placeholder sinks with five `StorageUnit` basins (`BASIN_01`…`BASIN_05`).
   - Each basin declares `spill_destination_id`, INLET, OUTLET, and DRAIN ports.
   - Applied channel placeholder sink (`APPLIED_CHANNEL_PLACEHOLDER`) downstream until WP3.4.

3. Create `tests/unit/domain/test_basin_availability.gd`:
   - `test_out_of_service_zeroes_all_link_flows`: use `SetBasinServiceCommand` to put one
     basin out of service, run one `FlowSolver.solve_flows`, assert
     `requested == granted == actual == 0` on all its INLET and OUTLET links.
   - `test_in_service_restore_flows`: re-enable via command, run solver again, assert
     nonzero flow on at least one INLET or OUTLET link.
   - `test_drain_stays_enabled_when_out_of_service`: assert DRAIN link `is_enabled` is
     still `true` after `SetBasinServiceCommand(put_in_service=false)` runs.

4. Create `tests/integration/phase3_headworks/test_basin_availability_integration.gd`:
   - `test_four_basin_proration`: take one basin out of service, run solver, assert the
     remaining four basins receive proportionally redistributed flow and total granted
     outflow from `DIST_BOX_01` is unchanged.
   - `test_availability_churn_mass_conservation`: toggle basins in/out of service 100 times
     over 1000 ticks; assert mass-balance ledger ≤ tolerance and no negative volume.

**Tests**:
- `test_out_of_service_zeroes_all_link_flows`
- `test_in_service_restore_flows`
- `test_drain_stays_enabled_when_out_of_service`
- `test_four_basin_proration`
- `test_availability_churn_mass_conservation`

**Done when**:
- All five tests pass headless (pasted GUT Run Summary with Scripts count). 0 failing.
- `git status` clean.

---

### WP3.4 — Applied Channel Config + Level Alarm

**Goal**: Replace the applied channel placeholder with a full `StorageUnit`. Configure level
alarms for high-level (filter starvation risk) and low-level (basin starvation). Wire the
applied channel as the single downstream collector for all five basin OUTLET links.

**Files**:
- `config/plants/phase3_headworks/topology.json` (update)
- `config/plants/phase3_headworks/alarms.json`
- `tests/integration/phase3_headworks/test_applied_channel.gd`

**Steps**:

1. Extend topology:
   - `APPLIED_CHANNEL_01`: `StorageUnit` with `spill_destination_id` = spill boundary.
   - Five links from `BASIN_01`…`BASIN_05` OUTLET ports into `APPLIED_CHANNEL_01` INLET
     (five separate INLET ports, one per basin — each is a separate `FlowLink`).
   - One OUTLET link from `APPLIED_CHANNEL_01` to a filter-feed `ExternalBoundary` sink
     (placeholder until the filter phase).

2. Configure `alarms.json`:
   - `APPLIED_CHANNEL_HIGH_LEVEL`: threshold alarm fires when `level_m ≥ high_level_m`.
   - `APPLIED_CHANNEL_LOW_LEVEL`: threshold alarm fires when `level_m ≤ min_operating_level_m`.

3. Create `tests/integration/phase3_headworks/test_applied_channel.gd`:
   - `test_applied_channel_receives_all_basin_flow`: open all basins, run solver, assert
     `APPLIED_CHANNEL_01.inflow_m3s ≈ sum of all five basin outflows` within EPSILON.
   - `test_applied_channel_high_level_alarm`: drive level above `high_level_m`, assert alarm
     fires within one tick.
   - `test_applied_channel_mass_conservation_1k_ticks`: 1000 ticks, ledger ≤ tolerance.

**Tests**:
- `test_applied_channel_receives_all_basin_flow`
- `test_applied_channel_high_level_alarm`
- `test_applied_channel_mass_conservation_1k_ticks`

**Done when**:
- All three tests pass headless (pasted GUT Run Summary with Scripts count). 0 failing.

---

### WP3.5 — Level Controllers for Applied-Channel Regulation

**Goal**: Configure five existing `LevelController` instances (one per basin inlet gate) to
regulate `APPLIED_CHANNEL_01` level by modulating each gate's opening proportionally to the
level error. No new controller class is created. (P3-A4: a single controller commanding five
actuators requires a new multi-output contract; to avoid forking the P-control implementation,
we use five independent `LevelController` instances sharing the same PV unit and setpoint.)

**Design rationale**: Each `LevelController` targets one actuator (the inlet gate from
`DIST_BOX_01` to one basin). All five share the same `pv_unit_id = "APPLIED_CHANNEL_01"` and
`pv_property = "level_m"`. The FlowSolver then prorates naturally if the combined request
exceeds supply — the controllers provide equal proportional demand signals; proration handles
redistribution when a basin goes out of service (its gate is disabled, removing it from the
proration set automatically).

**Files**:
- `config/plants/phase3_headworks/controllers.json` — five `LevelController` config entries
- `tests/integration/phase3_headworks/test_headworks_controller.gd`

**Steps**:

1. Create `controllers.json` with five `LevelController` entries:
   - Each entry: `type = "LevelController"`, `pv_unit_id = "APPLIED_CHANNEL_01"`,
     `pv_property = "level_m"`, `target_actuator_id = "<basin_N_inlet_gate>"`,
     same `gain`, `deadband_m`, `min_output = 0.0`, `max_output = 1.0`.
   - Wire into `PlantFactory` (already handles `LevelController` from WP2.4; no new
     factory code needed — confirm the existing loading path handles multiple instances).

2. Create `tests/integration/phase3_headworks/test_headworks_controller.gd`:
   - `test_five_controllers_stabilize_applied_channel_level`: run 1000 ticks with all five
     controllers in AUTO, assert `|APPLIED_CHANNEL_01.level_m - setpoint| ≤ deadband_m`
     after settling.
   - `test_controller_redistribution_on_basin_loss`: take one basin out of service mid-run
     (disabling its inlet gate link); assert the four remaining controllers still maintain
     level within ±10% of setpoint within 100 ticks.

**Tests**:
- `test_five_controllers_stabilize_applied_channel_level`
- `test_controller_redistribution_on_basin_loss`

**Done when**:
- Both tests pass headless (pasted GUT Run Summary with Scripts count). 0 failing.
- No new `SimController` subclass created — only `LevelController` instances in config.

---

### WP3.6 — Config Schema Sync (All Phase 3 New Fields)

**Goal**: Ensure every new config field introduced in WP3.1–WP3.5 has a corresponding
schema entry in `config/schema/` and is validated by `plant_validator.gd`. Add a
`presentation_map.json` for `phase3_headworks` so the positive schema path is exercised
in CI (addressing the WP2.5 review nit).

**Files**:
- `config/schema/topology.schema.json` (update — confirm `in_service` field already present
  since Phase 1; add it if absent)
- `config/schema/presentation_map.schema.json` (confirm exists from WP2.5)
- `config/plants/phase3_headworks/presentation_map.json` (new)
- `scripts/configuration/plant_validator.gd` (update — explicit boolean type-check for
  `in_service`; no junction-size heuristic — see P3-A5 below)
- `tools/ci/validate_configs.sh` (guard already in place from WP2.2-R)

**Steps**:

1. Update `config/schema/topology.schema.json`:
   - Ensure `in_service` (type: boolean, default: true) is present.

2. Update `plant_validator.gd`:
   - Add explicit boolean type-check for `in_service` if present in config.
   - **P3-A5**: Do **not** add a `surface_area_m2 > 1.0 AND maximum_volume_m3 ≤ 10.0`
     warning. That heuristic is inverted relative to §1.2's sizing rule and would
     false-positive on legitimately small basins. The existing `simulation_resolution_warning`
     (`max_inflow × dt vs operating_volume`) in `SIMULATION_RULES.md` already covers
     fast-turnover risk; replicate that ratio check if any automated check is needed.

3. Create `config/plants/phase3_headworks/presentation_map.json` so
   `presentation_map.schema.json` positive path is exercised in CI.

4. Run `tools/ci/validate_configs.sh` — must exit 0.

**Tests**: All existing integration + schema validation CI must still pass.

**Done when**:
- `tools/ci/validate_configs.sh` exits 0.
- No schema changes break existing config files (all positive fixtures still pass).
- GUT suite: pasted Run Summary including Scripts count, 0 failing.

---

### WP3.7 — Phase 3 Verification & Soak Suite

**Goal**: Consolidate all Phase 3 correctness checks into a comprehensive automated suite
that mirrors WP2.6. Tests cover mass conservation, availability churn, and deterministic replay
across the full headworks train.

**Files**:
- `tests/integration/phase3_headworks/test_phase3_verification.gd`
- `tests/invariants/test_phase3_invariants.gd`

**Steps**:

1. `test_phase3_verification.gd`:
   - **`test_phase3_soak_100k_ticks`**: run the full headworks topology at 60× for 100,000
     ticks with fluctuating inflow demand (ramp source up and down every 5000 ticks). Assert
     zero mass-balance errors (within tolerance) and no negative volume across all units.
   - **`test_availability_churn_100k_ticks`**: randomly toggle basins in/out of service every
     500 ticks across 100,000 ticks. Assert ledger error ≤ tolerance and no negative volume.
   - **`test_deterministic_replay_phase3`**: record a 1000-tick sequence of commands (valve
     moves, basin toggles), replay from identical initial state, assert identical state
     trajectories (bit-exact comparison of snapshots).

2. `test_phase3_invariants.gd`:
   - **`test_no_water_created_phase3`** (P3-A6): validate mass conservation across a
     10,000-tick run. The assertion form must use the established tolerance:
     ```
     # Correct — matches Phase 2 invariant test form:
     assert mass_balance_report.mass_balance_error_m3 <= 1e-9 * scale * sqrt(tick_count)
     # where scale accounts for the larger Phase 3 plant volume
     #
     # Obtain the report via:
     var report: Dictionary = engine.mass_balance_tracker.report()
     # NOT: MassBalanceTracker.total_error_m3  (no such field)
     ```
   - **`test_dag_unchanged_after_availability_toggle`**: assert `topological_units_list` is
     identical before and after a basin is taken out of service (DAG is static).

**Tests**:
- `test_phase3_soak_100k_ticks`
- `test_availability_churn_100k_ticks`
- `test_deterministic_replay_phase3`
- `test_no_water_created_phase3`
- `test_dag_unchanged_after_availability_toggle`

**Done when**:
- All five tests pass headless. Report contains **pasted GUT Run Summary including Scripts
  count** (must include all Phase 3 scripts). 0 failing.
- `git status` clean.
- Commit message begins `WP3.7:`.

---

## 5. Config & Schema

New plant directory: `config/plants/phase3_headworks/`

| File | Created in WP | Notes |
|---|---|---|
| `plant.json` | WP3.1 | Plant metadata |
| `topology.json` | WP3.1, extended in WP3.2–3.4 | Full headworks DAG |
| `initial_conditions.json` | WP3.1 | Non-zero volumes for all units |
| `controllers.json` | WP3.5 | Level controller for applied channel |
| `alarms.json` | WP3.4 | High/low alarms on applied channel |
| `presentation_map.json` | WP3.6 | Exercises presentation_map schema positive path |

**AGENTS rule 13**: every new config field must update `config/schema/` and
`plant_validator.gd` in the **same commit**. Field documentation lives in the schema
`description` field — do not duplicate it in prose docs.

---

### WP3.8 — Headworks Presentation & Parity

**Goal**: Build the visual presentation for the full headworks train, mirroring WP2.5's
pattern. Water levels move on all wet units (reservoirs, manifold, flash mix, distribution
box, five basins, applied channel); the asset panel shows controller and availability state;
an out-of-service basin is visually distinct. Simulation code is not modified (INV-3).

**Files**:
- `scenes/plant/headworks.tscn`
- `config/plants/phase3_headworks/presentation_map.json` (extend — map every wet unit;
  created in WP3.6)
- `scripts/ui/controllers/asset_panel.gd` (extend — show `in_service` state and a
  Set-In/Out-of-Service button issuing `SetBasinServiceCommand` via `CommandBus`)
- `tests/integration/phase3_headworks/test_presentation_parity.gd`

**Steps**:
1. Build `headworks.tscn` reusing the WP2.5 visual adapters — new units are
   `presentation_map.json` entries, not new adapter code. Any unit absent from the map gets
   the default box (WP2.5 contract).
2. Extend `asset_panel.gd`: display `in_service`, wire the service toggle through
   `CommandBus` only (no direct domain writes — INV-3).
3. `test_presentation_parity.gd`: drive the same command script (valve moves + basin
   toggles) in visual and headless modes via `advance_frame`; assert identical state
   trajectories.

**Tests**:
- `test_headworks_presentation_parity`

**Done when**:
- Visual scene runs at 1× and 60× with moving water; taking a basin out of service is
  visible and flow redistribution can be observed.
- Parity test passes headless (pasted GUT Run Summary including Scripts count). 0 failing.
- Zero files under `scripts/simulation/` modified in this WP (INV-3 — verify with
  `git diff --stat`).
- `git status` clean. Commit message begins `WP3.8:`.

---

## 6. Final WPs — Verification (WP3.7) then Presentation (WP3.8)

WP3.7 mirrors WP2.6's structure and exit criteria exactly. WP3.8 follows it and closes the
phase with the visual product.

---

## 7. Exit Condition (Phase 3 Gate)

Phase 3 is complete when:
1. WP3.7 soak, churn, and replay tests pass with reviewer-verified output.
2. Mass balance ledger shows zero error across 100k-tick headworks soak.
3. Basin availability toggling produces correct flow redistribution with no water creation.
4. WP3.8 visual scene runs at 1× and 60×, basin-availability toggling is observable, and
   the headless/visual parity test passes with reviewer-verified output.
5. `git status` is clean; CHANGELOG.md has entries for all WP3.x deliverables.
6. Reviewer confirms G-Phase3 gate closed.

---

---

## 8. Phase 3 Execution Protocol (orchestrator-authorized, 2026-07-04)

Phase 2 is closed and this plan is accepted. The per-WP review pause is **suspended for Phase 3** and replaced by batch audits, to let the implementing agent run further independently. Binding rules:

1. **Execute WP3.0 → WP3.8 sequentially**, one commit per WP (commit message begins `WP3.x:`), without waiting for review between WPs — *provided every gate below stays green*.
2. **Every WP's report must contain the pasted GUT Run Summary including the Scripts count** matching that WP's expected totals, or the exact wording "Tests written but NOT executed — unverified." An unverified WP is a **hard stop**: do not begin the next WP until the orchestrator has run the suite.
3. **Hard stops — halt and report immediately, do not proceed:** any failing test; any drop in collected script count; any deviation from this plan's per-WP file list; any simulation-code change in a docs- or test-only WP; any need to modify an accepted Phase 2 file outside a WP's scope; any `assert` weakened, deleted, or bypassed.
4. **WP3.8 must also close W2.5-1** (asset panel enumerates snapshot, holds IDs not domain references — see PHASE2_CODE_REVIEW).
5. **Never write to `PHASE2_CODE_REVIEW.md` or any review verdict document.** Review verdicts are issued only by the orchestrator's reviewer. Implementer self-reviews recorded as acceptance are a firing-severity violation (it happened once; see the removed commit noted in PHASE2_CODE_REVIEW).
6. **Batch audit points:** the orchestrator reviews at **WP3.3** (spec + configs + availability wiring) and at **WP3.8** (phase exit, including WP3.7 soak rerun by the reviewer). Findings at an audit point may reopen earlier WPs; keep them small.
7. All existing AGENTS.md guardrails remain in force unchanged.
