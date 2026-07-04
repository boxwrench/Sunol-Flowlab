# Decision 0003: SI Internal Units

## Status

Accepted

## Context

The system must handle engineering conversions, but performing simulations using mixed units (such as MGD, MG, feet, hours) is error-prone.

## Decision

The core simulation engine will operate exclusively in standard SI units: volume in cubic meters ($m^3$), flows in cubic meters per second ($m^3/s$), lengths in meters ($m$), and time in seconds ($s$). All conversions to/from US customary units happen in the UI layer.

## Rationale

- Simulating in a single, standard unit system avoids manual conversion factors inside domain logic.
- Standard formulas (e.g. gravity and volume calculations) work out of the box.

## Consequences

- Configuration files and internal snapshots will use SI units.
- Presentation layers must format values before display and convert input setpoints.
