# Project Scope

This document defines what belongs in the proof‑of‑concept drinking water plant digital twin, and what does not.  It serves as the guardrail for development and helps prevent scope creep.

## Goals

- Build a **sandbox simulation** of a surface‑water treatment plant using Godot 4.x.
- Represent the plant as a network of modular process units (reservoirs, basins, filters, clearwells and reservoirs).
- Allow users to adjust flows, valve positions and equipment states and observe how water levels and flows change.
- Provide a clean, low‑poly 3D view with adjustable camera, overlays and simple trends.
- Support manual and automatic control modes with editable setpoints.
- Enforce mass conservation and flow constraints at every connection.
- Provide alarms and simple control logic to respond to high/low level conditions.

## Current process train

The proof of concept models the following sequence of units:

1. Two surface water reservoirs feeding an inlet manifold.
2. A flash mixer for coagulant dosing.
3. A distribution box that splits flow into five sedimentation/flocculation basins.
4. An applied channel that combines basin effluent and feeds twelve filters.
5. A clearwell combining filter effluent.
6. Two chlorine contact time basins in parallel.
7. A treated‑water reservoir from which system demand is drawn.

## Required sandbox behaviours

The simulation must:

- Conserve water mass across all units.
- Respect maximum flows, valve positions and equipment availability.
- Spill water when storage exceeds the defined spill elevation.
- Drain water when commanded or when units are taken out of service.
- Redistribute flow when basins or filters are unavailable.
- Generate high‑level and low‑level alarms.
- Allow manual override of automatic control.
- Allow the simulation to be paused, stepped, sped up and reset.

## Explicit exclusions

The following features are **out of scope** for the proof of concept:

- Computational fluid dynamics (CFD) or pressure‑network solvers.
- Detailed pump curves and head loss calculations.
- Chemistry models (coagulant optimisation, turbidity removal, chlorine residual).
- Regulatory CT calculations.
- Live SCADA or PLC integration.
- Multiplayer or scoring.

These may be added in a future phase if the architecture supports them.

## Future features not to build yet

Do not implement the following until after the proof‑of‑concept is stable:

- Filter backwash and filter‑to‑waste sequences.
- Raw‑water quality changes and dose optimisation.
- Detailed settling performance.
- Backwash waste handling.
- Air scour and surface wash.
- Media condition tracking and run‑length optimisation.
- Cyber‑physical attack scenarios or training modules.

## Completion criteria

The proof of concept is considered complete when:

- The entire plant process train is represented with modular units.
- Each storage unit has a visible and numerically correct water level.
- Valves and gates affect flows and enforce capacity limits.
- Equipment can be placed in and out of service.
- Flow can be redistributed across five basins and twelve filters.
- Spills and drain‑downs occur correctly.
- Manual and automatic control modes work.
- Alarms activate and clear correctly.
- The simulation can be paused, accelerated, reset and stepped.
- The user can select and inspect every process unit.
- The full plant can run for an extended period without creating or destroying water.
