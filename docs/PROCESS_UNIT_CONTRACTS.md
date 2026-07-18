# Process Unit Contracts

This document defines the interface for every reusable unit in the simulation. It is
reconciled against production symbols in `scripts/simulation/` and the JSON schemas in
`config/schema/`. Where an interface is intended but not yet built, it is marked **Planned /
Not Implemented**; everything else reflects code as committed. On any conflict, the committed
code and schemas win — update this document.

Two conventions used throughout, because they are the most common source of drift:

- **Internal fields carry SI-unit suffixes** (`volume_m3`, `level_m`, `deadband_m`). The
  generic names in prose (volume, level) are conceptual; the code and config use the
  suffixed forms.
- **Operators act through command objects, not instance methods.** There is no
  `unit.open_drain()` or `link.set_valve_position()`. State changes are enqueued as
  `SimulationCommand` subclasses (see each contract's *Commands* section) and applied at a
  scheduled tick. Alarms are evaluated by `AlarmEngine` over `ThresholdAlarm` instances, not
  raised as per-unit signals — the domain classes extend `RefCounted` and define no signals.

## Canonical Class Names

The following table defines the canonical class names used across the domain codebase. All
domain classes use these exact names (no `Node` suffix — `Node` is reserved for actual Godot
Nodes in the presentation/UI layers) and extend `RefCounted`.

| Concept | Canonical Class Name | Implementation Status / Notes |
|---------|----------------------|---------------------|
| Process Unit Base | `ProcessUnit` | Implemented; base class for all domain units (`scripts/simulation/domain/process_unit.gd`) |
| Storage Unit | `StorageUnit` | Implemented (`domain/storage_unit.gd`) |
| External Boundary | `ExternalBoundary` | Implemented; typed source/sink (`domain/external_boundary.gd`) |
| Junction Unit | `JunctionUnit` | Realized as `StorageUnit` — no separate `JunctionUnit` class exists; small storage units behave as junctions |
| Flow Link | `FlowLink` | Implemented (`domain/flow_link.gd`) |
| Flow Port | `FlowPort` | Implemented (`domain/flow_port.gd`) |
| Valve Actuator | `SimValve` | Implemented (`domain/actuator.gd`) |
| Controller | `SimController` | Implemented base; `LevelController` (`automation/level_controller.gd`) is the concrete controller |
| Alarm | `ThresholdAlarm` | Implemented (`alarms/threshold_alarm.gd`), evaluated by `AlarmEngine` — no generic `SimAlarm` class exists |
| Instrument | `SimInstrument` | Planned / Not Implemented — no `SimInstrument` class exists; instruments read property fields directly from units |

## Common fields

Every unit extends `ProcessUnit`, which defines:

- `unit_id` (`StringName`) – unique identifier following the tag naming conventions.
- `display_name` (`String`) – human-readable name for UI display.
- `type` (`String`) – the unit category (e.g. `StorageUnit`, `ExternalBoundary`).
- `in_service` (`bool`) – whether the unit is available to the plant.
- `operating_state` (`StringName`) – current operating state; defaults to `IN_SERVICE`.

Base method: `set_in_service(p_in_service: bool)`.

### Operating states

`operating_state` is a free `StringName` (default `IN_SERVICE`); it is carried in snapshots
but **not enforced by a formal state machine** in the current build. The values below are the
intended vocabulary, documented for planning — treat them as **Planned** until a unit enforces
transitions between them:

- `OFFLINE` – unit is not part of the flow network.
- `FILLING` – accepting water until it reaches operating level.
- `IN_SERVICE` – normal operating mode (the only state set by default today).
- `DRAINING` – being emptied.
- `EMPTY` – no usable water.
- `HIGH_LEVEL` – water has reached a high-level alarm.
- `SPILLING` – excess water is being spilled.

## StorageUnit contract

Represents anything that stores water (reservoir, basin, channel, clearwell). Source:
`domain/storage_unit.gd`.

**Flows (tracked state, m³/s)**: `inflow_m3s` (from upstream INLET links), `outflow_m3s` (to
downstream OUTLET links), `drain_flow_m3s` (to DRAIN-port links), `spill_flow_m3s` (discharged
on over-elevation). These are computed each tick by `StorageBalance`, not set by operators.

**Stored state**: `volume_m3` (m³), `level_m` (m, `= volume_m3 / surface_area_m2`). The
snapshot additionally exposes `elevation_m`.

**Commands** (enqueued `SimulationCommand` subclasses):

- `SetBasinServiceCommand(target_unit_id: StringName, put_in_service: bool, apply_tick: int)`
  – canonical service-state command for basin/storage availability. Toggles the unit's
  `in_service` flag and sets `is_enabled = put_in_service` on all connected `INLET` and
  `OUTLET` links; connected `DRAIN` links remain enabled. It does not modify topology (the
  unit stays in the topological order).
- `SetUnitServiceCommand(...)` – **legacy alias** subclassing `SetBasinServiceCommand`
  (`commands/set_unit_service_command.gd`), retained for compatibility. `SetBasinServiceCommand`
  is the single implementation and the documented operator-facing command.

There is no `open_drain()` method — draining is realized through DRAIN-port links and their
valves, not a unit method.

**Events / alarms**: high-level, low-level, and spill conditions are raised by `AlarmEngine`
evaluating `ThresholdAlarm` instances (see the Alarm contract), not by unit-level signals.

**Configuration fields** (topology schema, `units[]`):

- `maximum_volume_m3`
- `surface_area_m2`
- `bottom_elevation_m`
- `floor_elevation_m`
- `high_level_m`
- `spill_level_m`
- `min_operating_level_m`
- `spill_destination_id` (required; spill routing — the validator errors if unresolvable)

Note: `max_flow_m3s` is a **link** capacity, not a StorageUnit field; do not set it on a unit.

## JunctionUnit Contract (Abstract — Realized as StorageUnit)

Physical junctions, manifolds, splitter boxes, and distribution boxes combine or split flows.
To keep a pure Directed Acyclic Graph (DAG) and avoid simultaneous multi-variable solving,
**the simulation models all junctions as small `StorageUnit`s** — there is no `JunctionUnit`
class. They use the `StorageUnit` structure parameterized with a small surface area
(e.g. `1.0 m²`) and capacity.

- **Inlet Manifold** (`MANIFOLD_01`): a small `StorageUnit` combining reservoir inflows and
  passing them to the flash mix.
- **Distribution Box** (`DIST_BOX_01`): a small `StorageUnit` with multiple outlet ports; flow
  splits are realized by the commanded positions of the downstream outlet gates/valves
  (equal split or operator-specified percentages).

## FlowLink contract

Connects a source port to a destination port. Source: `domain/flow_link.gd`.

**Flow state (m³/s)**: `requested_flow_m3s`, `granted_flow_m3s`, `actual_flow_m3s`. Control
state: `is_enabled` (bool), `constraint_reason` (String — human-readable reason the flow was
limited, e.g. `"Valve Closed"`, `"GRAVITY self-regulating"`).

**Valve / enablement**: a link has no `set_valve_position()` or `enable()` method. Opening is
governed by the associated `SimValve` (`actuator`), driven by `SetValvePositionCommand`;
enablement is the `is_enabled` field, toggled by `SetBasinServiceCommand` on the owning unit.

**Events**: none. Flow-limiting conditions (no flow, at capacity, valve closed) surface through
`constraint_reason`, not signals.

**Configuration fields** (topology schema, `links[]`):

- `link_id`, `display_name`
- `source_port_id`, `destination_port_id`
- `max_flow_m3s` – link capacity
- `flow_mode` – enum `RESTRICTED | GRAVITY`.
  - `RESTRICTED`: flow = capacity × valve opening.
  - `GRAVITY`: self-regulating on head difference, using `design_head_m`.
  - The former `COMMANDED` placeholder was removed in WP4.3; a link using it is now rejected
    at configuration load. It may return only under the ROADMAP "triggered later" contract.
- `design_head_m` – reference head for `GRAVITY` mode (there is no `flow_coefficient` field).
- `actuator_id` – the controlling `SimValve`, if any.

Note: `reverse_flow_allowed` is still read by the loader but is **not in the topology schema**
and is on the removal path (ROADMAP WP4.4). Do not rely on it in new configuration.

## SimValve contract

Represents an actuator controlling a flow path. Source: `domain/actuator.gd`.

**State**: `commanded_position` (0–100%, desired opening), `position` (0–100%, actual opening;
slews toward commanded at the configured rates). `is_manual` (bool). `get_effective_opening()`
returns `position / 100`.

**Methods**: `set_manual(p_manual: bool)`, `set_commanded_position(pos: float)`.

**Commands**: `SetValvePositionCommand(actuator_id: StringName, pos: float, apply_tick: int)`.

**Events**: none (no `on_failure` signal). `fail_state` selects the modeled behavior instead.

**Configuration fields** (topology schema, `actuators[]`):

- `opening_rate_percent_per_s`
- `closing_rate_percent_per_s`
- `fail_state` – `OPEN | CLOSED | LAST_POSITION`
- `is_manual`, `initial_position`, `instant_mode` (debug: apply commanded position instantly)

## SimController contract

Automates adjustments to maintain process conditions. `SimController`
(`domain/controller.gd`) is the base; `LevelController` (`automation/level_controller.gd`) is
the concrete proportional controller.

**Inputs**: the process variable is read from a unit — `pv_unit_id` + `pv_property`
(default `level_m`) — not passed in. `control_mode` is `MANUAL | AUTO`.

**Output**: `previous_output` holds the last commanded output (valve position), clamped to
`[min_output, max_output]`.

**Methods**: `initialize(config)`, `evaluate(context)`. There are no `enable()`,
`set_setpoint()`, or `set_gain()` instance methods — mode and setpoint change through commands:

- `SetControllerModeCommand(controller_id: StringName, mode: StringName, apply_tick: int)`
- `SetLevelSetpointCommand(controller_id: StringName, setpoint: float, apply_tick: int)`

**Events**: none (no `on_deviation` signal).

**Configuration fields** (controllers schema):

- Base: `controller_id`, `display_name`, `type`, `target_actuator_id`, `pv_unit_id`,
  `pv_property`, `control_mode`, `gain`, `deadband_m`, `min_output`, `max_output`.
- `LevelController` adds: `setpoint`, `kp`, `kd`, `bumpless_transfer`.

There is no `initial_output` config field, and the deadband field is `deadband_m` (not
`deadband`).

## ThresholdAlarm contract

Defines an alarm associated with a process unit, evaluated by `AlarmEngine`. Source:
`alarms/threshold_alarm.gd`.

**Inputs**: `evaluate(current_value: float, dt: float, context)` — the monitored value is read
from `target_unit_id.target_property` and passed in by the engine.

**Output / state**: `is_active` (bool). Activation respects `delay_s` and `deadband`.

**Configuration fields** (alarms schema):

- `alarm_id`, `display_name`
- `target_unit_id`, `target_property`
- `alarm_type` – `HIGH | LOW`
- `threshold_value` – the trigger threshold (there is no `trigger_value` field)
- `delay_s`
- `deadband`

There are no `priority` or `message` **config** fields in the alarms schema (`message` exists
only as a runtime label on the class).

## Extending contracts

If a new unit requires additional fields or behaviours, extend the appropriate contract and
document the new fields here, against real symbols and schema entries. Maintaining explicit,
code-reconciled contracts prevents silent interface changes from breaking other modules.
