# Building a Plant Simulator in Sunol FlowLab

A practical, end-to-end guide to how the Sunol FlowLab simulation engine is built and how to
extend it. This guide **assembles and sequences** the existing reference docs
(`REPOSITORY_ARCHITECTURE.md`, `PROCESS_UNIT_CONTRACTS.md`, `SIMULATION_RULES.md`,
`CONFIGURATION_REFERENCE.md`, `CONTROL_LOGIC.md`) into a build-oriented tutorial, and fills the
gaps those docs leave. Where this guide and a reference doc disagree, treat the **committed code**
as authoritative and file an issue.

> Status: draft. The domain model, config contract, and verification machinery described here are
> stable. The control-law subsection (Part 3, controllers) is the one area under active revision
> in WP3.5 — treat `docs/CONTROL_LOGIC.md` as the live authority for control specifics.

---

## 0. The mental model in one paragraph

A *plant* is a directed acyclic graph (DAG) of **storage nodes** connected by **flow links**.
Every wet node — reservoir, basin, channel, manifold, junction — is a `StorageUnit`. The outside
world (raw-water sources, treated-water demand, drains, spills) is an `ExternalBoundary`. Each
tick, a deterministic two-pass solver walks the DAG, decides how much water each link carries
(prorating when capacity is short), updates every storage volume, evaluates controllers and
alarms, and validates a mass-balance ledger. Everything the simulation does is driven by JSON
config validated against schemas and assembled by a factory into plain `RefCounted` domain
objects with no UI, scene, or engine-signal dependencies.

---

## Part 1 — The domain model

### 1.1 Everything wet is a `StorageUnit`
Reservoirs, basins, channels, manifolds, and even small pass-through junctions are all modeled as
`StorageUnit` (`scripts/simulation/domain/storage_unit.gd`). A junction is simply a `StorageUnit`
with a small `surface_area_m2` / `maximum_volume_m3`; there is no separate `JunctionUnit` class
(the abstract "JunctionUnit" in `PROCESS_UNIT_CONTRACTS.md` is realized as `StorageUnit`).

Core state: `volume_m3`, `level_m` (= volume / surface_area above bottom), `inflow_m3s`,
`outflow_m3s`, `drain_flow_m3s`. Geometry fields (`maximum_volume_m3`, `surface_area_m2`,
`bottom_elevation_m`, `high_level_m`, `spill_level_m`, `min_operating_level_m`) are validated for
mutual consistency (e.g. `spill_level_m >= high_level_m`, `maximum_volume_m3 ≈ spill_level_m ×
surface_area_m2`).

Two withdrawal rules matter (`SIMULATION_RULES.md`, Edge Rule 3):
- **OUTLET** ports can only draw water **above** `min_operating_level_m` (a low-low cutoff).
- **DRAIN** ports can draw down to zero.

### 1.2 The outside world is an `ExternalBoundary`
Sources and sinks are `ExternalBoundary` units, each tagged with a `boundary_type` drawn from a
fixed, mutually-exclusive set of mass-balance ledger categories (INV-1):
`SOURCE_INFLOW`, `TREATED_DEMAND`, `PROCESS_WASTE`, `DRAIN`, `SPILL`. An optional
`flow_limit_m3s` caps the boundary's total flow (negative/absent = unlimited); the solver prorates
to fit. These categories are **labels the mass-balance ledger sums by** — no hydraulic logic
branches on them (this is what makes the engine portable; see the appendix).

### 1.3 `FlowPort` and `FlowLink`
A `FlowPort` (`flow_port.gd`) is an attachment point on a unit with a `port_id` and a `port_type`
of `INLET`, `OUTLET`, or `DRAIN`. **Critical invariant: each `FlowPort` stores exactly one
`connected_link`.** Wiring two links to one port silently overwrites the first — always give each
link its own port.

A `FlowLink` (`flow_link.gd`) connects one source port to one destination port and carries
`max_flow_m3s`. Its `flow_mode` is `RESTRICTED` (flow = `max_flow_m3s` × actuator opening) by
default. `COMMANDED` is unimplemented — it warns once and falls back to RESTRICTED at full open;
any unknown mode warns once and falls back to RESTRICTED at current
opening. If a link names an `actuator_id`, that valve modulates its flow.

### 1.4 The two-pass flow solver
Flow is resolved by `FlowSolver` (`scripts/simulation/hydraulics/flow_solver.gd`) over the
`topological_units_list` (see `SIMULATION_RULES.md`, "Flow Resolution and Proration"):
1. **Pass 1 (sinks → sources):** each link computes its *requested* flow.
2. **Pass 2 (sources → sinks):** available supply is *granted*, prorating proportionally when
   requests exceed capacity or a boundary's `flow_limit_m3s`.
3. **Final sweep:** actual flows applied, storage volumes integrated.

Flow-splitting across parallel trains is *nothing but* this proration — there is no second
splitter implementation. To bias a split, set the per-branch `max_flow_m3s` (or valve opening).

### 1.5 The topology is a static DAG
The unit graph is acyclic and **fixed for the life of a run**. Taking a unit out of service
(`in_service = false`) disables its INLET/OUTLET links but does **not** remove it from
`topological_units_list` — the DAG ordering is invariant under availability changes (a property
the invariant tests assert). DRAIN links stay enabled even when a unit is out of service.

---

## Part 2 — The config → schema → factory contract

### 2.1 The five config files
A plant lives in `config/plants/<plant_id>/` (`CONFIGURATION_REFERENCE.md`):

| File | Required | Purpose |
|------|----------|---------|
| `plant.json` | yes | Plant metadata + `simulation_settings` (e.g. `default_dt_s`) |
| `topology.json` | yes | Units, ports, actuators, links — the DAG |
| `initial_conditions.json` | yes | `unit_states`, `actuator_states`, optional `controller_states` at t=0 |
| `controllers.json` | no | Controller instances |
| `alarms.json` | no | Alarm definitions |

Each file references its schema via `$schema` (e.g. `"../../schema/topology.schema.json"`).

### 2.2 Two validation layers
1. **JSON Schema** (`config/schema/*.schema.json`), enforced in CI by
   `tools/ci/validate_configs.sh`. Schemas are `additionalProperties: false` — an unknown/misspelled
   field is a hard rejection. The CI script auto-discovers `config/plants/*/*.json` and maps each
   file by basename to `<name>.schema.json`; it requires `check-jsonschema` and guards for its
   absence.
2. **`PlantValidator`** (`plant_validator.gd`), enforced at load. It checks semantics the schema
   can't: unique unit/port IDs, dangling references (`spill_destination_id`, `target_actuator_id`,
   `pv_unit_id` must resolve), DAG acyclicity, geometry consistency, `in_service` boolean typing,
   and a simulation-resolution warning (`max_flow_m3s × dt > 0.2 × target storage`).

Always call `PlantValidator.validate_config(...)` and assert zero errors before building — this is
the guardrail that stops malformed input from silently producing a broken plant.

### 2.3 `ConfigLoader` and the canonical `PlantFactory` build order
`ConfigLoader.load_plant_config(plant_id)` returns a dict with keys `success`, `errors`,
`warnings`, `plant_data`, `topology_data`, `initial_conditions_data`, `controllers_data`,
`alarms_data`. Missing optional files yield empty dicts (not stubs), which the factory tolerates.

`PlantFactory.build_plant(context, topology_data, initial_conditions_data, controllers_data)`
constructs the plant in this order (`plant_factory.gd`):
1. **Units** — instantiate each `StorageUnit` / `ExternalBoundary`, call `initialize(config)`.
2. **Ports** — one `FlowPort` per `port_id`, attached to its owning unit.
3. **Actuators** — instantiate valves.
4. **Links** — instantiate each `FlowLink`, resolve `source_port_id`/`destination_port_id` and
   any `actuator_id`, and set each port's single `connected_link`.
5. **Topological sort** — Kahn's algorithm with lexicographic tie-breaking → `topological_units_list`.
   A cycle makes `build_plant` return `false`.
6. **Controllers** — instantiate from `controllers_data`, sorted by ID.
7. **Apply initial conditions** — `unit_states`/`actuator_states`/`controller_states`. Precedence
   rule: **`in_service` in initial_conditions overrides the topology default**; a controller
   `setpoint`/`control_mode` is applied only if present.

Note: **alarms are not built by the factory.** They are instantiated and registered in
application/bootstrap code (`alarm_engine.register_alarm(alarm)`), unlike units/links/controllers.

---

## Part 3 — How to add a new … (end-to-end recipes)

Each recipe lists the config you write and the code that enforces it. Field-level requirements are
summarized in the tables; the reference is always the schema + `plant_validator.gd`.

### 3.1 Add a new process unit (a `StorageUnit`)
1. In `topology.json` → `units`, add the unit. Required for a StorageUnit: `unit_id`, `type`
   (`"StorageUnit"`), `display_name`, `maximum_volume_m3`, `surface_area_m2`, `bottom_elevation_m`,
   `high_level_m`, `spill_level_m`, `min_operating_level_m`, `spill_destination_id`. Optional:
   `in_service` (default true), `ports`.
2. Define its `ports`, each with `port_id` and `port_type` (`INLET`/`OUTLET`/`DRAIN`). Give each
   link its own port (one link per port).
3. Point `spill_destination_id` at a real `ExternalBoundary` (validator requires it to resolve).
4. Add the `FlowLink`s that connect it (recipe 3.3).
5. Optionally set an initial `volume_m3` / `in_service` in `initial_conditions.json` → `unit_states`.
6. Run `validate_configs.sh` and a build test.

Enforced by: `plant_factory.gd` (units/ports), `plant_validator.gd` (geometry, unique IDs, spill
resolution), `storage_unit.gd::initialize`.

### 3.2 Add a new plant
1. Create `config/plants/<plant_id>/`.
2. Add `plant.json` (`plant_id`, `display_name`, `simulation_settings.default_dt_s`),
   `topology.json` (≥1 unit), and `initial_conditions.json` (may have empty arrays). Add
   `controllers.json` / `alarms.json` only if needed.
3. Load and build:
   ```gdscript
   var cfg := ConfigLoader.load_plant_config("<plant_id>")
   if cfg.success:
       PlantFactory.build_plant(context, cfg.topology_data,
                                cfg.initial_conditions_data, cfg.controllers_data)
   ```
4. Validate: `bash tools/ci/validate_configs.sh` (the new plant is auto-discovered).

### 3.3 Add a new link
In `topology.json` → `links`: required `link_id`, `max_flow_m3s`, `source_port_id`,
`destination_port_id`; optional `display_name`, `flow_mode` (default `RESTRICTED`), `actuator_id`,
`is_enabled` (default true). The link must preserve the DAG (a cycle fails the build) and each of
its ports must be otherwise unused.

### 3.4 Add a new controller instance
In `controllers.json` → `controllers`: `controller_id`, `type` (`"LevelController"`),
`display_name`, `target_actuator_id`, `pv_unit_id`, `pv_property` (`"level_m"`), `control_mode`
(`MANUAL`/`AUTO`), `setpoint`, `gain`, `deadband_m`, `min_output`, `max_output`. All five referenced
IDs must resolve. The factory loads multiple instances with no code change (`plant_factory.gd`).
Optionally seed `control_mode`/`setpoint` in `initial_conditions.json` → `controller_states`.

Control law (`level_controller.gd`, as of WP3.5): a velocity-form controller — in AUTO, with
`error = setpoint − pv`, when `|error| > deadband_m` it updates `output = previous_output +
gain·error` (plus proportional/derivative damping terms being added in WP3.5), clamps to
`[min_output, max_output]`, and commands the valve; inside the deadband it holds. See
`CONTROL_LOGIC.md` for the authoritative, current control specification. Note `pv_property` is
**not** checked to exist on the unit — a typo makes the controller silently no-op.

### 3.5 Add a new alarm
In `alarms.json` → `alarms`: `alarm_id`, `display_name`, `target_unit_id`, `target_property`,
`alarm_type` (`HIGH`/`LOW`), `threshold_value`, `delay_s`, `deadband` (optional `message`). HIGH
fires at `value ≥ threshold`, LOW at `value ≤ threshold`, with `deadband` hysteresis on reset and
`delay_s` persistence before activation. **Remember alarms are registered in application code**, not
built by the factory:
```gdscript
var a := ThresholdAlarm.new(); a.initialize(cfg); engine.alarm_engine.register_alarm(a)
```

---

## Part 4 — Determinism and verification

Determinism is a first-class property (`SIMULATION_RULES.md`, "Determinism Mechanics"):
- **No ad-hoc randomness.** Any stochastic behavior uses the seeded RNG owned by the context
  (`context.rng`, a `RandomNumberGenerator`). Same seed ⇒ identical run.
- **Sorted iteration.** Units, links, actuators, controllers, and alarms are iterated in
  deterministic (ID-sorted / topological) order.
- **Tick-stamped commands.** Commands carry an `apply_tick` and are applied in a stable order.

### 4.1 The mass-balance ledger
`context.mass_balance_tracker` (a `MassBalanceTracker`) is initialized with the starting total
storage and, given the current total storage, reports the ledger:
```gdscript
tracker.initialize(initial_total_volume)
var current := 0.0
for u in context.units_list:
    if u is StorageUnit: current += u.volume_m3
var report := tracker.report(current)   # report.mass_balance_error_m3, cumulative_inflow_m3, …
```
The invariant is `initial_storage + inflow − treated_demand − process_waste − drain − spill −
current_storage = error ≈ 0`. The established tolerance form used across the suite is
`abs(error) ≤ 1e-9 × max(initial_total_volume + cumulative_inflow_m3, 1.0) × sqrt(tick)`.

### 4.2 Snapshots and replay
`SnapshotService.take_snapshot(context, engine)` returns a deep-copied dict of every unit, link,
actuator, controller, alarm, and the plant totals. Deterministic-replay tests run two independently
built engines with the same seed and command sequence and assert identical state — either by
comparing `str(snap).hash()` or a stable field hash (unit vol/level, actuator pos/cmd, controller
mode/setpoint).

### 4.3 Test tiers
`REPOSITORY_ARCHITECTURE.md` §16 defines the tiers, all run headless under GUT:
- **Unit** — a single domain class.
- **Integration** — a built plant via `ConfigLoader` + `PlantFactory` (never hand-rolled).
- **Invariant** — mass conservation, no-negative-storage, DAG-unchanged-under-toggle,
  deterministic replay, run as long soaks (e.g. 100k ticks with the inflow ramped and basins
  churned via `context.rng`).

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

---

## Appendix — Porting to other utilities (wastewater, etc.)

The engine is **~95% portable**. It is a generic volume/flow/level hydraulics solver over an
arbitrary DAG; it encodes **no** assumptions about treatment, potability, chemistry, or the
headworks topology (which is only an example config). Everything works in `m³`, `m³/s`, `m`.

A port to wastewater or another utility touches exactly three things:
1. **Boundary labels.** The `boundary_type` enum (`SOURCE_INFLOW`, `TREATED_DEMAND`,
   `PROCESS_WASTE`, `DRAIN`, `SPILL`) is labels-not-logic. Rename in `topology.schema.json`,
   `external_boundary.gd`'s accepted list, and `mass_balance_tracker.gd` (e.g. `INFLUENT`,
   `EFFLUENT`, `SLUDGE`, …). No solver branch depends on the names.
2. **Ledger fields.** `mass_balance_tracker.gd` accumulates five hardcoded category buckets.
   Either rename them, or (for many streams) refactor to a dictionary keyed by `boundary_type`.
   Update the matching keys in `snapshot_service.gd`'s `plant_totals`.
3. **Display vocabulary.** Config `display_name`s and any presentation adapter labels.

No changes are required to the flow solver, storage balance, port/link topology, control system,
or tick cycle. A wastewater plant with different unit arrangements is just a different set of
config files plus those relabelings.

---

## Where the reference docs live
- Architecture & layers: `docs/REPOSITORY_ARCHITECTURE.md`
- Domain class contracts: `docs/PROCESS_UNIT_CONTRACTS.md`
- Physics, solver, determinism: `docs/SIMULATION_RULES.md`
- Control modes & loops: `docs/CONTROL_LOGIC.md`
- Config files & schemas: `docs/CONFIGURATION_REFERENCE.md`
- Adding a unit (checklist): `docs/ADDING_A_PROCESS_UNIT.md`
- Doc authority tiers: `docs/INDEX.md`
