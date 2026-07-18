# WP3.6 Config Schema Sync — Kickoff Prompt (historical)

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Kickoff cold-start prompt for WP3.6 config schema sync. First committed 2026-07-04.
> Written as a cold-start prompt — it is not a live instruction. Do not execute it.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

[ROLE]
You are the implementation agent for Sunol FlowLab, a deterministic Godot 4.x / GDScript
drinking-water simulator. Work from the repository's actual committed code and
`docs/PHASE3_IMPLEMENTATION_PLAN.md` — not from any prior chat summary. Follow AGENTS.md exactly.

[REPOSITORY]  C:\Github\Sunol FlowLab   —   HEAD = `ee2716b` (WP3.5)

[REVIEWER PRE-FLIGHT — already verified against committed objects, so DON'T redo it]
Most of WP3.6 is ALREADY DONE at ee2716b. Confirmed present and correct:
- `in_service` is defined in `config/schema/topology.schema.json` (unit def) AND in
  `initial_conditions.schema.json`.
- `plant_validator.gd` already has the explicit `in_service` boolean type-check
  (`if unit_dict.has("in_service") and typeof(...) != TYPE_BOOL: errors.append(...)`).
- Every field used across all phase3_headworks configs already has a schema entry.
- The `simulation_resolution_warning` (`max_flow*dt > 0.2*max_vol`) already exists.
- The forbidden **P3-A5 inverted heuristic is absent** (the surface_area/volume logic present is
  legitimate consistency checking, not the banned `surface_area_m2>1 AND maximum_volume_m3<=10`).
- `presentation_map.schema.json` exists; NO plant has a `presentation_map.json` yet.

Therefore WP3.6 reduces to ONE real deliverable + verification. Do NOT re-scope it larger.

[DO NOT — explicit anti-scope]
- Do NOT add the P3-A5 heuristic (`surface_area_m2 > 1.0 AND maximum_volume_m3 <= 10.0`). Banned.
- Do NOT inject `in_service` into every topology unit — it is schema-optional and defaults true
  by design; the precedence tests rely on omission.
- Do NOT touch runtime out-of-service logic (that was WP3.3, already done).
- Do NOT edit `tools/ci/validate_configs.sh` — it already auto-discovers new plant JSON by glob
  (`config/plants/*/*.json`) and maps by basename to `config/schema/<name>.schema.json`. A new
  `presentation_map.json` is picked up and validated automatically.
- No domain/solver changes, no scene/.tscn work (that is WP3.8). Do not modify review-verdict docs.

[FIRST — housekeeping]
1. Confirm a clean tree (Windows git): `git status --short` should show only the untracked
   task-brief markdown files. If anything else is modified, stop and report.
2. Ensure your own git identity is set (recent commits were authored as throwaway `reviewer@local`).
3. Clear the WP3.4/3.5 test debt — run and PASTE the summaries:
   ```
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/phase3_headworks -ginclude_subdirs -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
   ```
   If any of the five WP3.4/3.5 tests fail, fix the underlying WP3.4/3.5 defect in its OWN commit
   (`WP3.4:` / `WP3.5:`) BEFORE starting WP3.6. Do not build WP3.6 on red tests.

[THE ONE DELIVERABLE — create config/plants/phase3_headworks/presentation_map.json]

Schema contract (from config/schema/presentation_map.schema.json, verified):
- Top level is an OBJECT with a required `"units"` array. `additionalProperties: false` at top
  level AND per entry — unknown fields are rejected.
- Each entry: `unit_id` (REQUIRED, pattern `^[A-Z][A-Z0-9_]*$`), and optional `scene`
  (pattern `^res://.+\.tscn$`), `position_m` ([x,y,z] exactly 3 numbers), `rotation_deg`
  ([x,y,z] exactly 3 numbers). Godot axes, Y up.
- OMIT `scene` for now — no .tscn assets exist until WP3.8; absent scene = default box. Adding a
  res:// path to a nonexistent scene is allowed by schema but pointless; leave it out.

Use this ready-to-write file verbatim (covers the full headworks wet path with a simple layout;
all unit_ids exist in topology.json at ee2716b):

```json
{
  "$schema": "../../schema/presentation_map.schema.json",
  "units": [
    { "unit_id": "EXTERNAL_SOURCE_01", "position_m": [-10.0, 0.0, -5.0] },
    { "unit_id": "EXTERNAL_SOURCE_02", "position_m": [-10.0, 0.0, 5.0] },
    { "unit_id": "RESERVOIR_01", "position_m": [0.0, 0.0, -5.0] },
    { "unit_id": "RESERVOIR_02", "position_m": [0.0, 0.0, 5.0] },
    { "unit_id": "MANIFOLD_01", "position_m": [10.0, 0.0, 0.0] },
    { "unit_id": "FLASH_MIX_01", "position_m": [20.0, 0.0, 0.0] },
    { "unit_id": "DIST_BOX_01", "position_m": [30.0, 0.0, 0.0] },
    { "unit_id": "BASIN_01", "position_m": [40.0, 0.0, -10.0] },
    { "unit_id": "BASIN_02", "position_m": [40.0, 0.0, -5.0] },
    { "unit_id": "BASIN_03", "position_m": [40.0, 0.0, 0.0] },
    { "unit_id": "BASIN_04", "position_m": [40.0, 0.0, 5.0] },
    { "unit_id": "BASIN_05", "position_m": [40.0, 0.0, 10.0] },
    { "unit_id": "APPLIED_CHANNEL_01", "position_m": [50.0, 0.0, 0.0] },
    { "unit_id": "FILTER_FEED_01", "position_m": [60.0, 0.0, 0.0] },
    { "unit_id": "DRAIN_SINK", "position_m": [40.0, -5.0, 20.0] },
    { "unit_id": "SPILL_SINK", "position_m": [50.0, 5.0, 20.0] }
  ]
}
```

Before committing, re-list the actual units in `config/plants/phase3_headworks/topology.json`
and confirm every `unit_id` above still exists (correct any that drifted). The map need not cover
every unit, but any listed unit_id should be real.

[VERIFICATION — run and paste exact output]
1. `bash tools/ci/validate_configs.sh` → exit 0. `config/plants/phase3_headworks/presentation_map.json`
   reports `ok`; all phase1/phase2/phase3 positive configs still `ok`; all schema_invalid fixtures
   still `rejected as intended`. (If `check-jsonschema` is not installed, the script exits 1 with
   "FAIL: check-jsonschema not installed" — report that exact state, do not claim it passed.)
2. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
   → 0 failing, no parse errors, no skipped scripts. Paste Scripts/Tests/Passing/Failing counts.
3. `git diff --check` and `git status --short` → clean.

[HANDOFF]
Commit with a message beginning `WP3.6:`. Report: the accumulated Phase 3 test summaries from
housekeeping, the validate_configs output, the full-suite runner summary, and changed files.
State explicitly that (a) the P3-A5 heuristic was NOT added and (b) validate_configs.sh was NOT
edited (auto-discovery). Update CHANGELOG.md with the WP3.6 entry. Leave a clean working tree and
STOP for the orchestrator before WP3.7 (the soak/verification suite).
```
