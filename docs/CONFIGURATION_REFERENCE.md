# Configuration Reference

Plant definitions live under `config/plants/<plant_id>/`. **The field-level
documentation is the JSON Schemas in `config/schema/`** — every property's
type, unit, range, and meaning is defined there and enforced in CI
(`tools/ci/validate_configs.sh`). This file explains how the pieces fit.

## Files per plant

| File | Schema | Required | Purpose |
|---|---|---|---|
| `plant.json` | `plant.schema.json` | yes | Identity + simulation settings (dt) |
| `topology.json` | `topology.schema.json` | yes | Units, ports, actuators, links |
| `initial_conditions.json` | `initial_conditions.schema.json` | yes | Starting volumes and valve states |
| `controllers.json` | `controllers.schema.json` | no | Automation controllers |
| `alarms.json` | `alarms.schema.json` | no | Threshold alarms |
| `presentation_map.json` | `presentation_map.schema.json` | no | Custom visuals; absent units get default boxes |

## Two validation layers

1. **JSON Schema (authoring contract, strict):** shape — types, required
   keys, ranges, enums, ID patterns, unknown-key rejection. Runs in CI
   without Godot and in editors via the `$schema` key. Deliberately
   stricter than the loader: a config the schema rejects may still load
   (e.g. an unknown key is ignored at runtime), but it is not a valid
   authored config.
2. **`plant_validator.gd` (runtime authority, relational):** duplicate and
   dangling IDs, topology cycle detection (DAG constraint), spill
   destination resolution, geometry consistency, resolution warnings.

## Defining a new plant

1. Create `config/plants/<plant_id>/` with `plant.json`, `topology.json`,
   `initial_conditions.json` (start by copying `phase2_three_unit/`).
2. Put a `$schema` key at the top of each file — your editor will
   autocomplete fields and flag mistakes as you type.
3. Run `bash tools/ci/validate_configs.sh` locally.
4. Load the plant in-engine (or via a GUT test) to exercise the runtime
   validator's relational checks.

## Format versioning

There is deliberately no `format_version` field yet. Add one the first time
configs are shared outside this repository (e.g. the operator-facing form).
