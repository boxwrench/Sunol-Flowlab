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

1. **Controller update** – compute commanded flows and valve positions for the current step.
2. **Calculate actual flows** – apply constraints and modes to obtain actual flows.
3. **Update volumes** – apply the mass balance equation to update storage volumes.
4. **Calculate elevations** – compute water depth and elevation from updated volumes.
5. **Generate alarms** – check levels against alarm setpoints and set alarm states.

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
