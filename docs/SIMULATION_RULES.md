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

## Flow Resolution and Proration (Phase 2 Spec)

To ensure consistent flow calculations and avoid ad-hoc solutions, the simulation implements a Directed Acyclic Graph (DAG) topological flow solver. The `FlowSolver` runs a two-pass calculation (downstream-to-upstream requests, upstream-to-downstream grants) to resolve flow allocations deterministically.

### The Two-Pass DAG Solver Algorithm

1. **Pass 1: Propagate Downstream Requests (Downstream to Upstream)**
   - The engine visits units in **reverse topological order** (from sinks to sources).
   - For each unit, it calculates the combined withdrawal request.
   - For each incoming flow link, it calculates the link's requested flow `requested_flow_m3s`.
   - Links in `RESTRICTED` mode request flow based on their actuator's effective opening:
     `requested_flow = max_flow_m3s * actuator.get_effective_opening()`
   - Incoming links propagate these requests upstream to their source ports.

2. **Pass 2: Distribute Upstream Grants (Upstream to Downstream)**
   - The engine visits units in **topological order** (from sources to sinks).
   - For each unit, it determines the total available water supply for the tick:
     `available_supply = current_volume / dt + total_upstream_inflows`
   - It computes the sum of all downstream link requests connected to its outlet/drain ports:
     `total_requested_withdrawal = sum(link.requested_flow)`
   - **Proration Check**:
     - If `total_requested_withdrawal <= available_supply`, all requests are granted in full:
       `link.granted_flow_m3s = link.requested_flow_m3s`
     - If `total_requested_withdrawal > available_supply`, the supply is over-committed. The solver prorates the available supply proportionally among all competing links:
       `proration_factor = available_supply / total_requested_withdrawal`
       `link.granted_flow_m3s = link.requested_flow_m3s * proration_factor`
   - Once all links are resolved, `link.actual_flow_m3s = link.granted_flow_m3s`.
   - **Boundary Flow Limit Enforcement**: If a link connects to or from an `ExternalBoundary` unit with a positive `flow_limit_m3s`, the link's granted flow is capped at the boundary's limit:
     `link.granted_flow_m3s = min(link.granted_flow_m3s, boundary.flow_limit_m3s)`

---

### Worked Examples

#### Example 1: Two Links Competing on a Single Source (Proration)
Suppose we have a single `StorageUnit` (Basin A) with an initial volume of $3.0\text{ m}^3$, and a tick size $\Delta t = 1.0\text{ s}$.
- Basin A has no upstream inflows this tick.
- Total available water for withdrawal is:
  $$V_{\text{avail}} = \frac{3.0\text{ m}^3}{1.0\text{ s}} = 3.0\text{ m}^3/\text{s}$$
- Basin A has two outlet links:
  1. `LINK_OUT_1` (max capacity $4.0\text{ m}^3/\text{s}$, valve is $100\%$ open). Requested flow = $4.0\text{ m}^3/\text{s}$.
  2. `LINK_OUT_2` (max capacity $2.0\text{ m}^3/\text{s}$, valve is $100\%$ open). Requested flow = $2.0\text{ m}^3/\text{s}$.
- The total requested withdrawal is:
  $$Q_{\text{req}} = 4.0 + 2.0 = 6.0\text{ m}^3/\text{s}$$
- Since $Q_{\text{req}} (6.0) > V_{\text{avail}} (3.0)$, proration is triggered.
- The proration factor is:
  $$f_{\text{prorate}} = \frac{V_{\text{avail}}}{Q_{\text{req}}} = \frac{3.0}{6.0} = 0.5$$
- The granted flows are:
  - `LINK_OUT_1.granted_flow_m3s` = $4.0 \times 0.5 = 2.0\text{ m}^3/\text{s}$
  - `LINK_OUT_2.granted_flow_m3s` = $2.0 \times 0.5 = 1.0\text{ m}^3/\text{s}$
- The mass balance integration for Basin A in this tick computes:
  - Total actual withdrawal = $2.0 + 1.0 = 3.0\text{ m}^3/\text{s}$.
  - New volume = $3.0\text{ m}^3 + (0.0 - 3.0\text{ m}^3/\text{s}) \times 1.0\text{ s} = 0.0\text{ m}^3$.
  - Water is perfectly conserved, and no negative storage occurs.

#### Example 2: Junction-as-Small-Storage (Decoupling Algebraic Loops)
In plant hydraulics, splitter boxes or pipe junctions combine or split flows instantly. Representing them as zero-volume algebraic junctions creates algebraic loops (simultaneous equations) when downstream capacities depend on upstream heads, which requires complex iterative solvers and breaks clean DAG execution.

To preserve the pure Directed Acyclic Graph (DAG) and the single-mutator 1D Euler integration design:
- Every physical junction, splitter box, and manifold is modeled as a small `StorageUnit`.
- For example, the `Inlet Manifold` and `Distribution Box` are configured with a very small surface area (e.g., $1.0\text{ m}^2$) and low capacity (e.g., $10.0\text{ m}^3$).
- During each tick, these units integrate their volume using 1D Euler.
- Because they store a small amount of water, any flow mismatch between their inlets and outlets is temporarily buffered as a tiny volume change.
- In the next tick, the modified volume adjusts the head/elevation and influences the downstream request, naturally stabilizing the system.
- This dynamic buffering decouples the algebraic equations across space, allowing the engine to solve the entire plant topology in a single, non-iterative, deterministic two-pass sweep per tick.



