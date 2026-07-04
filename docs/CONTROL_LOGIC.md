# Control Logic

This document describes the automation rules used by the drinking water plant sandbox.  It defines how controllers adjust flows and levels, how manual and automatic modes interact, and how the system should respond to equipment states.

## Control modes

Every controllable asset supports four modes:

- **MANUAL** – the user directly sets valve positions, flow setpoints or equipment states.  Automatic controllers are bypassed.
- **AUTO** – controllers compute commands based on measured variables and setpoints.
- **FORCED** – a test or scenario overrides normal logic (e.g., to simulate a stuck valve).
- **FAILED** – the asset cannot follow its commands and remains at its failure state.

Controllers must respect the asset's mode.  In MANUAL or FORCED modes, controllers should not override the user command.

## Controller execution order

The following order is recommended on each simulation tick:

1. **Source‑flow controller** – adjusts raw‑water inflow from reservoirs to meet plant inflow setpoint.
2. **Sedimentation flow splitter** – divides total inflow among available basins according to equal split or operator‑specified percentages.
3. **Filter flow splitter** – divides applied‑channel flow among available filters, respecting maximum filtration rates.
4. **Clearwell level controller** – adjusts clearwell outflow to maintain a level setpoint.
5. **CT‑basin splitter** – divides clearwell outflow between available contact basins.
6. **Treated‑reservoir level controller** – (optional) adjusts plant inflow based on treated‑water reservoir level.

Controllers should be modular and independent of scene code.

## Level control logic

Use a simple proportional controller for level control:

```
error = setpoint - measured_level
output = previous_output + gain × error
output = clamp(output, min_output, max_output)
```

Include a deadband to avoid oscillation when the error is small.  More advanced PID control may be added later.

## Flow splitting

When splitting flow among parallel units (basins or filters), follow these rules:

- Identify which units are in service.
- Divide flow equally among available units, unless percentages are specified.
- Do not assign more than the unit's maximum capacity.
- If one unit cannot accept its share, redistribute the excess among remaining units.
- If total required flow exceeds combined capacity, raise a high‑level or capacity alarm.

## Lead‑lag source selection

When drawing from multiple sources (e.g., two reservoirs), designate one source as the lead.  The lead source supplies flow until it reaches a low‑level or other constraint.  The lag source then supplements to meet total demand.  Allow the operator to switch which source leads.

## Permissives and interlocks

Before a unit can be placed in service, ensure that all permissive conditions are satisfied (e.g., enough water volume, valves aligned).  Define interlocks that automatically take a unit out of service if unsafe conditions occur (e.g., low‑low level, drain valve open).

## Bumpless transfer

When switching an asset from MANUAL to AUTO, the controller output should start from the current manual position to avoid sudden jumps.  Similarly, switching from AUTO to MANUAL should not immediately change the valve position.

## Fallback behaviour

If a controller fails or its measured input is invalid, default to a safe state:

- Use last valid output.
- Or close the valve and raise an alarm.
- Or stop the flow and raise an alarm.

Document the chosen fallback for each controller.

## Control loop characteristics

### Velocity-form proportional control mechanics

The proportional control loop uses a velocity-form algorithm:
```
error = setpoint - measured_level
output = previous_output + gain × error
```
Although conventionally named a "proportional" controller, the velocity-form implementation operates mathematically as a **pure integral controller** because the change in output is added to the previous valve command on every tick. Consequently:
- **No steady-state offset (droop)**: Unlike a position-form P-controller, the velocity-form P-controller does not exhibit steady-state droop under sustained load changes. In steady state, the level error converges to zero (or within the deadband bounds). For example, under a sustained downstream demand step from 50% to 52% with a loop gain of 2.0, the time-averaged level stabilizes at approximately **4.981m** (representing zero offset within deadband limit-cycle fluctuations).
- **Transient error integral**: Rather than a sustained error offset, a permanent change in output ($\Delta \text{output}$) requires a transient cumulative error over time:
  $$\sum \text{error} \times \Delta t = \frac{\Delta \text{output}}{\text{gain}}$$
- **Limit cycles and stability**: Because the storage unit acts as a physical integrator (volume integrates net flow) and the velocity-form controller acts as an integral controller, the closed-loop system is an undamped double integrator. Combined with one-tick scan/actuator lag, the loop cannot asymptotically settle and will exhibit deadband-bounded limit cycles.
- **Tuning and Loop Gain**: High gains destabilize the loop and cause rapid, high-amplitude valve oscillations (rail-to-rail chattering). The loop gain per tick is approximated by:
  $$\text{Loop Gain} \approx \frac{\text{gain} \times \text{max\_flow\_m3s}}{100 \times \text{surface\_area\_m2}}$$
  To avoid severe limit cycles and preserve equipment lifetime, the gain should be kept small (e.g., `gain = 2.0`). Adding derivative/damping terms (PID) is a roadmap item for future phases.

### Loop direction and element pairing

When pairing controllers with physical actuators:
- **Reverse-acting vs. Direct-acting**: With a positive gain, the error formula `setpoint - measured_level` is reverse-acting (output increases when PV is below setpoint). It must only target inflow control elements (e.g., inflow valves) to be stable. Targeting an outflow control element with a positive gain results in positive feedback and loop instability.


