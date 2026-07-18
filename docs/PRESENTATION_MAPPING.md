# Presentation Mapping Contract

This document defines how simulation state may be translated into 3D visuals and UI.
It is binding on presentation and UI code. `REPOSITORY_ARCHITECTURE.md` remains the
authority on structure and dependency direction.

## Purpose

The presentation must make the simplified hydraulic model legible without implying
physics, precision, alarms, or process behavior that the simulation does not contain.
The proof of concept deliberately targets high functional fidelity, low physical
fidelity, and focused visual polish. Low-poly geometry and simple water surfaces are
therefore intentional. Photorealistic water, plant clutter, detailed pipe routing, and
ambient motion are not proof-of-concept requirements.

## Snapshot authority

- Every data-bearing visual and UI readout for a rendered update must derive from one
  immutable, completed simulation snapshot.
- A visual must not read a domain object, autoload, scene-local simulation value, or a
  second snapshot path to supplement that snapshot.
- Redundant views of one value, such as water height and numeric level, must use the same
  snapshot tick and the same SI source field. Display-unit conversion occurs only at the
  UI boundary.
- Presentation interpolation may smooth motion between snapshots, but it must not alter
  numeric readouts, lead the newest completed snapshot, or feed state back into the
  simulation.

## Encoding rules

1. Quantitative values use position or length as their primary visual channel where
   practical. Numeric text supplies units and precision.
2. Every quantitative mapping is monotone over its declared operating range. Increasing
   model values must never produce a decreasing visual indication unless direction is
   explicitly part of the contract.
3. Zero flow produces zero flow animation. Reversed flow animation is prohibited: the
   simulation link contract does not support reverse flow (the topology is a DAG).
4. Water-surface elevation comes directly from snapshot `level_m` or
   `water_surface_elevation_m`; presentation code must not recompute level from volume.
5. Valve pose represents actual actuator position, not commanded position. A separate
   command indication may be shown when it is clearly labelled.
6. Controller mode uses text (`AUTO`/`MANUAL`) plus a non-color cue. Mode is categorical,
   not a continuous color scale.
7. Color is reserved for exceptions and categorical distinctions. It must not be the
   only carrier of alarm, availability, mode, or service state. Alarm presentation must
   correspond to alarm state present in the snapshot.
8. Normal backgrounds and non-data scene elements remain low contrast and visually
   subordinate. Ambient animation must not resemble process motion.
9. Comparable repeated units use common scales where practical. If scales differ, each
   scale must be visible and the views must not invite direct height comparison.
10. Time acceleration is always labelled with the active multiplier. It changes how
    quickly fixed ticks are presented, never the fixed simulation step.

## Current mappings

| Model state | Primary mapping | Required redundant cue |
|-------------|-----------------|------------------------|
| Storage level | Water-surface position on the unit's declared scale | Numeric level with units |
| Link flow | Directional motion or length, proportional within a declared bounded range | Numeric flow with units when inspected |
| Actuator position | Valve/gate pose proportional to actual position | Numeric percent when inspected |
| Controller mode | `AUTO` or `MANUAL` text | Shape, icon, or faceplate style |
| Unit service state | Text or stable shape/style change | Color may supplement, never replace it |
| Alarm state | Alarm text and symbol | Priority color may supplement it |
| Mass-balance residual | Numeric value with tolerance context | Trend only when a trend buffer is in scope |

## Declared visual exaggeration

A visual may render an otherwise invisible state, such as flow inside an opaque pipe, or
use representative particles rather than literal water parcels. Each such mapping must
be documented beside the adapter or shader with:

- the snapshot source field;
- the mapping function and units;
- its bounded display range;
- its zero behavior and direction behavior;
- any render-only lag or interpolation.

The mapping must remain monotone, bounded, and subordinate to the model value. Decorative
turbulence, particles moving at zero flow, or color changes that imply unmodeled water
quality are prohibited.

## Validation

Presentation work must be tested independently from hydraulic correctness:

- **Monotonicity:** sweep the source field and assert that water height, pointer position,
  valve pose, or animation rate changes with the correct sign and reaches its defined
  zero/floor state.
- **Synchronization:** inject a step change and assert all redundant indications use the
  same snapshot tick, unless a bounded render-only lag is declared and tested.
- **Source integrity:** verify adapters consume snapshot dictionaries and do not mutate
  domain state. Headless and visual runs given identical commands must end in identical
  simulation snapshots.
- **Range and units:** test endpoints, clamping behavior, unit labels, and display-unit
  conversion. Presentation clamping must not conceal an out-of-range model value; the UI
  must still expose the value or exception.
- **Human legibility:** before treating a new encoding as a release criterion, perform a
  small blind-read check: with numbers hidden, users should correctly rank displayed
  levels/flows and identify modes and alarms. Record the task, sample, and result rather
  than adopting a universal percentage threshold.

These checks belong in `tests/unit/presentation/` or the relevant visual integration
suite. They must instantiate production adapters and mappings rather than reproduce them
in test doubles.

## Scope boundaries

This contract does not authorize new simulation observables. Turbidity, water-quality
transport, regulatory CT, tracer residence-time models, pump energy/cost, detailed alarm
management, trend infrastructure, and photorealistic water remain excluded or
trigger-gated by `PROJECT_SCOPE.md`, `KNOWN_LIMITATIONS.md`, and `ROADMAP.md`. A visual
channel for any of them requires a real model field or explicitly documented surrogate
before presentation work begins.

## Research basis

This contract distills the supplied mapping/fidelity research into repository rules. Its
design rationale is consistent with ISA-101 exception-oriented HMI design; the
high-performance-HMI practice of contextual, low-clutter displays; Cleveland and
McGill's preference for position and length over area, volume, and color for quantitative
judgment; and educational-simulation findings favoring functional alignment and coherent
representations over photorealism. These references motivate the contract but do not
override repository scope, executable behavior, or the canonical architecture.
