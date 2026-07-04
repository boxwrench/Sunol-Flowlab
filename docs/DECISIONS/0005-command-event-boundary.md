# Decision 0005: Command/Event Boundary

## Status

Accepted

## Context

We need a clean, decoupled communication interface between the simulation engine and the application/presentation layer, while preserving determinism and preventing side effects during simulation ticks.

## Decision

All state-modifying actions will be sent as tick-stamped `SimulationCommand` objects processed at the start of a tick. All state changes will publish `SimulationEvent` objects collected in the context and flushed at the end of the tick.

## Rationale

- Ensures that UI interactions are deferred to tick boundaries.
- Eliminates mid-tick side effects caused by direct function calls or immediate signal emissions.

## Consequences

- Command classes must be defined for all operator actions (e.g. changing valve position).
- The engine will flush events to the application bus only at the completion of a step.
