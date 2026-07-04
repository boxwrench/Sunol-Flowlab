# Simulation Rules

This document defines the mathematical and logical rules that govern the drinking water plant simulation.  All simulation code must conform to these rules.

## Time stepping

The simulation uses a **fixed time step**.  One simulation update represents a fixed number of real‑world seconds (configurable, default 1 s).  All calculations must run off this fixed interval rather than the rendering frame rate.

## Mass balance equation

For any storage node:

```
new_volume = old_volume + inflow - outflow - spill_flow - drain_flow
```

Where all terms have been converted to consistent units (e.g., cubic metres).  Under no circumstances may `new_volume` become negative.  If outflow would exceed the available volume, cap the outflow at the available volume.

## Storage calculations

- **Water depth** is computed as `volume / surface_area` for rectangular basins.  More complex elevation–storage curves may be added later.
- **Water elevation** = `bottom_elevation + water_depth`.
- **Spill elevation** defines the point at which spill_flow starts.  Once a unit reaches or exceeds spill_elevation, excess water must be routed to spill.
- **Minimum operating elevation** defines the lowest usable water surface.  Below this level, outflow automatically stops (low‑low cut‑off).

## Flow calculation modes

Each link between units specifies one of three modes:

1. **Commanded flow** – the controller requests a specific flow; actual flow is the minimum of the request, available supply and capacity.
2. **Restricted flow** – actual flow = `max_flow × valve_opening`.
3. **Simple gravity flow** – actual flow = `flow_coefficient × valve_opening × sqrt(head_difference)`.  Use this only where elevation differences matter.

## Flow constraints

On every update:

- Do not allow flow through a fully closed valve.
- Do not allow flow through disabled equipment.
- Do not allow outflow greater than available water.
- Do not exceed the maximum flow capacity of a link or unit.
- Enforce spill if storage exceeds spill elevation.
- Do not allow negative volume.

## Order of operations

The simulation engine executes each fixed tick in a defined 14-step sequence:

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

> [!NOTE]
> Actuators integrate before controllers evaluate; controller output therefore takes effect on the next tick (intended one-tick scan lag).

## External sources and sinks

External **sources** (e.g., raw‑water reservoirs, system inflow) provide water to the simulation.  They must declare a maximum supply and a current available volume or inflow.  External **sinks** (e.g., system demand, spills) remove water from the simulation and do not accumulate water.

## Numerical tolerances

Because floating‑point arithmetic can introduce minor errors, define an epsilon (e.g., `1e-9`) for volume comparisons.  Consider any volume below epsilon as zero and clamp negative values to zero.

## Valve behaviour

Valves and gates have a **commanded position** and an **actual position**.  The actual position moves toward the commanded position at a specified rate.  Instant movement may be used for debugging but should not be the default.

## Gravity approximation

Use gravity‑based flows only when modelling head differences matters.  Keep the coefficient configurable and allow it to be zero to disable gravity effects entirely.

## Empty and full structures

- If a storage node is empty, its outflow is forced to zero.
- If a storage node is full (at spill elevation), additional inflow becomes spill_flow.

These rules ensure conservation of mass.

## Determinism Mechanics

To guarantee identical results across runs and parity between headless and visual modes:
1. **Tick-Stamped Commands**: Commands are queued and stamped with their target execution tick. They are applied at the absolute start of that tick (Step 1).
2. **Speed Accumulator**: Simulation speed scales *accumulated simulated time*, never the step size `dt` itself. The clock runs as:
   `accumulator_s += frame_delta_s * speed_multiplier`
   Whole fixed-dt ticks are run while `accumulator_s >= dt_s` (capped at `MAX_TICKS_PER_FRAME`). Thus, at `dt = 1.0 s`, `1x` speed is approximately 1 tick per real second, and `60x` is approximately 60 ticks per real second.
3. **Sorted Iteration**: All loops over process units, flow links, and ports iterate over explicitly ordered arrays sorted alphabetically by their unique `StringName` ID. This prevents non-deterministic iteration order from hashing or dictionary traversal.
4. **No Domain RNG**: The domain simulation contains no unseeded random number generation. Any random behavior must use a seeded `RandomNumberGenerator` owned by the simulation context.
5. **Replay Integrity**: A replay consists of the same initial configuration and the same sequence of (tick, command) inputs, yielding identical state trajectories.

## Flow Resolution

To ensure consistent flow calculations and avoid ad-hoc solutions, the simulation implements the following design:

1. **Two-Pass Solver (Phase-2)**: Flow resolution is executed in two passes over a topologically ordered Directed Acyclic Graph (DAG):
   - *Pass 1 (Requests)*: Each unit and link propagates flow requests from downstream to upstream.
   - *Pass 2 (Grants)*: Flows are granted from upstream to downstream. If a source is over-committed, available flow is prorated proportionally among competing downstream requests.
2. **Competing Withdrawals**: Competing withdrawals from a single storage unit (e.g., normal outflow and bottom drain) compete and prorate if the available volume is insufficient to satisfy both.
3. **Passive Spill**: Spill is passive and computed after storage integration. It never competes with active withdrawals.
4. **Hard Boundary — Single-Mutator Rule**: The `FlowSolver` (and related link/port request logic) is strictly read-only regarding stored volume. It calculates requests, applies capacities, and produces granted flows, but *never* modifies the volume of a `StorageUnit`. The `storage_balance.gd` component is the single and exclusive place where volume mutation occurs. It consumes granted flows, performs the integration, and returns the actual resulting outflow, drain, and spill.
5. **Hard Boundary — DAG Constraint**: For Phases 1–5, the hydraulic topology must remain a Directed Acyclic Graph (DAG). Recirculation loops (such as backwash recovery, filter-to-waste returns, return activated sludge, or recycle streams) are explicitly out of scope until a formal cyclic-network resolution strategy is specified.


