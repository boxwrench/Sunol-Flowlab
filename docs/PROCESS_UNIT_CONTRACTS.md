# Process Unit Contracts

This document defines the required interface for every reusable unit in the simulation.  Adhering to these contracts allows units to be composed consistently.

## Canonical Class Names

The following table defines the canonical class names used across the domain codebase. All domain classes must use these exact names (which do not have a `Node` suffix, as `Node` is reserved for actual Godot Nodes in the presentation/UI layers) and extend `RefCounted`:

| Concept | Canonical Class Name | Suffix Rule / Notes |
|---------|----------------------|---------------------|
| Process Unit Base | `ProcessUnit` | Base class for all domain units |
| Storage Unit | `StorageUnit` | Replaces `StorageNode` |
| Junction Unit | `JunctionUnit` | Replaces `JunctionNode` |
| Flow Link | `FlowLink` | Connects flow ports |
| Flow Port | `FlowPort` | Connection point on a unit |
| Valve Actuator | `SimValve` | Actuator modeling valve travel |
| Controller | `SimController` | Base for level/flow controllers |
| Alarm | `SimAlarm` | Threshold or diagnostic alarm |
| Instrument | `SimInstrument` | Level/flow transmitters |

## Common fields

Every unit type must define:

- `id` – a unique identifier following the tag naming conventions.
- `display_name` – a human‑readable name for UI display.
- `type` – the unit category (e.g., storage_node, junction_node).
- `in_service` – boolean indicating whether the unit is available to the plant.
- `state` – the current operating state (see below).

### Operating states

Each unit defines its own state machine.  Common states include:

- `OFFLINE` – unit is not part of the flow network.
- `FILLING` – the unit is accepting water until it reaches operating level.
- `IN_SERVICE` – normal operating mode.
- `DRAINING` – unit is being emptied.
- `EMPTY` – unit has no usable water.
- `HIGH_LEVEL` – water has reached a high‑level alarm.
- `SPILLING` – excess water is being spilled.

## StorageUnit contract

Represents anything that stores water (reservoir, basin, channel, clearwell).

**Inputs**:

- `inflow` (m³/s) – total water entering from upstream links.
- `drain_flow` (m³/s) – operator‑controlled drain to waste.

**Outputs**:

- `outflow` (m³/s) – water leaving toward downstream links.
- `spill_flow` (m³/s) – excess water discharged due to high level.

**Stored state**:

- `volume` (m³) – current water volume.
- `elevation` (m) – calculated from volume and geometry.

**Commands**:

- `set_in_service(bool)` – place the unit in or out of service.
- `open_drain(position)` – adjust the drain valve position (0–100%).

**Events**:

- `on_high_level` – fired when elevation ≥ high level.
- `on_low_level` – fired when elevation ≤ low level.

**Alarms**:

- High‑level alarm.
- Low‑level alarm.
- Spill alarm.

**Configuration fields**:

- `maximum_volume_m3`
- `surface_area_m2`
- `bottom_elevation_m`
- `high_level_m`
- `spill_level_m`
- `min_operating_level_m`
- `max_flow_m3s`

## JunctionUnit contract

Represents a location that combines or splits flows without storage (e.g., manifold, distribution box).

**Inputs**:

- `inflows` (m³/s) – list of flows from upstream connections.

**Outputs**:

- `outflows` (list of m³/s) – flows assigned to downstream connections.

**Commands**:

- `set_distribution_rule(rule)` – choose how incoming flow is split (equal, percentage, priority).

**Events**:

- `on_capacity_exceeded` – fired when inflow exceeds maximum throughput.

**Configuration fields**:

- `max_throughput_m3s`
- Distribution parameters (percentages, max per outlet).

## FlowLink contract

Connects a source port to a destination port.

**Inputs**:

- `requested_flow` (m³/s) – desired flow rate.
- `valve_position` (0–100%).

**Outputs**:

- `actual_flow` (m³/s) – flow realised after applying constraints.

**Commands**:

- `set_valve_position(percent)` – command the valve or gate.
- `enable(bool)` – enable/disable the link.

**Events**:

- `on_no_flow` – fired when flow is zero despite a request.
- `on_max_capacity` – fired when flow hits maximum.

**Configuration fields**:

- `max_flow_m3s`
- `reverse_flow_allowed`
- `flow_mode` (commanded, restricted, gravity)
- `flow_coefficient` (for gravity mode)

## SimValve contract

Represents an actuator controlling a flow path.

**Inputs**:

- `commanded_position` (0–100%) – desired valve opening.

**Outputs**:

- `position` (0–100%) – actual valve opening.

**Commands**:

- `set_manual(bool)` – switch between manual and automatic mode.
- `set_commanded_position(percent)`

**Events**:

- `on_failure` – fired when the valve fails to respond.

**Configuration fields**:

- `opening_rate_percent_per_s`
- `closing_rate_percent_per_s`
- `fail_state` (open, closed, last position)

## SimController contract

Automates adjustments to maintain process conditions.

**Inputs**:

- `process_variable` – measured level or flow.
- `setpoint`

**Outputs**:

- `output` – commanded flow or valve position.

**Commands**:

- `enable(bool)`
- `set_setpoint(value)`
- `set_gain(value)`

**Events**:

- `on_deviation` – fired when error exceeds deadband.

**Configuration fields**:

- `gain`
- `deadband`
- `min_output`
- `max_output`
- `initial_output`

## SimAlarm contract

Defines an alarm associated with a process unit.

**Inputs**:

- `value` – the variable being monitored.

**Outputs**:

- `active` – whether the alarm is currently active.

**Configuration fields**:

- `priority`
- `trigger_value`
- `delay_s`
- `deadband`
- `message`

## Extending contracts

If a new unit requires additional fields or behaviours, extend the appropriate contract and document the new fields here.  Maintaining explicit contracts prevents silent interface changes from breaking other modules.
