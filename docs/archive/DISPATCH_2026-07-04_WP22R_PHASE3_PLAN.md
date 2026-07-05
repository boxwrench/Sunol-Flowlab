# Dispatch — WP2.2-R Remediation + Phase 3 Implementation Plan

Date: 2026-07-04 · Issued by: orchestrator · Executor: implementation agent
Authority: `AGENTS.md` (all 13 guardrails, binding) → `docs/INDEX.md` order.

## Read first, in this order — do not skip

1. `AGENTS.md` § Verification and failure-mode guardrails (all 13).
2. `docs/PHASE2_CODE_REVIEW.md` — the findings you are fixing (F2.2-1…5 + minors).
3. `docs/SIMULATION_RULES.md` § Flow Resolution and Proration + § Determinism and Edge Rules.
4. `docs/PHASE2_IMPLEMENTATION_PLAN.md` (WP2.2 section) and `docs/ROADMAP.md` (for Task 2).

## Rules of engagement for this dispatch

- Exactly **two tasks**, executed in order, **one commit each** (Task 1 may be a small commit series if needed; Task 2 is one docs-only commit). After Task 2 is committed: **STOP. Do not begin any Phase 3 WP.** Progression is gated on orchestrator review.
- Repo state warning: WP2.3–2.6 are committed but **unreviewed**. Do not modify their files except where a Task 1 fix forces a call-site update, and list every such touch in your report.
- Do not alter tick order, iteration order, `dt`, or any tolerance value (INV-2). Do not weaken, delete, or conditionally bypass any `assert` to make a test pass. Do not modify an existing test's expected values except where the F2.2-1 signature change forces a call-site update.
- Every claim in your report must be backed by pasted evidence. Unevidenced claims are treated as false.

---

## Task 1 — WP2.2-R (closes findings from docs/PHASE2_CODE_REVIEW.md)

### 1. F2.2-1 — multi-outlet/multi-drain integration (INV-1) ⛔

- `scripts/simulation/domain/storage_unit.gd` `solve_tick()`: replace the scalar `=` overwrite with per-type **summation** (`requested_outflow += link.actual_flow_m3s`, same for drain). Iterate ports in **sorted port_id order** (build a sorted key array first) so behavior is order-independent AND deterministic.
- `scripts/simulation/hydraulics/storage_balance.gd` `solve()`: accept outlet/drain **totals** (document that callers pre-sum). Update the docstring — it currently says "the OUTLET link" singular.
- Update the only production call site (`storage_unit.gd`) and the existing test call sites (`tests/unit/hydraulics/test_storage_balance.gd`, `tests/unit/hydraulics/test_flow_solver.gd` defensive test). No other files.
- **New test (required):** `test_multi_outlet_worked_example_1` in `tests/unit/hydraulics/test_flow_solver.gd` — reproduce SIMULATION_RULES Worked Example 1 **end-to-end**: Basin A volume 3.0 m³, two outlet links (max 4.0 and 2.0, both open), run `FlowSolver.solve_flows` **and then** `StorageUnit.solve_tick`, assert granted 2.0/1.0, assert `new volume == 0.0`, assert no water created (downstream deliveries sum equals basin volume change). Solver-only assertions do not satisfy this — the Phase 2 review exists because a solver-only test hid this bug.

### 2. F2.2-2 — disabled links carry stale flows ⛔

- `scripts/simulation/hydraulics/flow_solver.gd` Pass 1: for links with `not link.is_enabled`, do not skip silently — call `link.calculate_requested_flow()` (which zeroes and sets `constraint_reason`) **and** set `link.granted_flow_m3s = 0.0`, then exclude from proration sets. The final sweep then propagates 0 to `actual_flow_m3s`.
- **New test (required):** `test_disabled_link_zeroes_flows` — solve once with the link enabled (nonzero flow), set `is_enabled = false`, solve again, assert `requested == granted == actual == 0.0`.
- Rationale you must not "optimize away": Phase 3 basin availability will toggle equipment at runtime; this path is about to become load-bearing.

### 3. F2.2-3 — boundary clamp → debug assert

- `scripts/simulation/core/simulation_engine.gd` `_step_calculate_levels_spills()`: replace the silent `current_flow_m3s = flow_limit_m3s` clamp with `assert(unit.current_flow_m3s <= unit.flow_limit_m3s + 1e-9, ...)`. Guardrail 9: a clamp on a ledgered flow is either ledgered or proven unreachable — this one is claimed to be fp-residual only, so prove it.

### 4. F2.2-4 — single withdrawable-volume implementation

- `FlowSolver._grant_storage_source()` must call `unit.available_outlet_withdrawal_m3(dt)` and `unit.available_withdrawal_m3(dt)` instead of recomputing `min_operating_level_m * surface_area_m2` inline. `StorageUnit.solve_tick` likewise passes `min_vol`/`spill_vol` derived from one place. Grep for `min_operating_level_m * surface_area_m2` afterward: it must appear in exactly one production location.

### 5. F2.2-5 — one COMMANDED implementation; GRAVITY must not be a silent placeholder

- Move the COMMANDED warn+RESTRICTED@1.0 behavior into `FlowLink.calculate_requested_flow()`; the solver calls it and deletes its own duplicate branch. Make the warning **once per link** (a `_commanded_warned` flag) — per-tick warnings flood 100k-tick soaks.
- GRAVITY: `push_warning` as unimplemented (once per link) and treat as RESTRICTED at current opening — or reject GRAVITY in `plant_validator.gd`. Pick one, state which in the report. Silent max-flow behavior is prohibited (Edge Rule 6 / guardrail 10).

### 6. Minors (same commit or a second commit)

- `StorageBalance.solve()` step (g): fix the comment — the sub-epsilon clamp is spec-sanctioned (§ Numerical tolerances), not a "ledgered clamp". Say what it actually is.
- `_step_apply_constraints()` / `_step_transfer_water()`: add the guardrail-4 comment stating constraint work happens inside step 5's `FlowSolver.solve_flows` and what (if anything) fills these steps later.
- `FlowPort` header comment: add DRAIN to the port-type list.
- `tools/ci/validate_configs.sh`: add `command -v check-jsonschema >/dev/null || { echo "FAIL: check-jsonschema not installed"; exit 1; }` before the loops.
- `CHANGELOG.md`: add entries for WP2.1–WP2.6 as committed **and** WP2.2-R (state clearly that WP2.3–2.6 are implemented, pending review — do not describe them as accepted).

### Task 1 — Done when (all required, none negotiable)

- Full suite runs headless (`--headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`) and the report contains the **pasted GUT Run Summary including the Scripts count**. Expected: **22 scripts collected** (GUT silently skips unparseable files — a drop in script count is a FAIL even at 100% pass rate), **57 tests minimum** (55 + 2 new), **0 failing**. If your environment cannot run Godot, the required wording is: "Tests written but NOT executed — unverified."
- `grep` proof for item 4 (one production occurrence) pasted in the report.
- `git status` clean; last line of every edited file intact (guardrail 11).
- Commit message begins `WP2.2-R:` — no renumbering, no "Phase 2 complete" claims.

---

## Task 2 — docs/PHASE3_IMPLEMENTATION_PLAN.md (docs-only commit)

Scope source: `ROADMAP.md` "Next phase", second half — headworks + five sedimentation trains: source reservoirs, inlet manifold, flash mix, distribution box, five basins, applied channel; flow splitting and basin availability.

Required structure (mirror `PHASE2_IMPLEMENTATION_PLAN.md`):

1. **Architecture & rules map** — how each Phase 3 feature maps onto existing invariants, Edge Rules, and classes. Binding constraints to state explicitly:
   - All wet nodes are `StorageUnit`s (junction-as-small-storage, SIMULATION_RULES Example 2). Flash mix / manifold / distribution box get small volumes; cite the `simulation_resolution_warning` sizing rule.
   - Flow splitting across the five basins **is** `FlowSolver` proration — no new splitter algorithm, no second implementation (guardrail 5). If a WP appears to need one, the WP is wrong.
   - Basin availability = `in_service` / `is_enabled` semantics through the **existing** solver path (the F2.2-2 fix is a prerequisite — say so). Define what taking a basin out of service means for its links, in a new SIMULATION_RULES subsection **before** any code WP.
   - Topology remains a DAG; no recirculation/backwash in Phase 3 (out of scope until a cyclic-network spec exists).
   - Tick order, dt, iteration rules unchanged (INV-2). Simulation never references presentation (INV-3).
2. **Spec-first WP0-style item**: any new binding rules (basin availability semantics, small-storage sizing for the new units, applied-channel behavior) are written into SIMULATION_RULES / PROCESS_UNIT_CONTRACTS in the plan's **first** WP, before code.
3. **WP table** — numbered WP3.1…WP3.N, layer, primary files, depends-on. Each WP sized for one review cycle.
4. **Per-WP sections** — goal, files, steps, named tests, "Done when" that requires pasted runner output (copy WP2.1's wording).
5. **Config & schema**: new plant dir `config/plants/phase3_headworks/` (or similar); every new config field updates `config/schema/` + `plant_validator.gd` in the same commit (AGENTS rule 13); include a `presentation_map.json` so that schema's positive path is finally exercised in CI.
6. **Final WP**: verification & soak suite mirroring WP2.6 (soak, availability churn, replay).

Constraints: **no code files, no config files, no test files** are created by Task 2 — plan document only (strict scope guard). The plan must exist at `docs/PHASE3_IMPLEMENTATION_PLAN.md`, be linked from `docs/INDEX.md` (Planning & reviews), and be committed — a plan in any scratch/brain folder is work not done (guardrail 12).

### Task 2 — Done when

- `docs/PHASE3_IMPLEMENTATION_PLAN.md` committed, linked from INDEX, cross-references resolve (relative links only).
- Commit message begins `plan:`. Then **STOP** for orchestrator review.

---

## Report format (required, both tasks)

```
Task N report
Commits: <hashes>
Files changed: <list>
NOT done / deviations: <explicit list, or "none">
Evidence:
  - GUT Run Summary (pasted, incl. Scripts count)   [Task 1]
  - grep output for single min-vol implementation    [Task 1]
git status: <pasted, must be clean>
```

Reports that assert success without the pasted evidence blocks will be rejected without review.
