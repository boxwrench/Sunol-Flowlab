# Design: Formal Plant-Definition Schema (Approach A)

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Design proposal for the formal plant-definition schema (Approach A). First committed 2026-07-04.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

Date: 2026-07-04
Status: Approved (design); implementation plan to follow
Audience: primary — repo owner + AI agents maintaining configs through Phases 3–5; secondary (later) — external plant operators via a schema-driven form.

## Goal

Make the plant-definition JSON format a formal, machine-readable contract so that:

1. CI catches malformed configs without launching Godot.
2. Editors (VS Code) autocomplete and validate configs as they are written.
3. A future operator-facing form can be generated directly from the schema (e.g. react-jsonschema-form / JSONForms) with no redesign.
4. `CONFIGURATION_REFERENCE.md` stops drifting from the real rules in `plant_validator.gd`.

## Deliverables

New directory `config/schema/` containing JSON Schema **draft 2020-12** files:

| File | Describes | Field source of truth today |
|---|---|---|
| `defs.schema.json` | Shared `$defs`: ID patterns (TAG_NAMING), SI-suffixed number types, vector3 | TAG_NAMING.md, INTERNAL_UNITS.md |
| `plant.schema.json` | `plant.json` (simulation settings, display units) | `config_loader.gd`, shipped plants |
| `topology.schema.json` | Units, ports, actuators, links | `plant_validator.gd`, domain `initialize()` methods |
| `initial_conditions.schema.json` | Starting volumes, valve/actuator states | `plant_validator.gd`, shipped plants |
| `controllers.schema.json` | Controller definitions (WP2.4 fields: gain, deadband_m, setpoint, min/max_output, control_mode MANUAL\|AUTO, …) | `plant_validator.gd` §4, `controller.gd`, `level_controller.gd`, shipped `controllers.json` |
| `alarms.schema.json` | Alarm definitions (alarm_type HIGH\|LOW, threshold, delay_s, deadband) | `plant_validator.gd` §5, `threshold_alarm.gd` |
| `presentation_map.schema.json` | Optional visuals mapping (see §Visuals) | this design (file not yet consumed by engine) |

Every property carries: `type`, `description` (including physical unit — schemas are the field documentation), range constraints (`minimum`/`exclusiveMinimum`/`maximum`), and `enum` for closed vocabularies (`boundary_type`, `port_type`, `flow_mode`, `control_mode`, `alarm_type`).

## Division of labor (stated in each schema header)

- **JSON Schema owns shape**: types, required keys, ranges, enums, ID lexical patterns.
- **`plant_validator.gd` owns relationships** (runtime authority): duplicate/dangling ID resolution, topology cycle detection, spill-destination resolution to a boundary, geometry consistency (max_volume vs spill_level × area), resolution warnings.

Neither layer duplicates the other's checks. A config can be schema-valid and still be rejected by the runtime validator; it can never be schema-invalid and runtime-valid.

## CI enforcement

Add a job/step to `.github/workflows/tests.yml`, **before** the Godot test job (no engine required):

1. Install `check-jsonschema` (pip).
2. Validate each file in `config/plants/*/` against its schema by filename convention.
3. **Negative guard**: validate `tests/fixtures/schema_invalid/*.json` and assert validation FAILS (protects against a schema so permissive it accepts anything). At least one intentionally broken sample per schema family (wrong type, out-of-range value, unknown enum).

Existing invalid fixtures under `tests/fixtures/` that exercise the GDScript validator's relational checks are NOT schema-validated (they may be schema-valid by design).

Local runner mirror: extend `tools/ci/run_tests.sh` (or a sibling `tools/ci/validate_configs.sh`) so the check runs locally the same way as CI.

## Editor experience

Add a `$schema` key to each shipped config file pointing at the relative schema path. Verify `ConfigLoader`/`PlantValidator` tolerate the unknown key (expected: yes — loaders read specific keys and the validator does not reject unknown keys). Fallback if anything objects: map schemas by path in `.vscode/settings.json` (`json.schemas`) instead of inline keys.

## Visuals: `presentation_map.json` (reserve + default-box rule)

- File is **fully optional** per plant.
- Shape: `{"units": [{"unit_id": <id>, "scene": <res:// path>, "position_m": [x,y,z], "rotation_deg": [x,y,z]}]}` — unit entries themselves optional per unit.
- **Default-box rule (contract only, implemented in WP2.5 or later)**: any unit without an entry is rendered as an auto-generated primitive sized from its simulation geometry (`surface_area_m2`, `spill_level_m`, `bottom_elevation_m`). Consequence: a plant defined purely by filling in simulation fields is renderable in 3D by construction; custom models are progressive enhancement.
- The schema's header documents this rule so WP2.5+ implements against it rather than inventing behavior.

## Documentation & sync discipline

- `CONFIGURATION_REFERENCE.md`: replace the hand-maintained field catalog with a short pointer to `config/schema/` plus the division-of-labor explanation and a worked "define a new plant" walkthrough.
- `AGENTS.md`: add one rule — *any config field addition/change updates the matching schema file and `plant_validator.gd` in the same commit; CI schema validation must pass.*
- No `format_version` field yet (YAGNI). Trigger to add one, noted in CONFIGURATION_REFERENCE: the first time configs are shared outside this repo (operator form launch).

## Error handling

- CI schema failures block merge with the validator's native per-field error messages (path + violated constraint).
- Runtime behavior unchanged: `ConfigLoader`/`PlantValidator` remain the load-time gate inside the engine.

## Testing

- Positive: both shipped plants (`phase1_single_basin`, `phase2_three_unit`) validate clean.
- Negative: `schema_invalid` fixtures fail as asserted in CI.
- Regression: full GUT suite still green (schemas add no runtime code; only `$schema` keys touch loaded files).

## Out of scope

- The operator-facing form/wizard itself.
- Default-box rendering implementation (WP2.5+ presentation work).
- Any change to solver, validator logic, or runtime behavior.
- `format_version` / migration machinery.

## Conflict note

Concurrent WP2.5 (Presentation & Visuals) touches `scenes/` and UI scripts; the only shared file is `.github/workflows/tests.yml` (script-count bump vs new schema step) — trivial merge if collided.
