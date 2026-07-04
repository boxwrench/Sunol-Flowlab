# Decision 0004: Separation of Simulation and Presentation

## Status

Accepted

## Context

To run tests in continuous integration environments and to guarantee that graphics and rendering do not affect simulation states, simulation code must be independent of visual components.

## Decision

The simulation domain layer will be written using Godot `RefCounted` scripts that have no reference to the scene tree, Node classes, UI, or autoloads. Presentation classes (Nodes/scenes) will pull snapshots and send commands but never run simulation logic.

## Rationale

- Allows headless unit and integration testing without launching the Godot engine GUI.
- Enforces a clear architectural boundary.

## Consequences

- Domain objects cannot inherit from `Node` or use `@onready` variables.
- Visual elements must use adapters to read from read-only state snapshots.
