# Configuration Reference

This document explains each field available in the plant configuration JSON files.  Agents and contributors should consult this reference when adding or editing configuration parameters.

## Structure

Configuration files are stored under `config/plants/<plant_id>/`.  The main files are:

- `plant.json` – global plant settings (simulation tick, display units).
- `topology.json` – list of units, ports, links and flow models.
- `initial_conditions.json` – starting volumes, levels, valve positions and unit states.
- `controllers.json` – controller definitions, setpoints, gains and limits.
- `alarms.json` – alarm definitions and setpoints.
- `presentation_map.json` – mapping from unit IDs to scene files and positions.

## Field definitions

Each configuration field must include:

- **Name** – the key used in the JSON.
- **Type** – data type (string, number, boolean, array, object).
- **Unit** – physical unit (if applicable).
- **Required** – whether the field must be present.
- **Default** – default value if not specified.
- **Range** – allowable range or enumerated values.
- **Example** – sample usage.
- **Description** – explanation of the field.

Below are definitions for common fields.  Extend this reference as new fields are added.

### maximum_volume_m3

- **Type:** number
- **Unit:** m³
- **Required:** yes
- **Range:** > 0
- **Example:** 15000
- **Description:** Maximum physical storage before spill calculations begin.

### surface_area_m2

- **Type:** number
- **Unit:** m²
- **Required:** yes
- **Range:** > 0
- **Example:** 8500
- **Description:** Footprint of the storage unit used to compute water depth from volume.

### bottom_elevation_m

- **Type:** number
- **Unit:** m
- **Required:** yes
- **Example:** 125.0
- **Description:** Physical elevation of the bottom of the unit relative to a common datum.

### high_level_m

- **Type:** number
- **Unit:** m
- **Required:** optional
- **Description:** Water elevation at which a high‑level alarm is generated.

### spill_level_m

- **Type:** number
- **Unit:** m
- **Required:** optional
- **Description:** Elevation at which spill flow begins.  Must be ≥ high_level_m.

### max_flow_m3s

- **Type:** number
- **Unit:** m³/s
- **Required:** optional
- **Description:** Maximum allowable flow through this unit or link.

### reverse_flow_allowed

- **Type:** boolean
- **Required:** optional
- **Default:** false
- **Description:** Whether flow is allowed in the reverse direction for this link.

### flow_mode

- **Type:** string
- **Required:** optional
- **Default:** `commanded`
- **Range:** `commanded`, `restricted`, `gravity`
- **Description:** Flow calculation mode for this link.

### display_name

- **Type:** string
- **Required:** yes
- **Description:** Human‑readable name used in the UI.

### position

- **Type:** array of numbers
- **Unit:** metres (x, y, z)
- **Required:** optional
- **Description:** Position of the unit in the 3D scene.  Only used by the presentation layer.

## Extending the reference

When adding new configuration fields, update this document with definitions following the template above.  This ensures that other contributors and AI agents understand the purpose and constraints of each field.
