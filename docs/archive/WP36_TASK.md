# WP3.6 Config Schema Sync — Implementation Brief (historical)

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Implementation agent brief for WP3.6 config schema sync. First committed 2026-07-04.
> Titled "Next Task" as written — it is not a live instruction. Do not execute it.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

Source of truth: `docs/PHASE3_IMPLEMENTATION_PLAN.md` §4 "WP3.6" and §5 Config & Schema.
Per §8 Execution Protocol, WP3.6 runs sequentially after WP3.4/WP3.5 with no review pause
(next batch audit is WP3.8), **provided all gates stay green**. Begin only after WP3.5 is
committed with green tests and a clean tree.

[ROLE]
You are the implementation agent for Sunol FlowLab. Work from the repository's actual code and
`docs/PHASE3_IMPLEMENTATION_PLAN.md`, not prior summaries. Follow AGENTS.md exactly.

[REQUIRED READING — BEFORE EDITING]
1. AGENTS.md
2. docs/PHASE3_IMPLEMENTATION_PLAN.md §4 "WP3.6", §1.2 (sizing rule), §5 Config & Schema
3. docs/SIMULATION_RULES.md — the `simulation_resolution_warning` (max_inflow × dt vs operating_volume)
4. config/schema/topology.schema.json
5. config/schema/presentation_map.schema.json (confirm it exists from WP2.5)
6. config/plants/phase2_three_unit/presentation_map.json (pattern reference)
7. scripts/configuration/plant_validator.gd
8. tools/ci/validate_configs.sh

[STRICT SCOPE]
Schema + validator + one new config file, plus CI confirmation. No domain/solver changes. No
scene/UI work (that is WP3.8). Do not modify review-verdict documents. Do not begin WP3.7.

[GOAL]
Every new config field introduced across WP3.1–WP3.5 has a matching schema entry in
`config/schema/` and is enforced by `plant_validator.gd`. Add a `presentation_map.json` for
`phase3_headworks` so the positive schema path is exercised in CI (closes the WP2.5 review nit).

[REQUIRED WORK]
1. `config/schema/topology.schema.json`:
   - Confirm `in_service` (type: boolean, default: true) is present; add it if absent.
   - Audit every field used by the phase3_headworks configs (units, boundaries, links,
     alarms, controllers introduced in WP3.1–WP3.5) and confirm each has a schema entry.
     Keep `additionalProperties:false` honest — no config field should be silently unschema'd.

2. `scripts/configuration/plant_validator.gd`:
   - Add an explicit boolean type-check for `in_service` when present in config.
   - **P3-A5 — DO NOT add the `surface_area_m2 > 1.0 AND maximum_volume_m3 <= 10.0` warning.**
     That heuristic is inverted relative to §1.2's sizing rule and would false-positive on
     legitimately small basins. If any automated fast-turnover check is warranted, replicate
     the existing `simulation_resolution_warning` ratio (max_inflow × dt vs operating_volume)
     from SIMULATION_RULES.md — do not invent a new heuristic.

3. `config/plants/phase3_headworks/presentation_map.json` (new):
   - Author a valid presentation map for the headworks plant so
     `presentation_map.schema.json`'s positive path is exercised by CI. IDs only (references
     snapshot/asset IDs, not live domain objects), matching the WP2.5 pattern.

4. Confirm `tools/ci/validate_configs.sh` already includes phase3_headworks in its guarded set
   (the WP2.2-R guard). If presentation_map.json is not picked up automatically, ensure it is
   validated. Do not weaken the invalid-fixture rejection checks.

[VERIFICATION — run and paste exact output]
1. `bash tools/ci/validate_configs.sh` → exit 0. Every phase3_headworks config (including the
   new presentation_map.json) reports `ok`; all `schema_invalid` fixtures still `rejected as
   intended`.
2. Confirm no schema change breaks existing positive fixtures (phase1, phase2, phase3 all `ok`).
3. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
   → 0 failing, no parse errors, no skipped scripts. Paste Scripts/Tests/Passing/Failing counts.
4. `git diff --check` and `git status --short` → both clean.

[HANDOFF]
Commit with a message beginning `WP3.6:`. Report the exact validate_configs output, runner
summary, and changed files. Confirm explicitly that the inverted P3-A5 heuristic was NOT added.
Update CHANGELOG.md with the WP3.6 entry. Leave a clean working tree. Stop for the orchestrator
before WP3.7 (the soak/verification suite) unless instructed to continue.
