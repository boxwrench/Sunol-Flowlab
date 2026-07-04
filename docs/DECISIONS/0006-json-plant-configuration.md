# Decision 0006: JSON Plant Configuration

## Status

Accepted

## Context

The plant topology, equipment settings, and initial conditions must be configurable without modifying the compiled GDScript domain models.

## Decision

Store plant definitions in human-readable JSON files. The engine will boot from a configuration folder containing plant definition, topology, and initial conditions.

## Rationale

- Promotes a data-driven design.
- Simplifies scene configuration and scenario setup.
- Enables validation of plant setups before instantiation.

## Consequences

- A validator component must check configuration validity (e.g. unique IDs, connected links, cyclic loops).
- A factory component must parse JSON data and build RefCounted domain models.
