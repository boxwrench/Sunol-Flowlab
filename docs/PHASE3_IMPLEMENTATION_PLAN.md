# Implementation Plan — Phase 3: Headworks & Five Sedimentation Trains

This document defines the work-package (WP) breakdown for Phase 3 of Sunol FlowLab.
The goal of Phase 3 is to build the full headworks topology and five parallel sedimentation
trains: two source reservoirs, inlet manifold, flash mix, distribution box, five floc/sed basins,
and the applied channel. This introduces flow splitting across parallel trains and basin
availability (in-service / out-of-service toggling at runtime).

**Gate prerequisite**: WP2.2-R must be reviewed and its G5 gate closed before any Phase 3 WP
begins. Reviews of WP2.3–2.6 must follow, one per cycle, in order. Phase 3 does not start
until all outstanding Phase 2 reviews are complete.

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

> **This subsection defines binding rules that WP3.1 will write into SIMULATION_RULES and
> PROCESS_UNIT_CONTRACTS before any code WP.**

A floc/sed basin is considered **available** when both:
1. Its `in_service` boolean flag is `true` on the `StorageUnit`, AND
2. All links attached to its INLET and OUTLET ports have `is_enabled = true`.

Taking a basin **out of service** means:
- Setting `unit.in_service = false` on the `StorageUnit` (tracking field, no direct solver effect).
- Setting `is_enabled = false` on **every FlowLink** connected to the basin's INLET, OUTLET,
  and DRAIN ports. This causes FlowSolver (F2.2-2 fix) to zero all three flow fields
  (`requested`, `granted`, `actual`) on those links and exclude them from proration sets.
- The basin's own `solve_tick` continues to run but receives zero inflows and grants zero
  outflows, so its volume is frozen (no flow = no change from flow).
- The basin does **not** get removed from the topological list; the DAG remains static.
- Spill: if a basin is out of service and still has volume above `spill_level_m`, its spill
  link remains enabled (spill is gravity/passive, not operator-controlled). If the basin is
  to be isolated completely, the operator must also drain it via the DRAIN link before
  disabling the spill boundary link.

**F2.2-2 fix is a prerequisite for basin availability**. The fix must be accepted (reviewer
confirmed) before WP3.3 (which wires basin availability at runtime) begins.

Taking a basin **back into service** reverses the above: re-enable all its links. FlowSolver
then begins granting flow naturally on the next tick.

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
| **WP3.0** | Spec: basin-availability semantics + small-storage sizing | Documentation | `SIMULATION_RULES.md`, `PROCESS_UNIT_CONTRACTS.md` | WP2.2-R reviewed; WP2.3–2.6 reviewed |
| **WP3.1** | Source Reservoirs & Inlet Manifold config + wiring | Configuration / Data | `config/plants/phase3_headworks/` | WP3.0 |
| **WP3.2** | Flash Mix & Distribution Box config + wiring | Configuration / Data | `config/plants/phase3_headworks/` | WP3.1 |
| **WP3.3** | Five Floc/Sed Basins — config, wiring, availability | Configuration / Domain | plant config, `storage_unit.gd` `in_service` field | WP3.2 |
| **WP3.4** | Applied Channel config + level alarm | Configuration / Domain | plant config, alarm config | WP3.3 |
| **WP3.5** | Basin availability commands & controller | Automation / Commands | `set_basin_service_command.gd` | WP3.3 |
| **WP3.6** | Config schema sync (all Phase 3 new fields) | Configuration / Schema | `config/schema/`, `plant_validator.gd` | WP3.4, WP3.5 |
| **WP3.7** | Phase 3 Verification & Soak Suite | Verification / Tests | `tests/integration/phase3_headworks/` | WP3.6 |

---

## 4. Per-WP Sections

---

### WP3.0 — Spec: Basin-Availability Semantics + Small-Storage Sizing (docs-only)

**Goal**: Write all new binding rules into `SIMULATION_RULES.md` and `PROCESS_UNIT_CONTRACTS.md`
before any code is written. This is the spec-first guardrail for Phase 3.

**Files**:
- `docs/SIMULATION_RULES.md` — new subsection: **Basin Availability Semantics**
- `docs/PROCESS_UNIT_CONTRACTS.md` — new subsection: **Basin Availability Contract**;
  update `StorageUnit` contract to include `in_service` field

**Steps**:

1. Add to `SIMULATION_RULES.md` § Basin Availability Semantics (new subsection after
   Determinism and Edge Rules):
   - Define `in_service` as a `StorageUnit` tracking field (not a solver field directly).
   - Define the "out of service" precondition: all attached links `is_enabled = false`.
   - Define the tick behavior when out of service (frozen volume, no spill suppression).
   - Cite the F2.2-2 fix as prerequisite.
   - Define the `simulation_resolution_warning` sizing rule for junction StorageUnits
     (surface_area ≤ 1.0 m², max_volume ≤ 10.0 m³, no min_operating_level).

2. Add to `PROCESS_UNIT_CONTRACTS.md`:
   - `in_service: bool` field in the `StorageUnit` contract (default `true`).
   - New command: `SetBasinServiceCommand` (enable/disable all links + flip flag).
   - Confirm that out-of-service does **not** remove the unit from the topological list.

3. Cross-reference INDEX.md (already links PROCESS_UNIT_CONTRACTS and SIMULATION_RULES).

**Tests**: None — docs-only WP.

**Done when**:
- `docs/SIMULATION_RULES.md` contains the Basin Availability Semantics subsection with all
  rules from §1.4 of this plan explicitly stated and no contradictions with existing rules.
- `docs/PROCESS_UNIT_CONTRACTS.md` defines the `in_service` field and `SetBasinServiceCommand`.
- Commit message begins `spec:`. No code files, no config files, no test files in this commit.

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
Add `in_service` field to `StorageUnit`. Implement `SetBasinServiceCommand` which toggles
`is_enabled` on all attached links and flips the `in_service` flag. Wire the command into
`PlantFactory` and `PlantValidator`.

**Prerequisite**: WP3.0 spec must be committed; the Basin Availability Semantics section in
SIMULATION_RULES must be accepted before writing any `in_service` code.

**Files**:
- `scripts/simulation/domain/storage_unit.gd` — add `var in_service: bool = true`
- `scripts/simulation/commands/set_basin_service_command.gd` (new)
- `scripts/configuration/plant_factory.gd` — register new command type
- `scripts/configuration/plant_validator.gd` — validate `in_service` field type
- `config/plants/phase3_headworks/topology.json` (update — replace placeholder sinks)
- `tests/unit/domain/test_basin_availability.gd` (new)
- `tests/integration/phase3_headworks/test_basin_availability_integration.gd` (new)

**Steps**:

1. Update `storage_unit.gd`:
   - Add `var in_service: bool = true`, loaded from config with default `true`.
   - `initialize()` reads `config.get("in_service", true)`.
   - No solver logic added here — availability is enforced through link `is_enabled` only.

2. Create `set_basin_service_command.gd` (`extends SimulationCommand`):
   - Fields: `target_unit_id: StringName`, `put_in_service: bool`.
   - `execute(context)`:
     1. Resolve `target_unit_id` → `StorageUnit`.
     2. Set `unit.in_service = put_in_service`.
     3. For each port on the unit, if `port.connected_link != null`:
        - If port type is INLET or OUTLET: `link.is_enabled = put_in_service`.
        - If port type is DRAIN: leave enabled (drain must remain available for emptying).
     4. Do NOT disable spill destination links (spill is passive/gravity).
   - `validate(context)`: verify `target_unit_id` resolves to a `StorageUnit`.

3. Extend `config/plants/phase3_headworks/topology.json`:
   - Replace five placeholder sinks with five `StorageUnit` basins
     (`BASIN_01` … `BASIN_05`).
   - Each basin declares `spill_destination_id`, INLET, OUTLET, and DRAIN ports.
   - Applied channel placeholder sink (`APPLIED_CHANNEL_PLACEHOLDER`) as downstream boundary
     until WP3.4.

4. Create `tests/unit/domain/test_basin_availability.gd`:
   - `test_out_of_service_zeroes_all_link_flows`: put one basin out of service, run one
     FlowSolver solve, assert `requested == granted == actual == 0` on all its INLET and
     OUTLET links.
   - `test_in_service_restore_flows`: re-enable, run solver again, assert nonzero flow on
     at least one link.
   - `test_drain_stays_enabled_when_out_of_service`: verify DRAIN link is not disabled by
     `SetBasinServiceCommand`.

5. Create `tests/integration/phase3_headworks/test_basin_availability_integration.gd`:
   - `test_four_basin_proration`: take one basin out of service, assert the remaining four
     basins receive proportionally more flow (total grant unchanged, redistributed).
   - `test_availability_churn_mass_conservation`: take basins in and out of service 100
     times over 1000 ticks, assert mass-balance ledger ≤ tolerance and no negative volume.

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

### WP3.5 — Basin Availability Commands & Controller

**Goal**: Add a proportional level controller targeting `APPLIED_CHANNEL_01` level, which
modulates the distribution box outlet valve openings to maintain a setpoint. Verify that
toggling basin availability causes the controller to re-distribute flow across remaining
in-service basins without operator intervention.

**Files**:
- `scripts/simulation/automation/headworks_level_controller.gd` (new — extends
  `SimController`)
- `config/plants/phase3_headworks/controllers.json`
- `tests/integration/phase3_headworks/test_headworks_controller.gd`

**Steps**:

1. Create `headworks_level_controller.gd`:
   - Operates in AUTO mode: reads `APPLIED_CHANNEL_01.level_m` as PV, modulates the
     distribution box outlet valve openings proportionally.
   - In MANUAL mode: hold current output.
   - Warn-once on FORCED / FAILED mode (not implemented; treated as MANUAL).
   - Bumpless transfer: initialize output to current valve position on MANUAL → AUTO switch.

2. Wire into `controllers.json` and `PlantFactory`.

3. Create `tests/integration/phase3_headworks/test_headworks_controller.gd`:
   - `test_controller_stabilizes_applied_channel_level`: run 1000 ticks with level controller
     in AUTO, assert `|level - setpoint| ≤ deadband_m` after settling.
   - `test_controller_redistributes_on_basin_loss`: take one basin out of service mid-run,
     assert controller adapts and level stays within ±10% of setpoint within 100 ticks.

**Tests**:
- `test_controller_stabilizes_applied_channel_level`
- `test_controller_redistributes_on_basin_loss`

**Done when**:
- Both tests pass headless (pasted GUT Run Summary with Scripts count). 0 failing.

---

### WP3.6 — Config Schema Sync (All Phase 3 New Fields)

**Goal**: Ensure every new config field introduced in WP3.1–WP3.5 has a corresponding
schema entry in `config/schema/` and is validated by `plant_validator.gd`. Add a
`presentation_map.json` for `phase3_headworks` so the positive schema path is exercised
in CI (addressing the WP2.5 review nit).

**Files**:
- `config/schema/topology.schema.json` (update — `in_service`, junction sizing constraints)
- `config/schema/presentation_map.schema.json` (confirm exists from WP2.5)
- `config/plants/phase3_headworks/presentation_map.json` (new)
- `scripts/configuration/plant_validator.gd` (update — validate `in_service`, warn on
  junction sizing violations)
- `tools/ci/validate_configs.sh` (confirm guard in place from WP2.2-R)

**Steps**:

1. Update `config/schema/topology.schema.json`:
   - Add `in_service` field (type: boolean, default: true).
   - Add a `simulation_resolution_warning` check comment for junction units (schema cannot
     enforce warnings, so `plant_validator.gd` emits `push_warning` if `surface_area_m2 > 1.0`
     on a unit whose `maximum_volume_m3 ≤ 10.0`).

2. Create `config/plants/phase3_headworks/presentation_map.json` so
   `presentation_map.schema.json` positive path is exercised.

3. Run `tools/ci/validate_configs.sh` — must exit 0.

4. Update `plant_validator.gd`:
   - Validate `in_service` is boolean if present.
   - Emit `push_warning` (not error) when a `StorageUnit` has
     `surface_area_m2 > 1.0` and `maximum_volume_m3 ≤ 10.0` (possible junction misconfiguration).

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
   - **`test_no_water_created_phase3`**: after every tick in a 10,000-tick run, assert
     `MassBalanceTracker.total_error_m3 ≤ EPSILON * tick_count`.
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

## 6. Final WP (WP3.7) — Verification & Soak Suite

See §4 WP3.7 above. This mirrors WP2.6's structure and exit criteria exactly.

---

## 7. Exit Condition (Phase 3 Gate)

Phase 3 is complete when:
1. WP3.7 soak, churn, and replay tests pass with reviewer-verified output.
2. Mass balance ledger shows zero error across 100k-tick headworks soak.
3. Basin availability toggling produces correct flow redistribution with no water creation.
4. `git status` is clean; CHANGELOG.md has entries for all WP3.x deliverables.
5. Reviewer confirms G-Phase3 gate closed.

---

> **STOP after Task 2 commit. Phase 3 WP execution is gated on orchestrator review of this plan.**
