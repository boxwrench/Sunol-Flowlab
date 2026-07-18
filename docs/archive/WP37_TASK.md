# WP3.7 Verification & Soak Suite — Implementation Brief (historical)

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Implementation agent brief for WP3.7 Phase 3 verification and soak suite. First committed 2026-07-04.
> Titled "Next Task" as written — it is not a live instruction. Do not execute it.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

Source of truth: `docs/PHASE3_IMPLEMENTATION_PLAN.md` §4 "WP3.7" and §6.
Per §8 Execution Protocol, WP3.7 runs after WP3.6 with no review pause, but WP3.7 output IS
re-run by the reviewer at the **WP3.8 batch audit** — so its results must be reproducible from
a clean tree. Begin only after WP3.6 is committed with green tests and a clean tree.

[ROLE]
You are the implementation agent for Sunol FlowLab. Work from the repository's actual code and
`docs/PHASE3_IMPLEMENTATION_PLAN.md`, not prior summaries. Follow AGENTS.md exactly.

[REQUIRED READING — BEFORE EDITING]
1. AGENTS.md
2. docs/PHASE3_IMPLEMENTATION_PLAN.md §4 "WP3.7", §6
3. docs/SIMULATION_RULES.md — Determinism & Edge Rules, mass-balance tolerance
4. scripts/simulation/core/mass_balance_tracker.gd — the REAL report() signature (see below)
5. scripts/simulation/core/simulation_engine.gd — `mass_balance_tracker` field, tick loop
6. scripts/simulation/core/simulation_context.gd — `topological_units_list`, seeded RNG
7. scripts/simulation/core/snapshot_service.gd — snapshot shape for replay comparison
8. tests/invariants/test_mass_conservation.gd, test_deterministic_replay.gd,
   test_no_negative_storage.gd — established Phase 2 patterns to mirror

[STRICT SCOPE]
Verification tests only. No production/domain/solver/config changes — if a test cannot pass
without a production change, STOP and report it as a finding rather than editing production code
to make a test green. No scene/UI work (WP3.8). Do not modify review-verdict documents.

[GOAL]
Consolidate all Phase 3 correctness checks into an automated suite mirroring WP2.6: mass
conservation, availability churn, and deterministic replay across the full headworks train.

[REQUIRED WORK]

1. `tests/integration/phase3_headworks/test_phase3_verification.gd`:
   - `test_phase3_soak_100k_ticks`: full headworks topology at 60× for 100,000 ticks with
     inflow demand ramped up and down every 5000 ticks. Assert zero mass-balance error (within
     tolerance) and no negative volume on any unit.
   - `test_availability_churn_100k_ticks`: randomly toggle basins in/out of service every 500
     ticks over 100,000 ticks, using the context's SEEDED RNG (deterministic — do not use
     unseeded randomness). Assert ledger error ≤ tolerance and no negative volume.
   - `test_deterministic_replay_phase3`: record a 1000-tick command sequence (valve moves,
     basin toggles), replay from an identical initial state, assert identical state
     trajectories (bit-exact snapshot comparison). Follow tests/invariants/test_deterministic_replay.gd.

2. `tests/invariants/test_phase3_invariants.gd`:
   - `test_no_water_created_phase3` (P3-A6): mass conservation over a 10,000-tick run. Use the
     established tolerance form: `error <= 1e-9 * scale * sqrt(tick_count)`, where `scale`
     accounts for the larger Phase 3 plant volume.
     **CORRECT API — the report() method takes an argument:**
     ```
     var report: Dictionary = engine.mass_balance_tracker.report(current_storage_m3)
     var err: float = abs(report.mass_balance_error_m3)
     ```
     `current_storage_m3` is the summed live storage across all units at the moment of the call
     (see how snapshot_service.gd / mass_balance_tracker.gd obtain it). Do NOT reference a
     `MassBalanceTracker.total_error_m3` field — no such field exists. Use absolute error.
   - `test_dag_unchanged_after_availability_toggle`: assert `context.topological_units_list` is
     identical (same ordering, same unit IDs) before and after a basin is taken out of service.
     Availability changes service state and link-enabled state only; the topological list is
     static.

[DETERMINISM REQUIREMENTS]
- All randomness routes through the context's seeded RNG so runs are reproducible.
- Use production PlantFactory + production domain classes. Do not recreate solver, tick, or
  balance behavior in tests.
- 100k-tick tests must complete headless in reasonable time; if runtime is a concern, keep the
  per-tick work to production paths and avoid per-tick allocations in the test harness.

[VERIFICATION — run and paste exact output]
1. Targeted: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/phase3_headworks -ginclude_subdirs -gexit`
   and `... -gdir=res://tests/invariants ...` → all five WP3.7 tests passing, 0 failing.
2. Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
   → 0 failing, no parse errors, no skipped scripts. Paste Scripts/Tests/Passing/Failing counts
   (Scripts count must include all Phase 3 scripts).
3. `bash tools/ci/validate_configs.sh` → exit 0.
4. `git diff --check` and `git status --short` → both clean.

[HANDOFF]
Commit with a message beginning `WP3.7:`. Report the exact runner summaries (including the
100k-tick results and wall-clock if notable), validate_configs result, and changed files.
Update CHANGELOG.md with the WP3.7 entry. Leave a clean working tree.

This is the last WP before the WP3.8 batch audit. After committing, STOP for orchestrator
review — the reviewer will re-run this soak suite from a clean checkout as part of the WP3.8
gate. Do NOT begin WP3.8 (scenes/presentation) until the reviewer authorizes it.
