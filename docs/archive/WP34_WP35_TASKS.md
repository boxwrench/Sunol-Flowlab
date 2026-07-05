# Next Tasks — WP3.4 and WP3.5 (implementation agent briefs)

Source of truth: `docs/PHASE3_IMPLEMENTATION_PLAN.md` §3–§4, §8 Execution Protocol.
Per §8, the per-WP review pause is suspended for Phase 3; WP3.4→WP3.5 run sequentially
without a review between them, **provided all gates stay green**. Next batch audit is at WP3.8.

---

## PRECONDITION — clears the WP3.3 batch gate (do this first, once)

WP3.4 may not begin until the WP3.3 batch gate is green. Reviewer already confirmed commit
`3183b92` ("WP3.3: Repair test_basin_availability.gd inline topologies") is contract-valid and
correctly scoped. Two items remain before WP3.4:

1. **Clean the working tree.** A stale `.git/index.lock` and a large out-of-scope uncommitted
   diff (~25 files, gutting tests/docs/schema, and truncating `test_basin_availability.gd`)
   are present. On Windows:
   ```
   del ".git\index.lock"
   git checkout -- .
   git status --short     # MUST be empty
   git diff --check       # MUST be empty
   ```
   The discarded diff is preserved at `WP33_quarantine_uncommitted.patch` if any of it turns
   out to be wanted — inspect on a scratch branch before relying on the discard.

2. **Run Godot and paste the real summaries** (config validation already passes 16/16):
   ```
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/domain -ginclude_subdirs -gexit
   #   REQUIRE: Scripts 1 / Tests 5 / Passing 5 / Failing 0
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
   #   REQUIRE: Scripts 26 / Tests 74 / Passing 74 / Failing 0, no parse errors, no skips
   ```

Only after both are green and the reviewer states the WP3.3 gate is ACCEPTED may WP3.4 start.

---

## TASK 1 — WP3.4: Applied Channel Config + Level Alarm

[ROLE]
You are the implementation agent for Sunol FlowLab. Work from the repository's actual code and
`docs/PHASE3_IMPLEMENTATION_PLAN.md`, not prior summaries. Follow AGENTS.md exactly.

[REQUIRED READING — BEFORE EDITING]
1. AGENTS.md
2. docs/PHASE3_IMPLEMENTATION_PLAN.md §4 "WP3.4 — Applied Channel Config + Level Alarm" and §5 Config & Schema
3. docs/SIMULATION_RULES.md — Flow Resolution/Proration, Determinism & Edge Rules, Basin Availability Semantics
4. docs/PROCESS_UNIT_CONTRACTS.md — StorageUnit contract, alarm semantics
5. config/schema/topology.schema.json and config/schema/ (alarms schema)
6. config/plants/phase3_headworks/topology.json (current placeholder for applied channel)
7. scripts/configuration/plant_validator.gd, scripts/configuration/plant_factory.gd
8. scripts/simulation/domain/storage_unit.gd, scripts/simulation/domain/flow_port.gd
9. Existing tests/integration/phase3_headworks/ for the established test pattern

[STRICT SCOPE]
Configuration + integration tests only. No scene files, visual adapters, or `.tscn` (those are
WP3.8). Do not modify review-verdict documents. Do not start WP3.5 until WP3.4 is committed and
its tests are green. Domain classes stay RefCounted with no UI/scene/CommandBus/EventBus/signal
dependency.

[GOAL]
Replace the applied-channel placeholder sink with a full `StorageUnit`. Wire it as the single
downstream collector for all five basin OUTLET links. Add high/low level alarms.

[REQUIRED WORK]
1. `config/plants/phase3_headworks/topology.json` (update):
   - Add `APPLIED_CHANNEL_01` as a `StorageUnit` with `spill_destination_id` = the spill
     boundary, and the full StorageUnit field set (maximum_volume_m3, surface_area_m2,
     bottom_elevation_m, high_level_m, spill_level_m, min_operating_level_m). No unsupported
     fields on ports (schema `additionalProperties:false` — ports carry only `port_id`,
     `port_type`).
   - Give `APPLIED_CHANNEL_01` **five separate INLET ports**, one per basin (FlowPort stores a
     single `connected_link`; do not share a port across links).
   - Five separate `FlowLink`s from `BASIN_01`…`BASIN_05` OUTLET ports into those five INLET
     ports. Every link includes `max_flow_m3s`, `source_port_id`, `destination_port_id`.
   - One OUTLET link from `APPLIED_CHANNEL_01` to a filter-feed `ExternalBoundary` sink
     (`boundary_type` from the canonical enum — e.g. `TREATED_DEMAND`; confirm against schema).
     This sink is a placeholder until the filter phase.
   - Remove the old applied-channel placeholder sink so no orphan boundary remains.
2. `config/plants/phase3_headworks/alarms.json`:
   - `APPLIED_CHANNEL_HIGH_LEVEL`: fires when `level_m >= high_level_m` (filter-starvation risk).
   - `APPLIED_CHANNEL_LOW_LEVEL`: fires when `level_m <= min_operating_level_m` (basin starvation).
   - Match the existing alarms schema exactly.
3. `tests/integration/phase3_headworks/test_applied_channel.gd`:
   - `test_applied_channel_receives_all_basin_flow`: open all five basins, run the solver, assert
     `APPLIED_CHANNEL_01.inflow_m3s ≈ sum of the five basin outflows` within EPSILON.
   - `test_applied_channel_high_level_alarm`: drive level above `high_level_m`, assert the high
     alarm fires within one tick.
   - `test_applied_channel_mass_conservation_1k_ticks`: 1000 ticks, mass-balance ledger within
     tolerance (absolute-error check, matching the corrected mass-balance assertion pattern).
   - Use the production PlantFactory and production domain classes. Do not recreate solver,
     tick, or balance behavior in the test.

[VERIFICATION — run and paste exact output]
1. `bash tools/ci/validate_configs.sh`  → exit 0; all phase3_headworks configs `ok`.
2. `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/phase3_headworks -ginclude_subdirs -gexit`
   → the three WP3.4 tests passing, 0 failing.
3. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
   → 0 failing, no parse errors, no skipped scripts. Paste Scripts/Tests/Passing/Failing counts.
4. `git diff --check` and `git status --short` → both clean.

[HANDOFF]
Commit with a message beginning `WP3.4:`. Report the exact runner summaries, validate_configs
result, changed files, and anything not done. Update CHANGELOG.md with the WP3.4 entry. Leave a
clean working tree. Do not begin WP3.5 until WP3.4 tests are green and committed.

---

## TASK 2 — WP3.5: Level Controllers for Applied-Channel Regulation

[ROLE]
Same as above. Begins only after WP3.4 is committed with green tests.

[REQUIRED READING — BEFORE EDITING]
1. docs/PHASE3_IMPLEMENTATION_PLAN.md §4 "WP3.5 — Level Controllers for Applied-Channel Regulation"
2. scripts/simulation/automation/level_controller.gd (existing class — do NOT subclass or fork it)
3. scripts/configuration/plant_factory.gd — existing LevelController loading path (added WP2.4)
4. config/plants/phase3_headworks/controllers.json pattern from phase2_three_unit/controllers.json
5. docs/CONTROL_LOGIC.md — P-control, deadband, AUTO/MANUAL semantics
6. docs/SIMULATION_RULES.md — Flow proration (redistribution on basin loss)

[STRICT SCOPE]
Configuration + integration tests only. **No new `SimController` subclass** — only
`LevelController` config instances. No factory changes unless the existing multi-instance
loading path is proven insufficient (confirm first; if a change is truly required, keep it
minimal and flag it prominently in the handoff). No scene/UI work.

[GOAL]
Configure five `LevelController` instances (one per basin inlet gate) that all regulate
`APPLIED_CHANNEL_01` level, so FlowSolver proration redistributes demand automatically when a
basin drops out.

[REQUIRED WORK]
1. `config/plants/phase3_headworks/controllers.json` — five `LevelController` entries:
   - Each: `type = "LevelController"`, `pv_unit_id = "APPLIED_CHANNEL_01"`,
     `pv_property = "level_m"`, `target_actuator_id = "<basin_N_inlet_gate>"` (the gate from
     `DIST_BOX_01` to basin N), and the SAME `gain`, `deadband_m`, `min_output = 0.0`,
     `max_output = 1.0` across all five.
   - Confirm the existing PlantFactory path loads multiple LevelController instances with no
     new factory code. State the confirmation in the handoff.
2. `tests/integration/phase3_headworks/test_headworks_controller.gd`:
   - `test_five_controllers_stabilize_applied_channel_level`: 1000 ticks, all five in AUTO,
     assert `|APPLIED_CHANNEL_01.level_m - setpoint| <= deadband_m` after settling.
   - `test_controller_redistribution_on_basin_loss`: take one basin out of service mid-run
     (disabling its inlet-gate link via SetBasinServiceCommand), assert the remaining four
     controllers hold level within ±10% of setpoint within 100 ticks. This proves proration
     handles redistribution — the disabled gate leaves the proration set automatically.

[VERIFICATION — run and paste exact output]
1. `bash tools/ci/validate_configs.sh` → exit 0 (controllers.json valid).
2. `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/phase3_headworks -ginclude_subdirs -gexit`
   → both WP3.5 tests passing, plus the WP3.4 tests still green.
3. Full suite → 0 failing, no parse errors, no skips. Paste counts.
4. `git diff --check` and `git status --short` → clean.

[HANDOFF]
Commit with a message beginning `WP3.5:`. Confirm no new controller subclass was created (only
config instances). Report runner summaries, validate_configs result, changed files. Update
CHANGELOG.md. Leave a clean tree. WP3.6 (schema sync) is next per the plan, but stop here for
the orchestrator unless instructed to continue.
