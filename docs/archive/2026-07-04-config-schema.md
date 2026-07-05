# Plant-Definition JSON Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Formal JSON Schemas for all six plant-config file types, validated in CI without Godot, per `docs/superpowers/specs/2026-07-04-config-schema-design.md`.

**Architecture:** Seven schema files (six config types + shared `$defs`) live in `config/schema/`. A shell harness validates every shipped plant against them and asserts deliberately-invalid fixtures fail. CI runs the harness in a Godot-free job. Shipped configs gain `$schema` keys for editor autocomplete. Docs are updated to make schemas the field-documentation authority.

**Tech Stack:** JSON Schema draft 2020-12; `check-jsonschema` (Python CLI); bash; GitHub Actions.

## Global Constraints

- Schema dialect: `https://json-schema.org/draft/2020-12/schema` in every schema file.
- Every property must have a `description` including its physical unit where applicable (schemas are the field documentation).
- All object schemas use `"additionalProperties": false` (typo-catching is a core goal). Every root schema explicitly allows an optional `$schema` string property.
- Zero runtime behavior changes: no edits to any `.gd` file. (`$schema` keys in config JSON are data-only additions.)
- Division of labor (state in each schema's root `description`): schema owns shape (types/ranges/enums/required); `plant_validator.gd` owns relationships (dangling IDs, cycles, geometry cross-checks).
- Repo rule: create no files beyond those listed in this plan.
- Verified local Godot binary for the GUT suite: `/home/keith/.gemini/antigravity-cli/scratch/Godot_v4.5-stable_linux.x86_64`.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## File Structure

```text
config/schema/defs.schema.json                    # shared $defs (IDs, numbers, vectors)
config/schema/plant.schema.json                   # plant.json
config/schema/topology.schema.json                # topology.json (units/ports/actuators/links)
config/schema/initial_conditions.schema.json      # initial_conditions.json
config/schema/controllers.schema.json             # controllers.json
config/schema/alarms.schema.json                  # alarms.json
config/schema/presentation_map.schema.json        # presentation_map.json (optional; default-box contract)
tools/ci/validate_configs.sh                      # harness: plants must pass, invalid fixtures must fail
tests/fixtures/schema_invalid/*.json              # one deliberately broken sample per schema family
.github/workflows/tests.yml                       # + Godot-free validation job (modify)
config/plants/*/*.json                            # + "$schema" keys (modify)
docs/CONFIGURATION_REFERENCE.md                   # rewrite as pointer (modify)
AGENTS.md                                         # + sync-discipline rule (modify)
```

Validation is by filename convention: `<name>.json` validates against `config/schema/<name>.schema.json`.

---

### Task 1: Validation harness + defs + plant schema

> **✅ COMPLETE** (commits `ab569a9`→`3c0fb7f`, reviewed). Deviation for all later tasks: **omit the relative `"$id"` line from every schema** — a relative `$id` makes check-jsonschema resolve sibling `$ref`s against process CWD (verified failure mode). `simulation_settings` gained a `description` per Global Constraints.

**Files:**
- Create: `tools/ci/validate_configs.sh`, `config/schema/defs.schema.json`, `config/schema/plant.schema.json`, `tests/fixtures/schema_invalid/plant.json`
- Test: the harness itself (positive: shipped plants pass; negative: invalid fixture fails)

**Interfaces:**
- Produces: `bash tools/ci/validate_configs.sh` → exit 0 iff all shipped configs pass AND all `schema_invalid` fixtures fail. Later tasks add schemas/fixtures; the harness needs no changes.
- Produces: `defs.schema.json#/$defs/{tag_id,display_name,positive_number,non_negative_number,percent,vector3}` consumed by every later schema via relative `$ref`.

- [ ] **Step 1: Install the validator locally**

Run: `pip install --user check-jsonschema && check-jsonschema --version`
Expected: a version string prints (any ≥ 0.27).

- [ ] **Step 2: Write the failing fixture (the "test")**

Create `tests/fixtures/schema_invalid/plant.json`:

```json
{
  "plant_id": "Bad Plant ID With Spaces",
  "display_name": "",
  "simulation_settings": { "default_dt_s": 0 },
  "not_a_real_key": true
}
```

- [ ] **Step 3: Write the harness**

Create `tools/ci/validate_configs.sh`:

```bash
#!/bin/bash
# Validates plant configs against config/schema/*.schema.json.
# Positive: every JSON file in config/plants/*/ must pass its schema.
# Negative: every file in tests/fixtures/schema_invalid/ must FAIL its schema
# (guards against schemas so permissive they accept anything).
set -u
SCHEMA_DIR="config/schema"
fail=0

for f in config/plants/*/*.json; do
  name=$(basename "$f")
  schema="$SCHEMA_DIR/${name%.json}.schema.json"
  if [ ! -f "$schema" ]; then
    echo "FAIL: no schema for $f (expected $schema)"
    fail=1
    continue
  fi
  if check-jsonschema --schemafile "$schema" "$f"; then
    echo "ok: $f"
  else
    echo "FAIL: $f violates $schema"
    fail=1
  fi
done

for f in tests/fixtures/schema_invalid/*.json; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  schema="$SCHEMA_DIR/${name%.json}.schema.json"
  if [ ! -f "$schema" ]; then
    echo "FAIL: no schema for negative fixture $f"
    fail=1
    continue
  fi
  if check-jsonschema --schemafile "$schema" "$f" >/dev/null 2>&1; then
    echo "FAIL: $f unexpectedly PASSED $schema — schema too permissive"
    fail=1
  else
    echo "ok (rejected as intended): $f"
  fi
done

exit $fail
```

Run: `chmod +x tools/ci/validate_configs.sh && bash tools/ci/validate_configs.sh`
Expected: FAIL — "no schema for config/plants/phase1_single_basin/plant.json". This is the red state.

- [ ] **Step 4: Write `config/schema/defs.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "defs.schema.json",
  "title": "Sunol FlowLab shared configuration definitions",
  "description": "Shared $defs referenced by all plant-config schemas. Schemas own SHAPE (types, ranges, enums, required keys); scripts/configuration/plant_validator.gd owns RELATIONSHIPS (dangling IDs, cycle detection, geometry cross-checks).",
  "$defs": {
    "tag_id": {
      "type": "string",
      "pattern": "^[A-Z][A-Z0-9_]*$",
      "description": "Uppercase StringName identifier per docs/TAG_NAMING.md, e.g. BASIN_01, VALVE_IN, LINK_SRC_TO_BASIN_01."
    },
    "display_name": {
      "type": "string",
      "minLength": 1,
      "description": "Human-readable name shown in the UI."
    },
    "positive_number": {
      "type": "number",
      "exclusiveMinimum": 0,
      "description": "Strictly positive number."
    },
    "non_negative_number": {
      "type": "number",
      "minimum": 0,
      "description": "Zero or positive number."
    },
    "percent": {
      "type": "number",
      "minimum": 0,
      "maximum": 100,
      "description": "Percentage in [0, 100]."
    },
    "vector3": {
      "type": "array",
      "items": { "type": "number" },
      "minItems": 3,
      "maxItems": 3,
      "description": "[x, y, z] triple."
    }
  }
}
```

- [ ] **Step 5: Write `config/schema/plant.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "plant.schema.json",
  "title": "plant.json — global plant settings",
  "description": "Global plant identity and simulation settings. Shape only; relational checks live in plant_validator.gd.",
  "type": "object",
  "properties": {
    "$schema": { "type": "string", "description": "Editor hint; ignored by the engine." },
    "plant_id": {
      "type": "string",
      "pattern": "^[a-z0-9_]+$",
      "description": "Snake-case ID matching the directory name under config/plants/."
    },
    "display_name": { "$ref": "defs.schema.json#/$defs/display_name" },
    "simulation_settings": {
      "type": "object",
      "properties": {
        "default_dt_s": {
          "type": "number",
          "exclusiveMinimum": 0,
          "description": "Fixed simulation tick duration [s]. Defaults to 1.0 when absent. Speed multipliers scale accumulated time, never dt."
        }
      },
      "additionalProperties": false
    }
  },
  "required": ["plant_id", "display_name"],
  "additionalProperties": false
}
```

- [ ] **Step 6: Run the harness — plant.json green, others still red**

Run: `bash tools/ci/validate_configs.sh`
Expected: `ok: config/plants/*/plant.json` for both plants; `ok (rejected as intended): tests/fixtures/schema_invalid/plant.json`; still FAILs for topology/initial_conditions (no schema yet — expected until Tasks 2–3).

If check-jsonschema cannot resolve the relative `$ref` to `defs.schema.json` (error mentions unresolvable reference), the fallback is: replace each `"$ref": "defs.schema.json#/$defs/X"` with an inline copy of that def in the referencing schema, and delete `defs.schema.json`. Do not add flags to the harness to work around it.

- [ ] **Step 7: Commit**

```bash
git add tools/ci/validate_configs.sh config/schema/defs.schema.json config/schema/plant.schema.json tests/fixtures/schema_invalid/plant.json
git commit -m "feat(schema): validation harness + defs + plant.json schema

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: topology schema

> **✅ COMPLETE** (commit `f6791dc`, reviewed clean). `$id` omitted per Task 1 deviation.

**Files:**
- Create: `config/schema/topology.schema.json`, `tests/fixtures/schema_invalid/topology.json`

**Interfaces:**
- Consumes: `defs.schema.json#/$defs/{tag_id,display_name,positive_number,non_negative_number}` from Task 1.
- Produces: enums later docs reference — `type: StorageUnit|ExternalBoundary`, `port_type: INLET|OUTLET|DRAIN`, `boundary_type: SOURCE_INFLOW|TREATED_DEMAND|PROCESS_WASTE|DRAIN|SPILL`, `flow_mode: RESTRICTED|COMMANDED`.

- [ ] **Step 1: Write the failing fixture**

Create `tests/fixtures/schema_invalid/topology.json` (three violations: bad enum, missing StorageUnit requireds, negative max_flow):

```json
{
  "units": [
    {
      "unit_id": "BASIN_01",
      "type": "StorageUnit",
      "display_name": "Basin missing all geometry fields"
    },
    {
      "unit_id": "SINK_01",
      "type": "ExternalBoundary",
      "display_name": "Bad boundary type",
      "boundary_type": "NOT_A_CATEGORY"
    }
  ],
  "links": [
    {
      "link_id": "LINK_BAD",
      "max_flow_m3s": -5.0,
      "source_port_id": "PORT_A",
      "destination_port_id": "PORT_B"
    }
  ]
}
```

Run: `bash tools/ci/validate_configs.sh`
Expected: FAIL — "no schema for negative fixture .../topology.json" (red state).

- [ ] **Step 2: Write `config/schema/topology.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "topology.schema.json",
  "title": "topology.json — units, ports, actuators, links",
  "description": "Hydraulic topology. Shape only. plant_validator.gd additionally enforces: unique IDs, dangling port/actuator references, DAG (cycle-free) topology, spill_destination_id resolving to an ExternalBoundary, and geometry consistency (maximum_volume_m3 vs spill_level_m * surface_area_m2).",
  "type": "object",
  "properties": {
    "$schema": { "type": "string", "description": "Editor hint; ignored by the engine." },
    "units": {
      "type": "array",
      "minItems": 1,
      "items": { "$ref": "#/$defs/unit" }
    },
    "actuators": {
      "type": "array",
      "items": { "$ref": "#/$defs/actuator" }
    },
    "links": {
      "type": "array",
      "items": { "$ref": "#/$defs/link" }
    }
  },
  "required": ["units"],
  "additionalProperties": false,
  "$defs": {
    "port": {
      "type": "object",
      "properties": {
        "port_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
        "port_type": {
          "enum": ["INLET", "OUTLET", "DRAIN"],
          "description": "INLET receives flow. OUTLET withdraws only above min_operating_level_m (low-low cutoff). DRAIN withdraws down to zero volume."
        }
      },
      "required": ["port_id", "port_type"],
      "additionalProperties": false
    },
    "unit": {
      "type": "object",
      "properties": {
        "unit_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
        "type": {
          "enum": ["StorageUnit", "ExternalBoundary"],
          "description": "Domain class instantiated by plant_factory.gd."
        },
        "display_name": { "$ref": "defs.schema.json#/$defs/display_name" },
        "maximum_volume_m3": {
          "$ref": "defs.schema.json#/$defs/positive_number",
          "description": "Physical storage capacity [m3]. StorageUnit only."
        },
        "surface_area_m2": {
          "$ref": "defs.schema.json#/$defs/positive_number",
          "description": "Footprint [m2] used to derive level_m = volume_m3 / surface_area_m2. StorageUnit only."
        },
        "bottom_elevation_m": {
          "type": "number",
          "description": "Bottom elevation [m] relative to the plant datum. StorageUnit only."
        },
        "high_level_m": {
          "$ref": "defs.schema.json#/$defs/non_negative_number",
          "description": "Level [m above bottom] for high-level alarming. StorageUnit only."
        },
        "spill_level_m": {
          "$ref": "defs.schema.json#/$defs/non_negative_number",
          "description": "Level [m above bottom] where passive spill begins; must be >= high_level_m (cross-checked at runtime). StorageUnit only."
        },
        "min_operating_level_m": {
          "$ref": "defs.schema.json#/$defs/non_negative_number",
          "description": "Low-low cutoff [m above bottom]; OUTLET ports cannot draw below it (DRAIN ports can). StorageUnit only."
        },
        "spill_destination_id": {
          "$ref": "defs.schema.json#/$defs/tag_id",
          "description": "unit_id of the ExternalBoundary receiving this unit's spill. Required for StorageUnit; no code default exists (Edge Rule 5)."
        },
        "boundary_type": {
          "enum": ["SOURCE_INFLOW", "TREATED_DEMAND", "PROCESS_WASTE", "DRAIN", "SPILL"],
          "description": "Mutually exclusive mass-balance ledger category (INV-1). ExternalBoundary only."
        },
        "flow_limit_m3s": {
          "type": "number",
          "description": "Cap [m3/s] on the boundary's TOTAL flow across all its links; the solver prorates to fit. Negative or absent = unlimited. ExternalBoundary only."
        },
        "ports": {
          "type": "array",
          "items": { "$ref": "#/$defs/port" }
        }
      },
      "required": ["unit_id", "type", "display_name"],
      "additionalProperties": false,
      "allOf": [
        {
          "if": { "properties": { "type": { "const": "StorageUnit" } } },
          "then": {
            "required": [
              "maximum_volume_m3",
              "surface_area_m2",
              "bottom_elevation_m",
              "high_level_m",
              "spill_level_m",
              "min_operating_level_m",
              "spill_destination_id"
            ]
          }
        },
        {
          "if": { "properties": { "type": { "const": "ExternalBoundary" } } },
          "then": { "required": ["boundary_type"] }
        }
      ]
    },
    "actuator": {
      "type": "object",
      "properties": {
        "actuator_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
        "display_name": { "$ref": "defs.schema.json#/$defs/display_name" },
        "opening_rate_percent_per_s": {
          "$ref": "defs.schema.json#/$defs/positive_number",
          "description": "Valve travel rate opening [%/s]; e.g. 5.0 means 0->100% takes 20 s."
        },
        "closing_rate_percent_per_s": {
          "$ref": "defs.schema.json#/$defs/positive_number",
          "description": "Valve travel rate closing [%/s]."
        }
      },
      "required": ["actuator_id"],
      "additionalProperties": false
    },
    "link": {
      "type": "object",
      "properties": {
        "link_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
        "display_name": { "$ref": "defs.schema.json#/$defs/display_name" },
        "max_flow_m3s": {
          "$ref": "defs.schema.json#/$defs/non_negative_number",
          "description": "Hydraulic capacity [m3/s]. RESTRICTED mode requests max_flow_m3s * actuator opening."
        },
        "flow_mode": {
          "enum": ["RESTRICTED", "COMMANDED"],
          "description": "RESTRICTED: flow = capacity x valve opening. COMMANDED: unimplemented — warns at runtime and behaves as RESTRICTED fully open (Edge Rule 6)."
        },
        "source_port_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
        "destination_port_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
        "actuator_id": {
          "$ref": "defs.schema.json#/$defs/tag_id",
          "description": "Valve governing this link. Omit for passive links."
        }
      },
      "required": ["link_id", "max_flow_m3s", "source_port_id", "destination_port_id"],
      "additionalProperties": false
    }
  }
}
```

- [ ] **Step 3: Run the harness**

Run: `bash tools/ci/validate_configs.sh`
Expected: both plants' `topology.json` pass; `schema_invalid/topology.json` rejected as intended; only `initial_conditions.json` still red.

- [ ] **Step 4: Commit**

```bash
git add config/schema/topology.schema.json tests/fixtures/schema_invalid/topology.json
git commit -m "feat(schema): topology.json schema with unit-type conditionals

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: initial_conditions schema

> **✅ COMPLETE** (commit `b27eea1`, reviewed clean). `$id` omitted per Task 1 deviation.

**Files:**
- Create: `config/schema/initial_conditions.schema.json`, `tests/fixtures/schema_invalid/initial_conditions.json`

**Interfaces:**
- Consumes: `defs.schema.json#/$defs/{tag_id,non_negative_number,percent}`.

- [ ] **Step 1: Write the failing fixture**

Create `tests/fixtures/schema_invalid/initial_conditions.json` (violations: negative volume, position out of range):

```json
{
  "unit_states": [
    { "unit_id": "BASIN_01", "in_service": true, "volume_m3": -10.0 }
  ],
  "actuator_states": [
    { "actuator_id": "VALVE_IN", "is_manual": true, "commanded_position": 150.0, "position": 50.0 }
  ]
}
```

Run: `bash tools/ci/validate_configs.sh`
Expected: FAIL — "no schema for negative fixture .../initial_conditions.json".

- [ ] **Step 2: Write `config/schema/initial_conditions.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "initial_conditions.schema.json",
  "title": "initial_conditions.json — starting volumes and actuator states",
  "description": "Initial state applied at plant build. plant_validator.gd additionally enforces: every unit_id/actuator_id resolves to the topology, and initial volume <= maximum_volume_m3.",
  "type": "object",
  "properties": {
    "$schema": { "type": "string", "description": "Editor hint; ignored by the engine." },
    "unit_states": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "unit_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
          "in_service": { "type": "boolean", "description": "Whether the unit participates in the simulation at t=0." },
          "volume_m3": {
            "$ref": "defs.schema.json#/$defs/non_negative_number",
            "description": "Starting stored volume [m3]. StorageUnit only; must not exceed maximum_volume_m3 (runtime cross-check)."
          }
        },
        "required": ["unit_id"],
        "additionalProperties": false
      }
    },
    "actuator_states": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "actuator_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
          "is_manual": { "type": "boolean", "description": "True when the valve starts under manual control." },
          "commanded_position": {
            "$ref": "defs.schema.json#/$defs/percent",
            "description": "Target valve position [%]."
          },
          "position": {
            "$ref": "defs.schema.json#/$defs/percent",
            "description": "Actual valve position at t=0 [%]."
          }
        },
        "required": ["actuator_id"],
        "additionalProperties": false
      }
    }
  },
  "required": ["unit_states"],
  "additionalProperties": false
}
```

- [ ] **Step 3: Run the harness**

Run: `bash tools/ci/validate_configs.sh`
Expected: both plants' `initial_conditions.json` pass and the negative fixture is rejected. Overall exit is still 1: phase2's shipped `controllers.json`/`alarms.json` report "no schema" until Task 4 — that is the only remaining red.

- [ ] **Step 4: Commit**

```bash
git add config/schema/initial_conditions.schema.json tests/fixtures/schema_invalid/initial_conditions.json
git commit -m "feat(schema): initial_conditions.json schema

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: controllers + alarms schemas

> **✅ COMPLETE** (commits `9e45d97`+`7250895`, reviewed). Harness first full green (exit 0). Second sweep added `description` to all array-container properties across schemas (plan template gap); Task 5's `units` property must carry one too.

**Files:**
- Create: `config/schema/controllers.schema.json`, `config/schema/alarms.schema.json`, `tests/fixtures/schema_invalid/controllers.json`, `tests/fixtures/schema_invalid/alarms.json`

**Interfaces:**
- Consumes: `defs.schema.json#/$defs/{tag_id,display_name,non_negative_number,percent}`.
- Field authority: `plant_validator.gd` sections 4–5 and shipped `config/plants/phase2_three_unit/controllers.json`.

- [ ] **Step 1: Write the failing fixtures**

Create `tests/fixtures/schema_invalid/controllers.json` (violations: zero gain, negative deadband, bad mode):

```json
{
  "controllers": [
    {
      "controller_id": "LC_BAD",
      "type": "LevelController",
      "display_name": "Bad Controller",
      "target_actuator_id": "VALVE_X",
      "pv_unit_id": "BASIN_01",
      "pv_property": "level_m",
      "control_mode": "TURBO",
      "setpoint": 5.0,
      "gain": 0.0,
      "deadband_m": -0.1,
      "min_output": 0.0,
      "max_output": 100.0
    }
  ]
}
```

Create `tests/fixtures/schema_invalid/alarms.json` (violations: bad alarm_type, negative delay):

```json
{
  "alarms": [
    {
      "alarm_id": "ALM_BAD",
      "display_name": "Bad Alarm",
      "target_unit_id": "BASIN_01",
      "target_property": "level_m",
      "alarm_type": "MEDIUM",
      "threshold_value": 9.0,
      "delay_s": -5.0,
      "deadband": 0.1
    }
  ]
}
```

Run: `bash tools/ci/validate_configs.sh`
Expected: FAIL — no schema for the two new negative fixtures (and for phase2's shipped `controllers.json`/`alarms.json`).

- [ ] **Step 2: Write `config/schema/controllers.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "controllers.schema.json",
  "title": "controllers.json — automation controller definitions",
  "description": "Controllers evaluated at tick step 4. plant_validator.gd additionally enforces: target_actuator_id and pv_unit_id resolve to the topology, and min_output < max_output. FORCED/FAILED modes are deferred; only MANUAL and AUTO are valid.",
  "type": "object",
  "properties": {
    "$schema": { "type": "string", "description": "Editor hint; ignored by the engine." },
    "controllers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "controller_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
          "type": {
            "enum": ["LevelController"],
            "description": "Controller class instantiated by plant_factory.gd."
          },
          "display_name": { "$ref": "defs.schema.json#/$defs/display_name" },
          "target_actuator_id": {
            "$ref": "defs.schema.json#/$defs/tag_id",
            "description": "Valve whose commanded_position this controller drives in AUTO."
          },
          "pv_unit_id": {
            "$ref": "defs.schema.json#/$defs/tag_id",
            "description": "Unit providing the process variable."
          },
          "pv_property": {
            "type": "string",
            "examples": ["level_m"],
            "description": "Snapshot property read as the process variable."
          },
          "control_mode": {
            "enum": ["MANUAL", "AUTO"],
            "description": "Starting mode. MANUAL: evaluate() does nothing. AUTO: proportional control with deadband."
          },
          "setpoint": {
            "type": "number",
            "description": "Target process-variable value (units of pv_property, e.g. [m] for level_m)."
          },
          "gain": {
            "type": "number",
            "exclusiveMinimum": 0,
            "description": "Proportional gain: output_delta = gain * error."
          },
          "deadband_m": {
            "$ref": "defs.schema.json#/$defs/non_negative_number",
            "description": "Half-width [m] of the no-action zone around zero error; output holds inside it."
          },
          "min_output": {
            "$ref": "defs.schema.json#/$defs/percent",
            "description": "Output clamp floor [%]. Must be < max_output (runtime cross-check)."
          },
          "max_output": {
            "$ref": "defs.schema.json#/$defs/percent",
            "description": "Output clamp ceiling [%]."
          }
        },
        "required": [
          "controller_id", "type", "display_name", "target_actuator_id",
          "pv_unit_id", "pv_property", "control_mode", "setpoint",
          "gain", "deadband_m", "min_output", "max_output"
        ],
        "additionalProperties": false
      }
    }
  },
  "required": ["controllers"],
  "additionalProperties": false
}
```

- [ ] **Step 3: Write `config/schema/alarms.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "alarms.schema.json",
  "title": "alarms.json — threshold alarm definitions",
  "description": "Threshold alarms evaluated at tick step 11. plant_validator.gd additionally enforces: target_unit_id resolves to the topology.",
  "type": "object",
  "properties": {
    "$schema": { "type": "string", "description": "Editor hint; ignored by the engine." },
    "alarms": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "alarm_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
          "display_name": { "$ref": "defs.schema.json#/$defs/display_name" },
          "target_unit_id": {
            "$ref": "defs.schema.json#/$defs/tag_id",
            "description": "Unit whose property is monitored."
          },
          "target_property": {
            "type": "string",
            "examples": ["level_m"],
            "description": "Property monitored against the threshold."
          },
          "alarm_type": {
            "enum": ["HIGH", "LOW"],
            "description": "HIGH activates when value >= threshold; LOW when value <= threshold."
          },
          "threshold_value": {
            "type": "number",
            "description": "Activation threshold (units of target_property)."
          },
          "delay_s": {
            "$ref": "defs.schema.json#/$defs/non_negative_number",
            "description": "Seconds the condition must persist before activation."
          },
          "deadband": {
            "$ref": "defs.schema.json#/$defs/non_negative_number",
            "description": "Hysteresis band (units of target_property) the value must clear past the threshold before the alarm resets."
          }
        },
        "required": [
          "alarm_id", "display_name", "target_unit_id", "target_property",
          "alarm_type", "threshold_value", "delay_s", "deadband"
        ],
        "additionalProperties": false
      }
    }
  },
  "required": ["alarms"],
  "additionalProperties": false
}
```

- [ ] **Step 4: Run the harness**

Run: `bash tools/ci/validate_configs.sh`
Expected: exit 0 — all shipped configs pass, all five negative fixtures rejected.

- [ ] **Step 5: Commit**

```bash
git add config/schema/controllers.schema.json config/schema/alarms.schema.json tests/fixtures/schema_invalid/controllers.json tests/fixtures/schema_invalid/alarms.json
git commit -m "feat(schema): controllers.json and alarms.json schemas

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: presentation_map schema (default-box contract)

> **✅ COMPLETE** (commit `fdd26cb`, reviewed clean). Both deviations applied ($id omitted; units description added).

**Files:**
- Create: `config/schema/presentation_map.schema.json`, `tests/fixtures/schema_invalid/presentation_map.json`

**Interfaces:**
- Consumes: `defs.schema.json#/$defs/{tag_id,vector3}`.
- Produces: the visuals contract WP2.5+ presentation code implements against. No engine code consumes this file yet — the schema is the reservation.

- [ ] **Step 1: Write the failing fixture**

Create `tests/fixtures/schema_invalid/presentation_map.json` (violations: non-res:// scene path, 2-element position):

```json
{
  "units": [
    { "unit_id": "BASIN_01", "scene": "C:/models/basin.glb", "position_m": [1.0, 2.0] }
  ]
}
```

Run: `bash tools/ci/validate_configs.sh`
Expected: FAIL — "no schema for negative fixture .../presentation_map.json".

- [ ] **Step 2: Write `config/schema/presentation_map.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "presentation_map.schema.json",
  "title": "presentation_map.json — optional visuals mapping",
  "description": "OPTIONAL per plant. Maps unit_ids to custom scenes and placements. DEFAULT-BOX RULE (contract; implementation lands with presentation work, WP2.5+): any unit with no entry here is rendered as an auto-generated primitive sized from its simulation geometry (surface_area_m2, spill_level_m, bottom_elevation_m). A plant defined purely by simulation fields is therefore renderable in 3D by construction; custom models are progressive enhancement. Visual adapters remain read-only over snapshots (INV-3) — nothing in this file affects simulation results.",
  "type": "object",
  "properties": {
    "$schema": { "type": "string", "description": "Editor hint; ignored by the engine." },
    "units": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "unit_id": { "$ref": "defs.schema.json#/$defs/tag_id" },
          "scene": {
            "type": "string",
            "pattern": "^res://.+\\.tscn$",
            "description": "Godot scene rendered for this unit. Omit to get the default box."
          },
          "position_m": {
            "$ref": "defs.schema.json#/$defs/vector3",
            "description": "World position [m], Godot axes (Y up)."
          },
          "rotation_deg": {
            "$ref": "defs.schema.json#/$defs/vector3",
            "description": "Euler rotation [degrees] around X, Y, Z."
          }
        },
        "required": ["unit_id"],
        "additionalProperties": false
      }
    }
  },
  "required": ["units"],
  "additionalProperties": false
}
```

- [ ] **Step 3: Run the harness**

Run: `bash tools/ci/validate_configs.sh`
Expected: exit 0 (no shipped plant has a presentation_map.json yet; the negative fixture is rejected).

- [ ] **Step 4: Commit**

```bash
git add config/schema/presentation_map.schema.json tests/fixtures/schema_invalid/presentation_map.json
git commit -m "feat(schema): presentation_map.json schema with default-box contract

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: `$schema` keys in shipped configs + engine regression

> **✅ COMPLETE** (commit `c6f9075`, reviewed clean). Engine accepts the keys — GUT 21 scripts / 52 tests / 0 failures; no .vscode fallback needed.

**Files:**
- Modify: all 8 shipped config files — `config/plants/phase1_single_basin/{plant,topology,initial_conditions}.json`, `config/plants/phase2_three_unit/{plant,topology,initial_conditions,controllers,alarms}.json`

**Interfaces:**
- Consumes: schemas from Tasks 1–4. Relative path from a plant dir to the schemas is `../../schema/`.

- [ ] **Step 1: Add the `$schema` key to every shipped config file**

Add as the first key of the root object in each file, pointing at its schema. Example for `config/plants/phase2_three_unit/topology.json`:

```json
{
  "$schema": "../../schema/topology.schema.json",
  "units": [
```

Repeat for each file with the matching schema name (`plant.schema.json`, `initial_conditions.schema.json`, `controllers.schema.json`, `alarms.schema.json`).

- [ ] **Step 2: Run the schema harness**

Run: `bash tools/ci/validate_configs.sh`
Expected: exit 0 (root schemas explicitly allow the `$schema` property).

- [ ] **Step 3: Run the full GUT suite — proves the engine tolerates the new key**

Run: `/home/keith/.gemini/antigravity-cli/scratch/Godot_v4.5-stable_linux.x86_64 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all tests pass with the same script/test counts as current main (21 scripts / 52 tests as of this writing; more if WP2.6 has landed — the requirement is 0 failures).

If any test fails because a loader/validator rejects the unknown `$schema` key: revert Step 1 entirely, and instead create `.vscode/settings.json` mapping schemas by path:

```json
{
  "json.schemas": [
    { "fileMatch": ["config/plants/*/plant.json"], "url": "./config/schema/plant.schema.json" },
    { "fileMatch": ["config/plants/*/topology.json"], "url": "./config/schema/topology.schema.json" },
    { "fileMatch": ["config/plants/*/initial_conditions.json"], "url": "./config/schema/initial_conditions.schema.json" },
    { "fileMatch": ["config/plants/*/controllers.json"], "url": "./config/schema/controllers.schema.json" },
    { "fileMatch": ["config/plants/*/alarms.json"], "url": "./config/schema/alarms.schema.json" },
    { "fileMatch": ["config/plants/*/presentation_map.json"], "url": "./config/schema/presentation_map.schema.json" }
  ]
}
```

- [ ] **Step 4: Commit**

```bash
git add config/plants/
git commit -m "feat(schema): \$schema editor keys in shipped plant configs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: CI job + documentation

**Files:**
- Modify: `.github/workflows/tests.yml`, `docs/CONFIGURATION_REFERENCE.md`, `AGENTS.md`

**Interfaces:**
- Consumes: `tools/ci/validate_configs.sh` (Task 1).

- [ ] **Step 1: Add a Godot-free validation job to `.github/workflows/tests.yml`**

Append as a sibling of the existing test job (keep the existing job untouched — WP2.6 may be editing it concurrently; appending a new job minimizes merge conflicts):

```yaml
  config-schema:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install check-jsonschema
        run: pip install check-jsonschema
      - name: Validate plant configs against schemas
        run: bash tools/ci/validate_configs.sh
```

Match the file's existing indentation exactly (the job key sits at the same depth as the existing job under `jobs:`).

- [ ] **Step 2: Rewrite `docs/CONFIGURATION_REFERENCE.md`**

Replace the entire file body with (keep the H1 title):

```markdown
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
```

- [ ] **Step 3: Add the sync rule to `AGENTS.md`**

Read the "Verification and failure-mode guardrails" numbered list in `AGENTS.md` and append the next-numbered rule (13 as of this writing — renumber if more have been added):

```markdown
13. **Config schema sync.** Any addition or change to a plant-config field updates the matching schema in `config/schema/` and `scripts/configuration/plant_validator.gd` in the same commit. `tools/ci/validate_configs.sh` must pass. Field documentation lives in the schema `description` — do not duplicate it in prose docs.
```

- [ ] **Step 4: Final verification — both harnesses green**

Run: `bash tools/ci/validate_configs.sh && /home/keith/.gemini/antigravity-cli/scratch/Godot_v4.5-stable_linux.x86_64 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: schema harness exits 0; GUT suite 0 failures.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/tests.yml docs/CONFIGURATION_REFERENCE.md AGENTS.md
git commit -m "ci+docs: schema validation job, CONFIGURATION_REFERENCE rewrite, AGENTS sync rule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
