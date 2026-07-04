# Internal Units

This document defines the internal and display units used in the simulation and establishes naming conventions for variables.  Adhering to consistent units prevents many common simulation errors.

## Internal units

All calculations within the simulation engine use **SI units**:

- **Volume** – cubic metres (m³).
- **Flow** – cubic metres per second (m³/s).
- **Elevation** – metres (m).
- **Time** – seconds (s).

Controllers, storage nodes and flow links must store values in these units.  Never store mixed units in simulation objects.

## Display units

For convenience, the user interface may display values in U.S. customary units:

- **Flow** – million gallons per day (MGD).
- **Volume** – million gallons (MG).
- **Elevation** – feet (ft).
- **Time** – minutes or hours.

Convert between internal and display units in the presentation layer (e.g., UI scripts) using defined conversion constants.

## Conversion constants

Define conversion constants in a central module (e.g., `simulation/core/unit_conversion.gd`).  Examples:

- `CUBIC_METERS_TO_GALLONS = 264.172052`
- `SECONDS_PER_DAY = 86400`

When converting MGD to m³/s, multiply MGD by `gallons_per_day_to_m3s = 0.043812637`.

## Naming conventions

To make it clear which units variables are stored in, append unit suffixes to variable names:

- `_m3` – volume in cubic metres.
- `_m3s` – flow in cubic metres per second.
- `_m` – elevation or depth in metres.
- `_s` – time in seconds.

Examples:

- `volume_m3`
- `flow_m3s`
- `high_level_m`
- `duration_s`

Avoid ambiguous names like `level` or `flow` without units.  In the UI, you may use human‑readable labels without suffixes.

## Rounding and precision

When converting to display units, round flows to three significant figures and levels to two decimal places unless otherwise specified.  Preserve higher precision internally to avoid cumulative errors.

## Storage of display units

Never store MGD, MG or feet directly in simulation objects.  Convert user inputs to internal units as soon as they are captured and convert back to display units when presenting data.
