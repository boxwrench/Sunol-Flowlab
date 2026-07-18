# Repository Architecture

Logical and modular architecture for the Sunol FlowLab drinking-water digital-twin
sandbox (Godot 4.7, GDScript).

**How to read this document.** Part I is the **binding core**: the directory layout,
architectural layers, module and tick/snapshot boundaries, dependency rules, and invariants
that code must respect. Part II is a **non-binding appendix** holding aspirational and
historical material (planned buildout, suggested patterns, original build order) — useful
context, but not a contract on today's code.

This document is the architectural spine. Where a topic has a dedicated authority document
(contracts, topology, units, testing, control, presentation), the detail lives there and this
document points to it — see the **Authority Map** (§9). On any structural conflict,
`REPOSITORY_ARCHITECTURE.md` wins per `docs/INDEX.md`; on symbol/field detail, the specialized
doc and the committed code win.

---

# Part I — Binding Core

## 1. Architectural Principles

### 1.1 Simulation First, Presentation Second

The hydraulic and automation simulation must not depend on 3D models, camera state, UI
panels, animation, particles, water meshes, or frame rate. The plant must run headless with no
3D scene loaded. The 3D layer reads simulation state and presents it; it must never change
hydraulic values directly — it sends commands through the command interface.

```text
Simulation State → Presentation Adapter → 3D Models and UI
```

### 1.2 Composition Over Inheritance

Process units are assembled from small reusable components (storage model, ports, actuators,
alarms, visual adapter) rather than deep inheritance trees. A filter reuses the same components
a basin does, adding only filter-specific behavior.

### 1.3 Data-Driven Plant Construction

Plant capacities, elevations, flow limits, setpoints, and topology live in configuration files,
not in reusable scripts. Reusable code defines behavior; configuration defines a particular
plant.

```text
Reusable Code + Plant Configuration = Running Plant Model
```

### 1.4 One Direction of Dependency

Dependencies flow inward toward the simulation core. The simulation domain must not import or
reference UI or 3D presentation classes.

```text
UI ──────────────┐
3D Presentation ──┼──> Application Services ──> Simulation Domain
Tools/Config ─────┘
```

### 1.5 Explicit Interfaces Between Modules

Modules communicate through defined interfaces and never reach into each other's internal
variables: a flow link requests water from a source port; a controller commands an actuator;
the UI sends a command through the command bus; a 3D scene reads a public snapshot.

### 1.6 Deterministic Fixed-Step Simulation

The simulation runs on a fixed timestep. The same initial state, configuration, commands, and
timestep must produce identical results. Rendering frame rate must not affect hydraulic
results. (INV-2 — Determinism.)

### 1.7 Water Conservation as a Core Invariant

Every tick must support a plant-wide mass-balance check. Floating-point tolerance is allowed;
unexplained creation or loss of water is not. (INV-1 — Water conservation.)

```text
Starting Storage + External Inflow − External Outflow − Spill − Drain = Ending Storage
```

## 2. Repository Structure

Actual top-level layout:

```text
Sunol FlowLab/
├── project.godot
├── README.md, LICENSE, CHANGELOG.md, CONTRIBUTING.md, AGENTS.md
├── addons/        # third-party Godot addons (GUT)
├── assets/        # models, materials, textures, licenses (see Appendix E)
├── config/        # plant definitions and JSON schemas
│   ├── plants/    # e.g. phase3_headworks/
│   └── schema/    # topology, controllers, alarms, plant, initial_conditions, …
├── docs/          # authority documentation (see INDEX.md)
├── scenes/        # Godot scenes (presentation/UI only)
├── scripts/       # all GDScript (see §3 for layers)
├── tests/         # GUT tests: unit/, integration/, invariants/
└── tools/         # standalone editor/dev tooling
```

`scripts/` is divided into layers:

```text
scripts/
├── simulation/     # domain core — no presentation dependencies
│   ├── domain/       # ProcessUnit, StorageUnit, ExternalBoundary, FlowLink, FlowPort, SimValve, SimController
│   ├── hydraulics/   # flow solver, storage balance
│   ├── automation/   # LevelController
│   ├── alarms/       # ThresholdAlarm, AlarmEngine
│   ├── commands/     # SimulationCommand subclasses
│   ├── events/       # domain events
│   └── core/         # engine, clock, context, snapshot service
├── application/    # bootstrap, hosting, command routing
├── configuration/  # config loading, schema validation, plant factory
├── presentation/   # 3D visual adapters (read snapshots)
├── ui/             # panels, controls (emit commands)
├── utilities/      # shared helpers (unit conversion, etc.)
└── tools/          # editor-side script tooling
```

There is no `scripts/telemetry/` or `scripts/scenarios/` layer today; trend/telemetry and
scenario frameworks are parked (see `docs/ROADMAP.md`). Their planned shape is noted in the
Appendix, not the binding core.

## 3. Architectural Layers

| Layer | Location | Responsibility | Restriction |
|-------|----------|----------------|-------------|
| Simulation Domain | `scripts/simulation/` | Plant/unit state, flow, volume, level, automation, alarm evaluation, mass-balance, commands/events | No `Node3D`, camera, UI, asset, scene, or frame-rate dependency |
| Application | `scripts/application/` | Start/stop, load config, build the plant, route commands, publish events, snapshots | Coordinates systems; contains no hydraulic equations |
| Configuration | `scripts/configuration/`, `config/` | Load and validate plant files, construct domain objects, apply initial conditions | Converts data into domain objects only |
| Presentation | `scripts/presentation/`, `scenes/` | Display units, animate valves/gates, move water surfaces, highlight alarms, camera | Reads immutable snapshots per `PRESENTATION_MAPPING.md`; never edits simulation state |
| UI | `scripts/ui/`, `scenes/ui/` | Show values/alarms/trends, accept operator input, change speed/mode/setpoints | UI actions become `SimulationCommand`s; never mutate the model directly |

The simulation domain uses plain GDScript classes / `RefCounted` objects, not Godot Nodes,
except where Godot lifecycle behavior is genuinely required.

## 4. Module Boundaries

Symbol-level interfaces (fields, methods, config keys) for `ProcessUnit`, `StorageUnit`,
`FlowLink`, `FlowPort`, `SimValve`, `SimController`, and `ThresholdAlarm` are defined and kept
reconciled with production in **`docs/PROCESS_UNIT_CONTRACTS.md`** — that document is the
authority; do not restate signatures here (it caused drift historically).

The architectural boundaries those contracts must preserve:

- **Uniform lifecycle.** Every unit extends `ProcessUnit` and implements the tick lifecycle
  (`pre_tick` / `solve_tick` / `post_tick`, `get_snapshot`, `validate`), so the engine can
  drive any unit uniformly.
- **Ports decouple units.** Units connect only through typed `FlowPort`s
  (`INLET`/`OUTLET`/`DRAIN`, plus boundary ports); neither unit knows the other's internals.
- **Controllers command actuators, not state.** A controller reads a process variable and
  produces an actuator command; it must never write a stored volume.
- **Alarm evaluation is centralized.** `AlarmEngine` decides alarm state over `ThresholdAlarm`
  instances; UI and presentation only display it.
- **Junctions are storage.** Manifolds, distribution boxes, and headers are modeled as small
  `StorageUnit`s to keep the topology a pure DAG — there is no separate junction class.

## 5. Simulation Tick Lifecycle

The engine executes each fixed tick in this exact order. The order is **binding** because
changing it changes results; it is asserted by `tests/unit/simulation/test_tick_order.gd` and
specified authoritatively in **`docs/SIMULATION_RULES.md`**.

```text
 1. Receive queued commands
 2. Apply mode and setpoint changes
 3. Update actuator positions
 4. Evaluate controllers
 5. Resolve requested flows
 6. Apply source and destination constraints
 7. Transfer water through links
 8. Update storage volumes
 9. Calculate levels and spills
10. Update process-unit state machines
11. Evaluate alarms and interlocks
12. Record telemetry
13. Validate invariants
14. Publish simulation snapshot
```

Actuators integrate before controllers evaluate, so controller output takes effect on the next
tick (intended one-tick scan lag).

## 6. Command, Event, and Snapshot Boundaries

These three boundaries keep presentation and simulation separated and make runs deterministic
and replayable.

- **Commands request changes.** All state-changing external actions are enqueued as
  `SimulationCommand` subclasses (e.g. `SetValvePositionCommand`, `SetBasinServiceCommand`,
  `SetLevelSetpointCommand`, `SetControllerModeCommand`) and applied at a scheduled tick. This
  makes actions validatable, loggable, replayable, and identical whether they come from the UI
  or a test.
- **Events report changes.** Events communicate completed state changes; they must not be used
  to implement hydraulic calculation, which stays inside the engine.
- **Snapshots expose state.** Presentation and UI read an immutable, read-only snapshot taken
  at the end of a tick — never a live reference to a mutable domain object. Within one rendered
  update, all data-bearing elements must use the same snapshot tick; presentation may lag but
  must never lead the snapshot or become a second source of truth. Encoding and validation
  rules are defined in **`docs/PRESENTATION_MAPPING.md`**.

Scene scripts may move a water plane, rotate a valve handle, change a material, show an alarm
light, or update a label. They may **not** calculate volume or flow, apply capacity limits,
decide spills, evaluate interlocks, or determine alarm state.

## 7. Dependency Rules

**Allowed:** `simulation/core`, `simulation/hydraulics`, `simulation/automation` may depend on
`simulation/domain` and utilities. `application` may depend on simulation and configuration.
`presentation` may depend on application interfaces and snapshots. `ui` may depend on
application services, commands, snapshots, and formatters. `tests` may depend on any target.

**Forbidden:**

```text
simulation → presentation        simulation → UI
simulation → camera              simulation → asset files
simulation → specific 3D scenes  domain model → singleton UI state
process-unit model → another unit's private fields
```

## 8. Invariants

Invariant tests run across the complete plant and are a release gate (see
`tests/invariants/` and `docs/TESTING_STRATEGY.md`):

- **INV-1** — total plant water is conserved; no negative storage.
- **INV-2** — simulation replay is deterministic.
- **INV-3** — one-way dependency: presentation/UI → simulation, never the reverse.
- No flow through closed valves; no flow exceeds link capacity.
- No out-of-service unit accepts normal flow unless explicitly allowed.
- No NaN or infinite values; every active connection has valid ports; every unit has a stable ID.

## 9. Authority Map

This document is the architectural spine. Topic detail is owned by these documents (all under
`docs/`, ordered by `INDEX.md`):

| Topic | Authority document |
|-------|--------------------|
| Unit interfaces (fields, methods, config keys) | `PROCESS_UNIT_CONTRACTS.md` |
| Tick order, mass-balance, determinism mechanics | `SIMULATION_RULES.md` |
| Connectivity, ports, plant configuration | `PLANT_TOPOLOGY.md` |
| Plant JSON configuration fields | `CONFIGURATION_REFERENCE.md` |
| Control modes, controller order, splitting | `CONTROL_LOGIC.md` |
| Snapshot-to-visual encoding and validation | `PRESENTATION_MAPPING.md` |
| SI internal units and display formatting | `INTERNAL_UNITS.md` |
| Identifier/tag format | `TAG_NAMING.md` |
| Test categories and expectations | `TESTING_STRATEGY.md` |
| Adding a new process unit | `ADDING_A_PROCESS_UNIT.md` |
| Architecture Decision Records | `DECISIONS/` (ADR 0001–0006) |
| Agent behavior rules; PR/commit rules | `AGENTS.md`, `CONTRIBUTING.md` |

## 10. Naming Conventions

- **Files:** `snake_case` (`storage_unit.gd`).
- **Classes:** `PascalCase` (`StorageUnit`).
- **Variables/functions:** `snake_case`, with SI-unit suffixes on quantities
  (`maximum_flow_m3s`, `level_m`).
- **Constants:** `UPPER_SNAKE_CASE`.
- **IDs/tags:** uppercase structured IDs independent of scene-tree paths (`SED_BASIN_01`);
  see `TAG_NAMING.md`.

## 11. Core Rule Summary

```text
Simulation owns truth.        Snapshots expose state.
Configuration defines plant.  Presentation shows state.
Commands request changes.     UI sends commands.
Events report changes.        Tests protect behavior.
```

The architecture is working when: a simulation runs without loading the 3D plant; a unit can be
tested independently; a unit's visual can be replaced without changing hydraulic code; a new
basin or filter can be added through configuration; repeated units reuse one model; UI actions
use commands rather than mutating fields; all values use one internal unit system; plant-wide
mass balance can be checked every tick; configuration errors are reported before start; a run
can be deterministically replayed; and an agent can identify the correct layer and folder for a
change.

---

# Part II — Appendix (Non-Binding)

Everything below is **non-binding** — aspirational patterns, planned buildout, and historical
sequencing kept for context. It is not a contract on current code, and it ranks below Part I and
every authority document. Where it describes something not yet built, treat it as intent, not
fact.

## A. Planned Full Buildout

The current plant (`phase3_headworks`) covers reservoirs through sedimentation. The completed
proof-of-concept train (per `docs/PROJECT_SCOPE.md`) also adds twelve filters, a clearwell, two
CT basins, and a treated-water reservoir. As those are built, each is expected to follow the
package pattern in §B and reuse one model per repeated unit type (one filter model × 12, etc.),
with new scenes under `scenes/process_units/` and configuration under `config/plants/`. Parked
layers — telemetry/trends (`scripts/telemetry/`), scenario frameworks (`scripts/scenarios/`),
and their config — would be added only when a milestone requires them (see the ROADMAP
"triggered later" table).

## B. Reusable Process-Unit Package Pattern

Each process unit is intended to keep its model, visual scene, configuration, and tests
separate but clearly associated, for example:

```text
scenes/process_units/<family>/   <unit>.tscn, <unit>_visual.gd, meshes/, materials/
scripts/simulation/domain/       <unit>.gd (or a shared StorageUnit + config)
config/plants/<plant>/           topology + parameters
tests/unit/…                     test_<unit>.gd
```

See `docs/ADDING_A_PROCESS_UNIT.md` for the current, authoritative procedure.

## C. Suggested Scene Composition

An application scene separates simulation hosting from 3D presentation (e.g. a `SimulationHost`
owning the engine lifecycle, a `PlantWorld` owning only 3D scenes, plus camera, UI, and debug
overlays). A process-unit visual scene composes static geometry, a water surface, valve/gate
visuals, flow indicators, an alarm indicator, a selection collider, and a visual adapter, and
receives a `unit_id` (`@export var unit_id: StringName`) that links it to the simulation model.

## D. Autoload Guidance

Use autoloads sparingly. The simulation engine should be instantiated and owned by the
application scene (not an autoload) so tests can create isolated engines. Genuinely global
concerns (app state, event bus, command bus, config registry, unit converter) are the
candidates; do not make every subsystem an autoload.

## E. Asset Architecture

Separate generic assets (`assets/models/generic_equipment/`) from plant-specific assets
(`assets/models/process_units/`). Every third-party asset source has a matching license record
under `assets/licenses/` with a manifest (name, source, creator, license, modified, location).
Simulation IDs must not depend on mesh names — a placeholder cube and a finished model must be
interchangeable without changing simulation code.

## F. Historical — Initial Implementation Order

The project was built in roughly this sequence: (1) repository foundation and engine shell;
(2) core domain classes; (3) a first source→basin→receiving hydraulic slice; (4) presentation
adapters; (5) data-driven construction (config loader, plant factory, schema validation);
(6) expansion of the process train. This is delivered through Phase 3 / WP4.1 — see
`docs/ROADMAP.md` for authoritative status. Retained only as historical context.
