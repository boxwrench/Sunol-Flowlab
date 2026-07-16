# Repository Architecture

## Drinking Water Digital Twin Sandbox

This document defines the logical and modular repository architecture for the Godot-based drinking water digital twin sandbox.

The architecture is designed to support:

- Incremental development.
- Reusable process-unit modules.
- Clear separation between simulation logic and 3D presentation.
- Deterministic hydraulic calculations.
- Editable automation logic.
- Automated testing.
- Data-driven plant configuration.
- Safe and efficient development with Claude Code and Codex.
- Future expansion into water quality, training scenarios, PLC logic, and external integrations.

---

# 1. Architectural Principles

## 1.1 Simulation First, Presentation Second

The hydraulic and automation simulation must not depend on:

- 3D models.
- Camera state.
- UI panels.
- Animation state.
- Particle systems.
- Visual water meshes.
- Frame rate.

The plant must be capable of running as a headless simulation with no 3D scene loaded.

The 3D layer reads simulation state and presents it visually.

```text
Simulation State
      │
      ▼
Presentation Adapter
      │
      ▼
3D Models and UI
```

The presentation layer must never directly change hydraulic values. It sends commands through the simulation command interface.

---

## 1.2 Composition Over Inheritance

Process units should be assembled from small reusable components instead of deep inheritance trees.

For example, a sedimentation basin should not contain all behavior in one large script.

It should be composed from:

```text
Sedimentation Basin
├── Storage Model
├── Inlet Flow Port
├── Outlet Flow Port
├── Inlet Gate
├── Outlet Gate
├── Drain Valve
├── Spillway
├── Alarm Set
├── Operating State Machine
└── Visual Adapter
```

A filter can reuse many of the same components while adding filter-specific behavior.

---

## 1.3 Data-Driven Plant Construction

Plant capacities, elevations, flow limits, setpoints, and topology must be stored in configuration files or Godot Resources.

Do not hard-code plant-specific values into reusable scripts.

Reusable code defines behavior.

Configuration defines a particular plant.

```text
Reusable Code + Plant Configuration = Running Plant Model
```

---

## 1.4 One Direction of Dependency

Dependencies should flow inward toward the simulation core.

```text
UI ───────────────┐
                  │
3D Presentation ──┼──> Application Services ──> Simulation Domain
                  │
Scenario Tools ───┘
```

The simulation domain must not import or reference UI or 3D presentation classes.

---

## 1.5 Explicit Interfaces Between Modules

Modules communicate through defined interfaces and events.

They must not reach into each other's internal variables.

Examples:

- A flow link requests water from a source port.
- A controller issues a command to an actuator.
- An alarm reads an instrument value.
- A 3D scene reads a public simulation snapshot.
- The UI sends a command through a command bus.

---

## 1.6 Deterministic Fixed-Step Simulation

The simulation runs using a fixed timestep.

The same:

- Initial state.
- Configuration.
- User commands.
- Simulation timestep.

must produce the same results.

Rendering frame rate must not affect hydraulic results.

---

## 1.7 Water Conservation as a Core Invariant

Every simulation tick must support a plant-wide mass-balance check.

```text
Starting Storage
+ External Inflow
- External Outflow
- Spill
- Drain
= Ending Storage
```

Floating-point tolerance is allowed, but unexplained creation or loss of water is not.

---

# 2. Repository Top-Level Structure

```text
water-digital-twin/
├── project.godot
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── AGENTS.md
├── .gitignore
├── .editorconfig
├── .gitattributes
│
├── addons/
├── assets/
├── config/
├── data/
├── docs/
├── scenes/
├── scripts/
├── tests/
├── tools/
└── builds/
```

---

# 3. Recommended Complete Folder Structure

```text
water-digital-twin/
│
├── project.godot
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── AGENTS.md
├── .gitignore
├── .editorconfig
├── .gitattributes
│
├── addons/
│   ├── gut/
│   └── third_party/
│
├── assets/
│   ├── models/
│   │   ├── environment/
│   │   ├── generic_equipment/
│   │   ├── process_units/
│   │   ├── structures/
│   │   └── vehicles/
│   │
│   ├── materials/
│   │   ├── concrete/
│   │   ├── metal/
│   │   ├── terrain/
│   │   └── water/
│   │
│   ├── textures/
│   ├── icons/
│   ├── fonts/
│   ├── audio/
│   └── licenses/
│
├── config/
│   ├── plants/
│   │   └── default_surface_water_plant/
│   │       ├── plant.json
│   │       ├── topology.json
│   │       ├── initial_conditions.json
│   │       ├── alarms.json
│   │       ├── controllers.json
│   │       ├── process_units/
│   │       └── scenarios/
│   │
│   ├── schemas/
│   │   ├── plant.schema.json
│   │   ├── topology.schema.json
│   │   ├── process_unit.schema.json
│   │   ├── alarm.schema.json
│   │   └── controller.schema.json
│   │
│   └── defaults/
│       ├── unit_defaults.json
│       ├── alarm_defaults.json
│       └── controller_defaults.json
│
├── data/
│   ├── runtime/
│   ├── saves/
│   ├── snapshots/
│   ├── trends/
│   └── exports/
│
├── docs/
│   ├── PROJECT_SCOPE.md
│   ├── REPOSITORY_ARCHITECTURE.md
│   ├── PLANT_TOPOLOGY.md
│   ├── SIMULATION_RULES.md
│   ├── CONTROL_LOGIC.md
│   ├── PROCESS_UNIT_CONTRACTS.md
│   ├── TAG_NAMING.md
│   ├── INTERNAL_UNITS.md
│   ├── TESTING_STRATEGY.md
│   ├── ASSET_PIPELINE.md
│   ├── AI_DEVELOPMENT_RULES.md
│   ├── DECISIONS/
│   └── diagrams/
│
├── scenes/
│   ├── application/
│   │   ├── main.tscn
│   │   ├── bootstrap.tscn
│   │   └── loading_screen.tscn
│   │
│   ├── plant/
│   │   ├── complete_plant.tscn
│   │   ├── headworks_area.tscn
│   │   ├── sedimentation_area.tscn
│   │   ├── filtration_area.tscn
│   │   └── finished_water_area.tscn
│   │
│   ├── process_units/
│   │   ├── reservoirs/
│   │   ├── manifolds/
│   │   ├── flash_mix/
│   │   ├── distribution_box/
│   │   ├── sedimentation/
│   │   ├── applied_channel/
│   │   ├── filters/
│   │   ├── clearwell/
│   │   ├── contact_basins/
│   │   └── treated_storage/
│   │
│   ├── components/
│   │   ├── actuators/
│   │   ├── instruments/
│   │   ├── water_surfaces/
│   │   ├── flow_indicators/
│   │   ├── alarms/
│   │   └── selection/
│   │
│   ├── cameras/
│   ├── environment/
│   ├── ui/
│   │   ├── shell/
│   │   ├── asset_panel/
│   │   ├── alarms/
│   │   ├── controls/
│   │   ├── trends/
│   │   ├── overlays/
│   │   └── debug/
│   │
│   └── debug/
│
├── scripts/
│   ├── application/
│   │   ├── app_bootstrap.gd
│   │   ├── application_state.gd
│   │   ├── command_bus.gd
│   │   ├── event_bus.gd
│   │   ├── save_service.gd
│   │   └── snapshot_service.gd
│   │
│   ├── simulation/
│   │   ├── core/
│   │   │   ├── simulation_engine.gd
│   │   │   ├── simulation_clock.gd
│   │   │   ├── simulation_context.gd
│   │   │   ├── simulation_snapshot.gd
│   │   │   ├── mass_balance_tracker.gd
│   │   │   └── simulation_result.gd
│   │   │
│   │   ├── domain/
│   │   │   ├── plant_model.gd
│   │   │   ├── process_unit.gd
│   │   │   ├── storage_unit.gd
│   │   │   ├── junction_unit.gd
│   │   │   ├── flow_link.gd
│   │   │   ├── flow_port.gd
│   │   │   ├── actuator.gd
│   │   │   ├── instrument.gd
│   │   │   ├── alarm.gd
│   │   │   └── controller.gd
│   │   │
│   │   ├── hydraulics/
│   │   │   ├── storage_balance.gd
│   │   │   ├── commanded_flow_model.gd
│   │   │   ├── restricted_flow_model.gd
│   │   │   ├── gravity_flow_model.gd
│   │   │   ├── splitter_solver.gd
│   │   │   ├── capacity_limiter.gd
│   │   │   └── hydraulic_constraints.gd
│   │   │
│   │   ├── automation/
│   │   │   ├── control_mode.gd
│   │   │   ├── level_controller.gd
│   │   │   ├── flow_controller.gd
│   │   │   ├── split_controller.gd
│   │   │   ├── lead_lag_controller.gd
│   │   │   ├── interlock.gd
│   │   │   ├── permissive.gd
│   │   │   └── sequence_controller.gd
│   │   │
│   │   ├── state_machines/
│   │   │   ├── unit_state_machine.gd
│   │   │   ├── basin_state_machine.gd
│   │   │   ├── filter_state_machine.gd
│   │   │   └── reservoir_state_machine.gd
│   │   │
│   │   ├── process_units/
│   │   │   ├── source_reservoir_model.gd
│   │   │   ├── inlet_manifold_model.gd
│   │   │   ├── flash_mix_model.gd
│   │   │   ├── distribution_box_model.gd
│   │   │   ├── sedimentation_basin_model.gd
│   │   │   ├── applied_channel_model.gd
│   │   │   ├── filter_model.gd
│   │   │   ├── clearwell_model.gd
│   │   │   ├── contact_basin_model.gd
│   │   │   └── treated_reservoir_model.gd
│   │   │
│   │   ├── alarms/
│   │   │   ├── alarm_engine.gd
│   │   │   ├── threshold_alarm.gd
│   │   │   ├── state_alarm.gd
│   │   │   ├── delayed_alarm.gd
│   │   │   └── alarm_record.gd
│   │   │
│   │   ├── commands/
│   │   │   ├── simulation_command.gd
│   │   │   ├── set_valve_position_command.gd
│   │   │   ├── set_flow_setpoint_command.gd
│   │   │   ├── set_control_mode_command.gd
│   │   │   ├── set_basin_service_command.gd
│   │   │   ├── set_unit_service_command.gd
│   │   │   └── acknowledge_alarm_command.gd
│   │   │
│   │   ├── events/
│   │   │   ├── simulation_event.gd
│   │   │   ├── alarm_activated_event.gd
│   │   │   ├── alarm_cleared_event.gd
│   │   │   ├── unit_state_changed_event.gd
│   │   │   └── spill_started_event.gd
│   │   │
│   │   └── validation/
│   │       ├── plant_validator.gd
│   │       ├── topology_validator.gd
│   │       ├── configuration_validator.gd
│   │       └── invariant_validator.gd
│   │
│   ├── configuration/
│   │   ├── config_loader.gd
│   │   ├── config_registry.gd
│   │   ├── plant_factory.gd
│   │   ├── resource_factory.gd
│   │   └── schema_validator.gd
│   │
│   ├── presentation/
│   │   ├── adapters/
│   │   │   ├── process_unit_visual_adapter.gd
│   │   │   ├── storage_visual_adapter.gd
│   │   │   ├── valve_visual_adapter.gd
│   │   │   ├── water_surface_adapter.gd
│   │   │   └── alarm_visual_adapter.gd
│   │   │
│   │   ├── camera/
│   │   ├── selection/
│   │   ├── animation/
│   │   └── overlays/
│   │
│   ├── ui/
│   │   ├── view_models/
│   │   ├── controllers/
│   │   ├── formatters/
│   │   └── widgets/
│   │
│   ├── telemetry/
│   │   ├── trend_buffer.gd
│   │   ├── tag_registry.gd
│   │   ├── telemetry_snapshot.gd
│   │   └── csv_exporter.gd
│   │
│   ├── scenarios/
│   │   ├── scenario.gd
│   │   ├── scenario_runner.gd
│   │   ├── scheduled_action.gd
│   │   └── scenario_condition.gd
│   │
│   └── utilities/
│       ├── unit_conversion.gd
│       ├── math_utils.gd
│       ├── id_utils.gd
│       ├── time_utils.gd
│       └── result.gd
│
├── tests/
│   ├── unit/
│   │   ├── simulation/
│   │   ├── hydraulics/
│   │   ├── automation/
│   │   ├── alarms/
│   │   ├── configuration/
│   │   └── utilities/
│   │
│   ├── integration/
│   │   ├── three_unit_train/
│   │   ├── sedimentation_train/
│   │   ├── filtration_train/
│   │   └── complete_plant/
│   │
│   ├── invariants/
│   │   ├── test_mass_conservation.gd
│   │   ├── test_no_negative_storage.gd
│   │   ├── test_capacity_limits.gd
│   │   └── test_deterministic_replay.gd
│   │
│   ├── scenarios/
│   ├── fixtures/
│   └── helpers/
│
├── tools/
│   ├── config_editor/
│   ├── topology_visualizer/
│   ├── validation/
│   ├── asset_import/
│   ├── data_generation/
│   └── ci/
│
└── builds/
    ├── windows/
    ├── linux/
    └── web/
```

---

# 4. Architectural Layers

## 4.1 Simulation Domain Layer

Location:

```text
scripts/simulation/
```

Responsibilities:

- Plant state.
- Process-unit state.
- Flow calculations.
- Volume calculations.
- Level calculations.
- Automation logic.
- Alarm evaluation.
- State transitions.
- Mass-balance tracking.
- Simulation commands and events.

Restrictions:

- No references to `Node3D`.
- No references to cameras.
- No references to UI controls.
- No loading of textures, meshes, or scenes.
- No direct user-input handling.
- No dependence on frame rendering.

The simulation domain should use plain GDScript classes, Resources, RefCounted objects, or lightweight Nodes only where Godot lifecycle behavior is genuinely required.

---

## 4.2 Application Layer

Location:

```text
scripts/application/
```

Responsibilities:

- Start and stop the application.
- Load plant configuration.
- Create the plant model.
- Connect simulation, UI, and presentation.
- Route commands.
- Publish events.
- Save and restore snapshots.
- Manage application-level state.

This layer coordinates systems but should not contain hydraulic equations.

---

## 4.3 Configuration Layer

Location:

```text
scripts/configuration/
config/
```

Responsibilities:

- Load plant files.
- Validate schemas.
- Create simulation objects.
- Apply initial conditions.
- Report configuration errors.
- Support alternate plant definitions.

The configuration layer converts data into domain objects.

```text
JSON or Resource
      │
      ▼
Configuration Loader
      │
      ▼
Plant Factory
      │
      ▼
Simulation Domain Objects
```

---

## 4.4 Presentation Layer

Location:

```text
scripts/presentation/
scenes/process_units/
scenes/plant/
```

Responsibilities:

- Display process units.
- Animate valves and gates.
- Move water surfaces.
- Show flow arrows.
- Highlight alarms.
- Support camera controls.
- Handle asset selection.
- Display operating states.

The presentation layer reads immutable snapshots. Quantitative and categorical mappings
must follow `PRESENTATION_MAPPING.md`.

It should not edit simulation state directly.

---

## 4.5 UI Layer

Location:

```text
scripts/ui/
scenes/ui/
```

Responsibilities:

- Display selected asset values.
- Display alarms.
- Display trends.
- Display plant summary.
- Accept operator commands.
- Change simulation speed.
- Switch manual and automatic modes.
- Edit setpoints.

UI actions become simulation commands.

```text
Button or Slider
      │
      ▼
UI Controller
      │
      ▼
Simulation Command
      │
      ▼
Command Bus
      │
      ▼
Simulation Engine
```

---

## 4.6 Telemetry Layer

Location:

```text
scripts/telemetry/
```

Responsibilities:

- Maintain tag registry.
- Produce current telemetry snapshots.
- Maintain rolling trend buffers.
- Export CSV data.
- Support future MQTT or historian adapters.

This layer observes simulation state without owning it.

---

## 4.7 Scenario Layer

Location:

```text
scripts/scenarios/
config/plants/.../scenarios/
```

Responsibilities:

- Schedule commands.
- Inject disturbances.
- Define scenario start conditions.
- Define scenario completion conditions.
- Support future training exercises.

Scenario logic must use the same command interfaces as the UI.

It must not modify internal simulation values directly.

---

# 5. Module Boundaries

## 5.1 Process Unit Contract

Every process-unit model should expose a consistent public contract.

```gdscript
class_name ProcessUnit

var unit_id: StringName
var display_name: String
var enabled: bool
var operating_state: int

func initialize(config: Dictionary) -> void
func pre_tick(context: SimulationContext) -> void
func solve_tick(context: SimulationContext) -> void
func post_tick(context: SimulationContext) -> void
func get_snapshot() -> Dictionary
func validate() -> Array[String]
```

The exact implementation may change, but the lifecycle should remain consistent.

---

## 5.2 Storage Unit Contract

A storage unit should expose:

```text
Current volume
Minimum volume
Maximum volume
Surface area or storage curve
Bottom elevation
Water elevation
Inflow total
Outflow total
Drain flow
Spill flow
Available withdrawal
Available receiving capacity
```

Recommended responsibilities:

- Accept inflow.
- Limit withdrawal.
- Update stored volume.
- Calculate water elevation.
- Calculate spill.
- Prevent negative volume.
- Report mass-balance terms.

---

## 5.3 Flow Port Contract

Each process unit communicates through ports.

Port types:

```text
INLET
OUTLET
DRAIN
SPILL
EXTERNAL_SOURCE
EXTERNAL_SINK
```

A flow port should contain:

```text
Port ID
Owner unit ID
Direction
Maximum flow
Enabled state
Connected link IDs
Current requested flow
Current accepted flow
Current actual flow
```

Ports allow modules to be linked without either module knowing the internal implementation of the other.

---

## 5.4 Flow Link Contract

A flow link connects one source port to one destination port.

Responsibilities:

- Read requested flow.
- Read source availability.
- Read destination capacity.
- Apply actuator restriction.
- Apply link capacity.
- Calculate actual flow.
- Transfer equal volume out of the source and into the destination.
- Record constrained-flow reasons.

Suggested result:

```gdscript
{
    "requested_flow": 1.5,
    "actual_flow": 1.1,
    "constraint": "DESTINATION_CAPACITY"
}
```

---

## 5.5 Actuator Contract

Actuator examples:

- Valve.
- Gate.
- Pump command.
- Mixer command.
- Drain valve.

Common state:

```text
Commanded position
Actual position
Opening rate
Closing rate
Control mode
Availability
Failure mode
Minimum position
Maximum position
```

Public methods:

```gdscript
func command_position(value: float) -> void
func set_mode(mode: ControlMode) -> void
func update_actuator(delta_seconds: float) -> void
func get_effective_opening() -> float
```

---

## 5.6 Instrument Contract

Instrument examples:

- Level transmitter.
- Flow transmitter.
- Valve position indicator.
- Runtime meter.
- Turbidity placeholder.
- Chlorine residual placeholder.

Common state:

```text
Tag
Engineering units
Raw value
Displayed value
Quality
Range
Bias
Noise
Failure mode
```

The proof of concept can use perfect instruments initially, but the interface should allow future failures and noise.

---

## 5.7 Controller Contract

Each controller should:

- Read one or more instrument values.
- Compare values to setpoints.
- Apply deadband and limits.
- Produce actuator commands.
- Report its internal state.

Suggested interface:

```gdscript
func evaluate(context: SimulationContext) -> void
func calculate_output(context: SimulationContext) -> float
func reset() -> void
func get_snapshot() -> Dictionary
```

Controllers must not directly change stored volumes.

They command actuators.

---

## 5.8 Alarm Contract

Each alarm should define:

```text
Alarm ID
Source tag
Priority
Condition
Setpoint
Deadband
Activation delay
Clear delay
Acknowledgement state
Active state
Activation timestamp
Clear timestamp
```

Alarm evaluation should be centralized in the alarm engine.

UI code must not decide whether an alarm is active.

---

# 6. Simulation Tick Lifecycle

The simulation engine should execute each fixed tick in a defined order.

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

Recommended method structure:

```gdscript
func run_tick(delta_seconds: float) -> void:
    command_processor.apply_pending_commands()
    actuator_system.update(delta_seconds)
    controller_system.evaluate(delta_seconds)
    flow_solver.solve(delta_seconds)
    storage_system.integrate(delta_seconds)
    state_machine_system.update(delta_seconds)
    alarm_system.evaluate(delta_seconds)
    telemetry_system.record()
    invariant_validator.validate()
    snapshot_service.publish()
```

The order must be documented and tested because changing it can change simulation results.

---

# 7. Plant Topology Model

The plant should be represented as a directed graph.

```text
Process Units = Nodes
Flow Links = Edges
Ports = Connection Points
```

Example:

```text
RESERVOIR_01.OUTLET
    │
    ▼
LINK_RAW_01
    │
    ▼
INLET_MANIFOLD.INLET_01
```

A topology file should identify:

- Process units.
- Ports.
- Links.
- Source and destination.
- Maximum flow.
- Default actuator.
- Flow model.
- Enabled state.

Example:

```json
{
  "id": "LINK_SED_01_TO_APPLIED",
  "source": "SED_BASIN_01.OUTLET",
  "destination": "APPLIED_CHANNEL.INLET_01",
  "flow_model": "commanded",
  "maximum_flow_m3s": 2.0,
  "actuator_id": "GV_SED_01_EFF"
}
```

---

# 8. Reusable Process-Unit Package Pattern

Each process unit should follow the same package pattern.

Example:

```text
scenes/process_units/sedimentation/
├── sedimentation_basin.tscn
├── sedimentation_basin_visual.gd
├── meshes/
├── materials/
└── README.md

scripts/simulation/process_units/
└── sedimentation_basin_model.gd

config/defaults/
└── sedimentation_basin_defaults.json

tests/unit/simulation/process_units/
└── test_sedimentation_basin_model.gd
```

The model, visual scene, configuration, and tests remain separate but clearly associated.

---

# 9. Scene Architecture

## 9.1 Main Application Scene

Suggested structure:

```text
Main
├── ApplicationServices
├── SimulationHost
├── PlantWorld
├── CameraRig
├── UserInterface
├── DebugOverlay
└── Audio
```

The `SimulationHost` owns the simulation engine lifecycle.

The `PlantWorld` owns only 3D presentation scenes.

---

## 9.2 Process-Unit Scene Pattern

Example storage-unit scene:

```text
SedimentationBasinVisual
├── StaticGeometry
├── WaterSurface
├── InletGateVisual
├── OutletGateVisual
├── DrainVisual
├── SpillVisual
├── FlowIndicators
├── AlarmIndicator
├── SelectionCollider
├── LabelAnchor
└── VisualAdapter
```

The scene should receive a `unit_id` that links it to the simulation model.

```gdscript
@export var unit_id: StringName
```

The visual adapter requests the latest snapshot for that ID.

---

## 9.3 No Simulation Logic in Scene Scripts

A scene script may:

- Move a water plane.
- Rotate a valve handle.
- Change a material.
- Show an alarm light.
- Update a label.

A scene script may not:

- Calculate basin volume.
- Calculate actual flow.
- Apply plant capacity limits.
- Decide whether a spill occurs.
- Evaluate an interlock.
- Determine alarm state.

---

# 10. Application Services and Autoloads

Use autoloads sparingly.

Recommended initial autoloads:

```text
AppState
EventBus
CommandBus
ConfigRegistry
UnitConverter
```

Possible later autoloads:

```text
SaveService
AudioService
TelemetryRegistry
```

Do not make every subsystem an autoload.

The simulation engine should be instantiated and owned by the application scene so tests can create isolated simulation engines.

---

# 11. Command Architecture

All state-changing external actions should use commands.

Example command types:

```text
SetValvePosition
SetGatePosition
SetFlowSetpoint
SetLevelSetpoint
SetControlMode
SetBasinService
SetSimulationSpeed
AcknowledgeAlarm
ResetSimulation
LoadSnapshot
```

Command example:

```gdscript
class_name SetValvePositionCommand
extends SimulationCommand

var actuator_id: StringName
var requested_position: float
```

Benefits:

- Commands can be validated.
- Commands can be logged.
- Commands can be replayed.
- Scenarios and UI use the same path.
- Future multiplayer or external integration becomes easier.
- Deterministic testing becomes possible.

---

# 12. Event Architecture

Events communicate completed state changes.

Examples:

```text
ValvePositionChanged
UnitStateChanged
AlarmActivated
AlarmCleared
SpillStarted
SpillStopped
ControllerModeChanged
SimulationReset
MassBalanceViolation
```

Commands request changes.

Events report changes.

```text
Command: Set Basin 3 Out of Service
Event: Basin 3 State Changed to Draining
```

Avoid using events to implement tightly coupled hydraulic calculations. Hydraulic calculation should remain inside the simulation engine.

---

# 13. Snapshot Architecture

The presentation and UI should read simulation snapshots.

A snapshot is a read-only representation of state at the end of a simulation tick.

Example:

```gdscript
{
  "simulation_time": 3600.0,
  "units": {
    "SED_BASIN_01": {
      "state": "IN_SERVICE",
      "volume_m3": 42000.0,
      "level_m": 4.6,
      "inflow_m3s": 1.2,
      "outflow_m3s": 1.18,
      "spill_m3s": 0.0
    }
  },
  "actuators": {},
  "alarms": {},
  "plant_totals": {}
}
```

Snapshots prevent UI and visual code from holding unsafe references to mutable simulation objects.

For each rendered update, all data-bearing presentation and UI elements must use one
completed snapshot. Redundant indications must use the same snapshot tick; presentation
interpolation may lag but must never lead that snapshot or become a second source of
simulation truth. The detailed encoding and validation rules are defined in
`PRESENTATION_MAPPING.md`.

---

# 14. Configuration Architecture

## 14.1 Configuration Categories

Separate configuration into:

```text
Plant Identity
Plant Topology
Equipment Parameters
Initial Conditions
Automation Parameters
Alarm Parameters
Scenario Definitions
Presentation Mapping
```

Do not place all configuration in one large file.

---

## 14.2 Configuration Validation

Validate before creating the simulation.

Validation checks should include:

- Duplicate IDs.
- Missing source or destination ports.
- Invalid flow direction.
- Negative capacities.
- Initial volume above maximum.
- Spill elevation below operating level.
- Missing actuator references.
- Invalid controller references.
- Circular connections where prohibited.
- Flow splits that do not total correctly.
- Units with no valid downstream path.

Configuration errors should stop plant loading with specific messages.

---

## 14.3 Stable IDs

Every important object should have a stable ID.

Examples:

```text
RSV_RAW_01
RSV_RAW_02
MNF_INLET_01
MXR_FLASH_01
DBX_SED_01
SED_BASIN_01
FLT_01
CWL_01
CT_BASIN_01
RSV_TREATED_01
```

IDs should not depend on scene-tree paths.

Scene nodes can move without breaking simulation references.

---

# 15. Internal Unit Strategy

Use SI units internally.

```text
Volume: cubic meters
Flow: cubic meters per second
Length and elevation: meters
Time: seconds
Mass: kilograms
Dose: milligrams per liter
```

Display units can include:

```text
Flow: MGD
Level: feet
Volume: million gallons
Time: minutes or hours
```

All conversion should occur at system boundaries.

```text
User Input in MGD
        │
        ▼
Unit Converter
        │
        ▼
Simulation in m³/s
```

Do not store mixed units inside domain objects.

---

# 16. Testing Architecture

## 16.1 Unit Tests

Unit tests cover isolated behavior.

Examples:

- Storage level increases when inflow exceeds outflow.
- Volume cannot become negative.
- Valve opening is clamped from 0 to 1.
- Flow is limited by source availability.
- Flow is limited by destination capacity.
- Spill activates above maximum volume.
- Alarm delay behaves correctly.
- Controller output respects limits.

---

## 16.2 Integration Tests

Integration tests cover connected systems.

Examples:

```text
Reservoir → Basin → Receiving Reservoir
```

```text
Distribution Box → Five Sedimentation Basins → Applied Channel
```

```text
Applied Channel → Twelve Filters → Clearwell
```

Integration tests should verify:

- Correct flow propagation.
- Correct redistribution.
- Capacity handling.
- Water conservation.
- Correct alarm transitions.

---

## 16.3 Invariant Tests

Invariant tests run across the complete plant.

Required invariants:

- No negative storage.
- No flow through closed valves.
- No out-of-service unit accepts normal flow unless explicitly allowed.
- No flow exceeds link capacity.
- Total plant water is conserved.
- Simulation replay is deterministic.
- No NaN or infinite values.
- Every active connection has valid ports.
- Every simulated unit has a stable ID.

---

## 16.4 Scenario Regression Tests

Each major sandbox scenario should become a regression test.

Examples:

- Loss of one raw-water source.
- Basin isolation.
- Basin outlet restriction.
- Multiple filters out of service.
- Clearwell outlet closure.
- High treated-water demand.
- Full plant drain-down.

A bug found during a scenario should result in a test that reproduces it.

---

# 17. Dependency Rules

## Allowed Dependencies

```text
simulation/core
    may depend on simulation/domain and utilities

simulation/hydraulics
    may depend on simulation/domain and utilities

simulation/automation
    may depend on simulation/domain and utilities

application
    may depend on simulation, configuration, telemetry, and scenarios

presentation
    may depend on application interfaces and snapshots

ui
    may depend on application services, commands, snapshots, and formatters

tests
    may depend on any test target
```

## Forbidden Dependencies

```text
simulation → presentation
simulation → UI
simulation → camera
simulation → asset files
simulation → specific 3D scenes
domain model → singleton UI state
process-unit model → another unit's private fields
```

---

# 18. Naming Conventions

## Files

Use snake_case:

```text
simulation_engine.gd
storage_unit.gd
sedimentation_basin_model.gd
```

## Classes

Use PascalCase:

```text
SimulationEngine
StorageUnit
SedimentationBasinModel
```

## Variables and Functions

Use snake_case:

```gdscript
current_volume_m3
maximum_flow_m3s
calculate_water_level()
```

## Constants

Use uppercase snake case:

```gdscript
const MINIMUM_LEVEL_M := 0.0
```

## IDs and Tags

Use uppercase structured IDs:

```text
SED_BASIN_01
FIT_SED_01_IN
LIT_CWL_01
GV_FLT_03_IN
```

---

# 19. Documentation Per Module

Every reusable process-unit module should contain documentation covering:

- Purpose.
- Inputs.
- Outputs.
- Stored state.
- Equations.
- Constraints.
- Operating states.
- Commands.
- Events.
- Alarms.
- Configuration fields.
- Assumptions.
- Known limitations.
- Tests.

A short `README.md` may live beside each major process-unit scene or package.

---

# 20. Asset Architecture

## 20.1 Separate Generic and Plant-Specific Assets

```text
assets/models/generic_equipment/
assets/models/process_units/
```

Generic assets include:

- Pumps.
- Valves.
- Fences.
- Handrails.
- Buildings.
- Roads.
- Trees.
- Electrical cabinets.

Plant-specific assets include:

- Applied channel.
- Sedimentation basin.
- Filter cells.
- Clearwell.
- CT basins.
- Distribution box.

---

## 20.2 Asset Licensing

Every third-party asset source must have a matching license record.

```text
assets/licenses/
├── kenney.md
├── quaternius.md
├── kaykit.md
└── asset_manifest.csv
```

The asset manifest should include:

```text
Asset name
Source
Creator
License
Modified
Repository location
```

---

## 20.3 Replaceable Visual Assets

Simulation IDs must not depend on mesh names.

A placeholder cube and a finished Blender model should be interchangeable without changing simulation code.

---

# 21. Git and Branching Strategy

Recommended branches:

```text
main
develop
feature/<short-name>
fix/<short-name>
docs/<short-name>
```

Keep commits focused.

Examples:

```text
feat(sim): add storage mass-balance model
feat(ui): add selected asset level display
fix(flow): prevent withdrawal above source volume
test(filter): add offline redistribution test
docs(architecture): define process-unit contract
```

Avoid commits that mix:

- Hydraulic behavior.
- 3D art replacement.
- UI redesign.
- Configuration changes.
- Unrelated refactoring.

---

# 22. Pull Request Rules

Each pull request should state:

- What changed.
- Why it changed.
- Which architectural layer it affects.
- What assumptions were made.
- What tests were added or updated.
- Whether configuration changed.
- Whether saved simulations remain compatible.
- Screenshots for visual changes.
- Mass-balance result for hydraulic changes.

A hydraulic behavior change should not be merged without tests.

---

# 23. AI-Assisted Development Rules

Claude Code and Codex must read these files before significant work:

```text
AGENTS.md
docs/PROJECT_SCOPE.md
docs/REPOSITORY_ARCHITECTURE.md
docs/SIMULATION_RULES.md
docs/CONTROL_LOGIC.md
docs/TAG_NAMING.md
docs/INTERNAL_UNITS.md
```

## Required Agent Behavior

- Respect dependency boundaries.
- Keep simulation and presentation separate.
- Do not create new global singletons without justification.
- Do not duplicate logic across repeated units.
- Use factories and configuration for repeated units.
- Add tests for every new hydraulic behavior.
- Add regression tests for every bug fix.
- Keep SI units inside the simulation.
- Do not silently change public interfaces.
- Update documentation when architecture changes.
- Prefer small changes over large rewrites.
- Do not add plugins without documenting purpose and license.
- Do not replace deterministic calculations with frame-based logic.
- Do not embed plant-specific values in reusable scripts.

---

# 24. Recommended Initial Implementation Order

## Step 1: Repository Foundation

Create:

- Folder structure.
- Documentation.
- GUT testing addon.
- Base application scene.
- Simulation engine shell.
- Simulation clock.
- Unit conversion utilities.
- Command and event base classes.

## Step 2: Core Domain

Create:

- ProcessUnit.
- StorageUnit.
- FlowPort.
- FlowLink.
- Actuator.
- Instrument.
- Alarm.
- Controller.

## Step 3: First Hydraulic Slice

Create:

```text
Source Reservoir → Storage Basin → Receiving Reservoir
```

Include:

- Inlet valve.
- Outlet valve.
- Drain.
- Spill.
- Mass-balance tracker.
- Snapshot output.
- Unit tests.

## Step 4: Presentation Adapter

Create:

- Generic storage scene.
- Water surface adapter.
- Valve visual adapter.
- Selection system.
- Basic asset panel.

## Step 5: Data-Driven Construction

Create:

- Configuration loader.
- Plant factory.
- Topology loader.
- Schema validation.
- Initial conditions.

## Step 6: Expand Process Train

Add modules in this order:

1. Two raw-water reservoirs.
2. Inlet manifold.
3. Flash mix.
4. Distribution box.
5. Five flocculation/sedimentation basins.
6. Applied channel.
7. Twelve filters.
8. Clearwell.
9. Two CT basins.
10. Treated-water reservoir.
11. System demand.

---

# 25. Architecture Decision Records

Major architectural choices should be recorded in:

```text
docs/DECISIONS/
```

Example files:

```text
0001-use-godot-and-gdscript.md
0002-use-fixed-step-simulation.md
0003-use-si-internal-units.md
0004-separate-simulation-and-presentation.md
0005-use-command-event-boundary.md
0006-use-json-plant-configuration.md
```

Each record should include:

```text
Status
Context
Decision
Consequences
Alternatives Considered
```

This helps future contributors and AI agents understand why the project is structured this way.

---

# 26. Definition of Architectural Success

The repository architecture is working when:

- A simulation can run without loading the 3D plant.
- A process unit can be tested independently.
- A process unit visual can be replaced without changing hydraulic code.
- A new basin or filter can be added through configuration.
- Five basins reuse one basin model.
- Twelve filters reuse one filter model.
- UI actions use commands rather than modifying model fields.
- Scenarios use the same commands as the UI.
- All plant values use one internal unit system.
- Plant-wide mass balance can be calculated every tick.
- Configuration errors are reported before simulation starts.
- A complete simulation can be deterministically replayed.
- Claude Code or Codex can identify the correct layer and folder for a requested change.

---

# 27. Core Rule Summary

```text
Simulation owns truth.
Configuration defines the plant.
Commands request changes.
Events report changes.
Snapshots expose state.
Presentation shows state.
UI sends commands.
Tests protect behavior.
```

This architecture keeps the first proof of concept simple while preserving a clean path toward a larger operator-training and digital-twin platform.
