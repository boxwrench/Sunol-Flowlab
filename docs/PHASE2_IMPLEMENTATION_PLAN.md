# Implementation Plan — Phase 2: Connected Three-Unit Sandbox

This document defines the work-package (WP) breakdown for Phase 2 of Sunol FlowLab.
The goal of Phase 2 is to connect a three-unit train (**Source Reservoir → Basin → Receiving Reservoir**), implement the G5 two-pass Directed Acyclic Graph (DAG) flow solver with proportional proration and boundary constraints, and establish simple proportional level control.

---

## Phase 2 Architecture & Edge Rules Map

To satisfy the **six Determinism and Edge Rules** defined in [SIMULATION_RULES.md](SIMULATION_RULES.md) and the three core invariants (**INV-1/2/3**), the work packages below are structured around the following constraints:

1. **Deterministic Topological Order (Edge Rule 1)**: Kahn's algorithm with a ready-set sorted lexicographically by unit ID is implemented at plant build. The resulting order is cached on the context and used for solver sweeps.
2. **One Proration Authority (Edge Rule 2)**: Flow proration is calculated *only* in `FlowSolver.solve_flows()`. In debug builds, `StorageBalance.solve()` asserts if its internal proration is triggered.
3. **Withdrawable vs Total Volume (Edge Rule 3)**: OUTLET ports draw only from volume above `min_operating_level_m`. DRAIN ports draw to zero volume. Both `FlowSolver` and `StorageBalance` share this exact calculation.
4. **Boundary Flows Sum Across Links (Edge Rule 4)**: `ExternalBoundary.current_flow_m3s` is calculated as the sum of its connected links' actual flows (using `+=` instead of `=`). Total flow is capped and prorated by `flow_limit_m3s`.
5. **Spill Routing is Per-Unit (Edge Rule 5)**: `StorageUnit` reads `spill_destination_id` from config; no default is injected in code. The plant validator errors if `spill_destination_id` does not resolve to a known boundary.
6. **COMMANDED Mode warning (Edge Rule 6)**: Links configured as `COMMANDED` raise a warning using `push_warning()` and behave as `RESTRICTED` at full opening (1.0). Silent placeholder behavior is prohibited.

---

## Sequencing Summary

| WP | Title | Layer | Primary Files | Depends On |
|---|---|---|---|---|
| **WP2.1** | Deterministic Topological Sorter | Core / Configuration | `plant_factory.gd`, `simulation_context.gd` | Phase 1 baseline |
| **WP2.2** | G5 FlowSolver & Proration Core | Hydraulics | `flow_solver.gd`, `storage_balance.gd` | WP2.1 |
| **WP2.3** | Three-Unit Sandbox Config & Wiring | Configuration / Data | `phase2_three_unit/`, `config_loader.gd` | WP2.2 |
| **WP2.4** | Proportional Level Controller & Commands | Automation / Commands | `controller.gd`, `level_controller.gd` | WP2.3 |
| **WP2.5** | Presentation & Visuals for Train | Presentation / UI | `three_unit_train.tscn`, `asset_panel.gd` | WP2.4 |
| **WP2.6** | Phase 2 Verification & Soak Suite | Verification / Tests | `test_three_unit_verification.gd` | WP2.5 |

---

## Work Packages

### WP2.1 — Deterministic Topological Sorter

**Goal**: Implement a deterministic topological sorting algorithm using Kahn's algorithm that breaks ready-set ties lexicographically by unit ID, and cache the result on the simulation context.

**Files**:
- `scripts/simulation/core/simulation_context.gd`
- `scripts/configuration/plant_factory.gd`
- `tests/unit/configuration/test_topological_sort.gd`

**Steps**:
1. Update [simulation_context.gd](../scripts/simulation/core/simulation_context.gd):
   - Add `var topological_units_list: Array = []` to store the sorted list of `ProcessUnit` objects.
2. Update [plant_factory.gd](../scripts/configuration/plant_factory.gd):
   - In `build_plant`, implement Kahn's algorithm:
     - Compute the in-degree of all units based on `FlowLink` connections: `link.source_port.parent_unit` -> `link.destination_port.parent_unit`.
     - Find all units with in-degree = 0. Add their IDs to a `ready_set` array.
     - Sort `ready_set` alphabetically to enforce deterministic tie-breaking (lexicographical sort on unit ID).
     - While `ready_set` is not empty, pop the lexicographically smallest ID, retrieve the unit, and append it to `topological_units_list`.
     - For each outgoing link from the popped unit, decrement the in-degree of its destination unit. If the in-degree becomes 0, push its ID into the `ready_set` and re-sort `ready_set`.
     - Assert that `topological_units_list.size() == context.units_list.size()` to verify the graph is cycle-free (DAG check).
     - Store the sorted list in `context.topological_units_list`.
3. Create [test_topological_sort.gd](../tests/unit/configuration/test_topological_sort.gd):
   - Write `test_topological_sort_order` using GUT to verify sorting for a simple chain.
   - Write `test_topological_sort_permutation_invariance` to verify that permuted unit-declaration orders in the JSON topology file yield the identical topological order.
   - Write `test_topological_sort_cycle_detection` asserting that cyclic topologies fail validation.

**Tests**:
- `test_topological_sort_order`
- `test_topological_sort_permutation_invariance`
- `test_topological_sort_cycle_detection`

**Done when**:
- All three tests above pass headless (GUT runner output shows 3 collected, 3 passed, 0 failed).
- Tests written but NOT executed in an environment without the `godot` executable are marked "unverified" per guardrail 1.

---

### WP2.2 — G5 FlowSolver & Proration Core

**Goal**: Implement the two-pass request/grant DAG flow solver in `FlowSolver`, align the withdrawable volume math with `StorageBalance`, and enforce boundary flow summing and spill routing.

**Files**:
- `scripts/simulation/hydraulics/flow_solver.gd`
- `scripts/simulation/hydraulics/storage_balance.gd`
- `scripts/simulation/core/simulation_engine.gd`
- `scripts/simulation/domain/storage_unit.gd`
- `tests/unit/hydraulics/test_flow_solver.gd`

**Steps**:
1. Update [storage_unit.gd](../scripts/simulation/domain/storage_unit.gd):
   - Add `var spill_destination_id: StringName` field — **loaded from config only, no code default**.
     The plant validator must emit an error if `spill_destination_id` is absent or does not resolve
     to a known boundary in the topology (Edge Rule 5). Do not inject a `"SPILL_SINK"` fallback in
     `StorageUnit.initialize()`.
   - Add `available_outlet_withdrawal_m3(dt: float)` for OUTLET ports:
     returns `max(0.0, volume_m3 - min_operating_level_m * surface_area_m2)`.
   - `available_withdrawal_m3(dt)` (existing method) continues to serve DRAIN ports and returns
     total volume `max(0.0, volume_m3)`.
2. Update [storage_balance.gd](../scripts/simulation/hydraulics/storage_balance.gd):
   - Redefine available volume checks for `requested_outflow_m3s` (OUTLET) and `requested_drain_flow_m3s` (DRAIN) using the same min-level cutoff as `available_outlet_withdrawal_m3`.
   - In `solve()`, add a debug assert: `assert(total_requested_withdrawal_volume <= available_volume + EPSILON, "StorageBalance proration triggered! This indicates a solver grant leak.")` (Edge Rule 2).
3. Update [flow_solver.gd](../scripts/simulation/hydraulics/flow_solver.gd):
   - **Pass 1 (Downstream-to-Upstream Requests)**:
     - Iterate `context.topological_units_list` in **reverse order**.
     - For each incoming link to the unit, compute `requested_flow_m3s`.
     - In `RESTRICTED` mode, compute based on actuator opening.
     - In `COMMANDED` mode, raise a warning via `push_warning()` and treat as restricted with opening = 1.0 (Edge Rule 6).
     - If the destination is an `ExternalBoundary` sink with a `flow_limit_m3s >= 0.0`, prorate the incoming links' requests proportionally if their sum exceeds the limit.
   - **Pass 2 (Upstream-to-Downstream Grants)**:
     - Iterate `context.topological_units_list` in **forward order**.
     - Determine available supply for the unit: `volume / dt + total_granted_inflow`.
     - Collect outgoing links, separate into `OUTLET` and `DRAIN`.
     - Prorate `OUTLET` links first against `outlet_supply = max(0, volume - min_vol) / dt + inflow`.
     - Prorate `DRAIN` links against `total_supply`.
     - If total grants (outlet + drain) exceed `total_supply`, prorate all outgoing links proportionally to fit the total supply limit.
     - If the source is an `ExternalBoundary` with `flow_limit_m3s >= 0.0`, prorate outgoing links to fit the boundary limit (Edge Rule 4).
     - Set `link.granted_flow_m3s = link.requested_flow_m3s` (capped by proration). **Note**: the
       assignment is `granted_flow_m3s = <prorated value>` — never `actual_flow_m3s = granted_flow_m3s`
       at this stage; `actual_flow_m3s` is written only after `StorageBalance.solve()` in `solve_tick()`.
4. Update [simulation_engine.gd](../scripts/simulation/core/simulation_engine.gd):
   - In `_step_calculate_levels_spills()`, set boundary flows using `+=` to sum flows across multiple links (Edge Rule 4).
   - Route `StorageUnit` spills to their configured `spill_destination_id` boundary instead of global summing (Edge Rule 5).
5. Create `tests/unit/hydraulics/test_flow_solver.gd`:
   - Verify proportional proration on a unit with multiple outlet links.
   - Verify boundary limit enforcement and proration.
   - Verify DRAIN vs OUTLET supply limits.
   - Verify `StorageBalance` does not trigger fallback proration under valid solver grants.

**Tests**:
- `test_flow_solver_proration`
- `test_flow_solver_boundary_limits`
- `test_flow_solver_outlet_vs_drain`
- `test_flow_solver_defensive_assert`

**Done when**:
- G5 solver algorithm passes all four unit test scenarios.
- Mass-balance integration tests run without triggering StorageBalance assertions.

---

### WP2.3 — Three-Unit Sandbox Config & Wiring

**Goal**: Establish the plant configuration files for the three-unit train and verify basic flow propagation through the connected units.

**Files**:
- `config/plants/phase2_three_unit/plant.json`
- `config/plants/phase2_three_unit/topology.json`
- `config/plants/phase2_three_unit/initial_conditions.json`
- `scripts/configuration/config_loader.gd`
- `scripts/configuration/plant_validator.gd`
- `tests/integration/three_unit_train/test_flow_propagation.gd`

**Steps**:
1. Create config files in `config/plants/phase2_three_unit/`:
   - **Topology**: Connect `EXTERNAL_SOURCE` -> `Source Reservoir` -> `Basin` -> `Receiving Reservoir` -> `EXTERNAL_SINK`. Add drain and spill sinks. Each `StorageUnit` must declare a `spill_destination_id` that resolves to a boundary in this topology.
   - **Initial Conditions**: Set non-zero initial volumes and default valve actuators.
2. Update [config_loader.gd](../scripts/configuration/config_loader.gd) and [plant_validator.gd](../scripts/configuration/plant_validator.gd):
   - Add loading and validation support for `controllers.json` and `alarms.json` if they exist (optionally default to empty).
   - Ensure the validator asserts cycle-free topology for the 3-unit train.
   - Ensure the validator errors on any `StorageUnit` whose `spill_destination_id` is absent or does not resolve to a known boundary.
3. Create `tests/integration/three_unit_train/test_flow_propagation.gd`:
   - Initialize the `phase2_three_unit` plant configuration.
   - Actuate valves manually using `SetValvePositionCommand`.
   - Verify that inflows at the headworks propagate down to the receiving reservoir.
   - Verify that the mass-balance ledger conservation invariant holds exactly (error <= tolerance) across 1,000 ticks.
   - Verify that draining works down to zero volume, and outlet starvation stops flow when reaching the low-low cutoff.

**Tests**:
- `test_three_unit_propagation`
- `test_three_unit_mass_conservation`
- `test_three_unit_drain_to_zero`
- `test_three_unit_outlet_cutoff`

**Done when**:
- `phase2_three_unit` configuration loads and validates successfully.
- Flow propagation integration tests pass.

---

### WP2.4 — Proportional Level Controller & Commands

**Goal**: Implement the `SimController` base class and a proportional level controller with deadband that regulates a valve position based on level error, supporting bumpless transfer.

**Scope note**: FORCED and FAILED control modes are explicitly deferred to a later phase. This WP covers MANUAL and AUTO modes only.

**Files**:
- `scripts/simulation/domain/controller.gd`
- `scripts/simulation/automation/level_controller.gd`
- `scripts/simulation/commands/set_controller_mode_command.gd`
- `scripts/simulation/commands/set_level_setpoint_command.gd`
- `scripts/configuration/plant_factory.gd`
- `scripts/configuration/plant_validator.gd`
- `config/plants/phase2_three_unit/controllers.json`
- `tests/unit/automation/test_level_controller.gd`
- `tests/integration/three_unit_train/test_closed_loop_control.gd`

**Steps**:
1. Create `controller.gd` (`extends RefCounted`):
   - Define fields: `target_actuator_id`, `pv_unit_id`, `pv_property`, `control_mode` (MANUAL, AUTO),
     `gain`, `bias`, `deadband_m`, `min_output`, `max_output`, `previous_output`.
   - `deadband_m` is the half-width of the no-action zone around zero error (per CONTROL_LOGIC.md §Proportional control). Units: metres.
2. Create `level_controller.gd` (`extends SimController` via `controller.gd`):
   - Implement `evaluate(context)` step:
     - In `AUTO` mode, calculate `error = setpoint - pv_value`.
     - If `abs(error) <= deadband_m`, skip output update (hold previous output).
     - Otherwise compute output: `output = previous_output + gain * error`.
     - Clamp output to `[min_output, max_output]`.
     - Update target actuator commanded position: `actuator.commanded_position = output`.
     - Store `previous_output = output`.
     - Handle **Bumpless Transfer**: when switching from MANUAL to AUTO, initialize `previous_output` to the target actuator's current position to prevent jumps.
   - In `MANUAL` mode, do nothing in `evaluate()`.
   - FORCED and FAILED modes: not implemented. If encountered, emit `push_warning()` and treat as MANUAL.
3. Create commands:
   - `SetControllerModeCommand`: changes controller between MANUAL and AUTO.
   - `SetLevelSetpointCommand`: changes level setpoint.
4. Update `PlantFactory` & `PlantValidator`:
   - Load controllers from `controllers.json` and validate fields (dangling actuator/unit IDs, positive gain, valid bounds, `deadband_m >= 0`).
   - Wire controller evaluation in `SimulationEngine._step_evaluate_controllers()`.
5. Create tests:
   - **Unit Tests**:
     - `test_controller_proportional_response`: verify output changes proportionally to error outside deadband.
     - `test_controller_deadband`: verify output does NOT change when `|error| <= deadband_m`.
     - `test_controller_bumpless_transfer`: verify no output jump on MANUAL→AUTO switch.
   - **Integration Tests**: Verify closed-loop control of Basin level. Subject the train to variable outflow demand and verify the controller modulates the upstream valve to maintain the level setpoint.

**Tests**:
- `test_controller_proportional_response`
- `test_controller_deadband`
- `test_controller_bumpless_transfer`
- `test_closed_loop_level_stabilization`

**Done when**:
- Level controller is fully integrated into the simulation tick.
- All four unit and integration tests pass without mass balance violations.

---

### WP2.5 — Presentation & Visuals for Three-Unit Train

**Goal**: Build the 3D visual presentation scene for the connected train, showing dynamic water levels and allowing interactive control.

**Files**:
- `scenes/plant/three_unit_train.tscn`
- `scenes/process_units/reservoirs/reservoir_visual.tscn`
- `scripts/ui/controllers/asset_panel.gd`
- `tests/integration/three_unit_train/test_presentation_parity.gd`

**Steps**:
1. Create `reservoir_visual.tscn` & `three_unit_train.tscn`:
   - Build 3D visual representations of the Source Reservoir, Basin, and Receiving Reservoir.
   - Instantiate visual adapters: water surface movement linked to `level_m` snapshots, and valve rotation linked to actuator positions.
2. Update `asset_panel.gd`:
   - Enhance the UI panel to show controller parameters (PV, setpoint, mode, gain, deadband) when a unit containing a controller is clicked.
   - Provide buttons/inputs to switch controller modes and adjust setpoints via `CommandBus`.
3. Create `test_presentation_parity.gd`:
   - Assert that driving the simulation in visual mode (via `SimulationHost` and visual scenes) produces identical numerical results to running the same sequence in headless mode.

**Tests**:
- `test_presentation_parity_run`

**Done when**:
- Visual scene runs at 1x and 60x with moving water surfaces.
- Headless vs visual parity test passes.

---

### WP2.6 — Phase 2 Verification & Soak Suite

**Goal**: Consolidate Phase 2 verification checks into an automated test suite verifying flow propagation and level control under continuous operations.

**Files**:
- `tests/integration/three_unit_train/test_three_unit_verification.gd`

**Steps**:
1. Write integration checks:
   - **Continuous Soak**: Run the 3-unit train at 60x for 100,000 ticks under fluctuating demand. Verify zero mass-balance errors (within tolerance) and no negative volume occurrences.
   - **Starvation & Spill**: Verify that closed-loop controls handle boundary conditions (fully depleting source reservoir, fully overflowing basin) safely, raising alarms and routing spills correctly.
   - **Command Replay**: Assert that a sequence of recorded controller mode/setpoint commands yields identical state trajectories when replayed.

**Tests**:
- `test_continuous_soak_100k_ticks`
- `test_boundary_starvation_and_spill`
- `test_deterministic_command_replay`

**Done when**:
- Soak tests pass successfully in headless CI.
- Final Phase 2 exit condition (changes propagate cleanly without creating/destroying water) is met.
