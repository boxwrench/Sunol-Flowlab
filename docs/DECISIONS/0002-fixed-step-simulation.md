# Decision 0002: Fixed-Step Simulation

## Status

Accepted

## Context

To ensure simulation stability, determinism, and reproducibility, the simulation clock must not depend on the variable rendering frame rate.

## Decision

The simulation engine will run on a fixed step size (`dt` = 1.0s by default). The simulation host will update the simulation state using a custom time accumulator.

## Rationale

- Fixed-step integration prevents numerical instabilities and ensures conservation of mass.
- Visual frame rate jitter does not affect simulation calculations.
- Replaying the same command sequence yields bit-identical results.

## Consequences

- The simulation does not run directly in Godot's `_process()` or `_physics_process()`.
- A time accumulator loop must run in the host adapter.
- The simulation can be accelerated (e.g., 60x) by running multiple simulation ticks in a single render frame.
