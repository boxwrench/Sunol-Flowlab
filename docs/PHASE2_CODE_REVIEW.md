# Phase 2 Code Review — WP2.2 (G5 FlowSolver & Proration Core)

Date: 2026-07-04
Scope: commits `2d7912d`, `f8155f8`, `6750603`, `19da695` (WP2.2), reviewed at HEAD `e5ce9de`.
References: `SIMULATION_RULES.md` §Flow Resolution and Proration + §Determinism and Edge Rules, `PHASE2_IMPLEMENTATION_PLAN.md`, `AGENTS.md` guardrails, INV-1/2/3.
Reviewer verification: Godot 4.5-stable Linux headless, GUT 9.7.0, full suite re-run independently (see §Verification evidence).

## Verdict

**WP2.2 is conditionally approved.** The two-pass solver is faithfully implemented, deterministic, and independently verified against the spec's proration math. Edge Rules 1–6 are each mechanically present. However, two latent INV-1 defects and one guardrail-9 violation must be remediated in a follow-up commit ("WP2.2-R") before the G5 gate closes. None of the three is reachable with the current `phase2_three_unit` configuration — which is exactly why they must be fixed now, while they are cheap, rather than discovered as "mysterious" mass errors when the plant grows.

**Process violation, separate from code quality:** WP2.3, WP2.4, WP2.5, WP2.6, and a seven-task schema workstream were all committed without stopping for inter-WP review, contrary to the standing rule (one WP per review cycle; agents stop for review between WPs). The work reviewed here is therefore already load-bearing for five subsequent deliverables. WP2.3–2.6 remain unreviewed and their acceptance is not implied by this document (guardrail 6).

## Verification evidence (reviewer-run, not agent-claimed)

Environment: Godot 4.5-stable Linux headless in an isolated sandbox; repo tar-copied excluding `.git`/`.godot`; `--import` clean (GUT editor-dock plugin parse errors are editor-only and harmless headless; no doubling/stubbing is used by any test).

- `tests/unit` (incl. subdirs): **14 scripts collected, 34/34 passed, 244 asserts** — matches the 14 unit test files on disk; no silent GUT skips. `test_flow_solver.gd`: 5/5 (`proration`, `boundary_limits`, `outlet_vs_drain`, `defensive_assert`, `sink_limits`).
- `tests/invariants`: **3 scripts, 4/4 passed**, including `test_mass_conservation_100k_ticks` (100,000 ticks, production engine, ~23 s) and `test_replay_determinism`.
- `tests/integration/single_basin`: 6/6 passed, including `test_extended_soak` (100,000 ticks).
- `tests/integration/three_unit_train`: `test_flow_propagation` 4/4, `test_closed_loop_control` 3/3, `test_presentation_parity` 1/1. (`test_three_unit_verification` is WP2.6 scope; long-soak verification pending at time of writing.)
- Script/test totals on disk (22 scripts / 55 tests) match the agent's claimed totals.
- Debug asserts were live in these runs: the StorageBalance Edge-Rule-2 backstop asserts never fired across >200,000 production-engine ticks. That is direct evidence the solver's grants respect both supply tiers.
- Commit `f8155f8` correctly used the required "Tests written but NOT executed — unverified" wording (guardrail 1 honored).

## Edge Rule scorecard

| Rule | Status | Notes |
|---|---|---|
| 1. Deterministic topo order | ✅ | WP2.1 order consumed via `context.topological_units_list`, reverse then forward. |
| 2. One proration authority | ✅ | Two debug asserts in `StorageBalance.solve()`; actual==granted assert in `StorageUnit.solve_tick()`. Never fired in 200k+ verified ticks. |
| 3. Withdrawable vs total | ✅/⚠️ | Semantics correct in both solver and balance; but the "share this exact calculation" requirement is violated in letter — see F2.2-4. |
| 4. Boundary += summing | ✅/⚠️ | Reset-then-`+=` accumulation and total-capped source/sink proration correct; but a silent clamp sits on the ledgered total — see F2.2-3. |
| 5. Per-unit spill routing | ✅ | `spill_destination_id` config-only, no code default; validator errors on absent/unresolvable; engine routes per-unit with `+=`. Unroutable spill is warned and dropped, which the ledger self-detects — acceptable. |
| 6. COMMANDED warns | ✅/⚠️ | `push_warning` + RESTRICTED@1.0 in the solver path; but a second, silent COMMANDED implementation survives in `FlowLink` — see F2.2-5. |

## Findings

### F2.2-1. Multi-outlet integration is broken — solver grants N links, balance integrates 1 (INV-1, latent) ⛔ blocking for gate closure

`FlowSolver._grant_storage_source()` correctly prorates any number of OUTLET/DRAIN links. But `StorageUnit.solve_tick()` collects flows into scalar `requested_outflow`/`requested_drain` with `=` overwrite — a unit with two OUTLET ports integrates only the last-iterated link (dictionary insertion order decides which — guardrail 7 territory), and `StorageBalance.solve()` accepts exactly one outlet and one drain scalar. Water granted on the dropped link still arrives downstream via `actual_flow_m3s` but is never deducted upstream: net creation of water. The binding spec's own Worked Example 1 (Basin A, two outlet links) **cannot execute correctly on this engine.** The actual==granted assert does not catch this; only the cumulative ledger would, at runtime, in debug.
Not reachable today: every storage unit in `phase2_three_unit` has exactly one OUTLET and one DRAIN.
**Fix:** `solve_tick` sums per-type (`requested_outflow += ...`), and `StorageBalance.solve()` takes outlet/drain totals (or arrays, mirroring `inflows_m3s`). Add a unit test reproducing Worked Example 1 end-to-end (solver + integration), not solver-only.

### F2.2-2. Disabled links carry stale flows forever (flow constraint, latent) ⛔ blocking for gate closure

Pass 1 and Pass 2 both `continue` past `not link.is_enabled` without touching the link's flow fields, and the final sweep then copies stale `granted_flow_m3s` into `actual_flow_m3s` every tick. A link disabled after carrying flow keeps "flowing" at its last granted rate indefinitely — both endpoints integrate it, so the ledger stays green while the binding constraint "no flow through disabled equipment" is violated. `FlowLink.calculate_requested_flow()` contains the correct zeroing branch, but the solver never reaches it for disabled links.
Not reachable today: nothing toggles `is_enabled` at runtime.
**Fix:** in Pass 1, call `calculate_requested_flow()` (or zero request+grant explicitly) for disabled links instead of skipping them. One unit test: disable a flowing link, assert zero on all three flow fields next solve.

### F2.2-3. Silent clamp on a ledgered boundary flow (guardrail 9) — must fix

`simulation_engine.gd` `_step_calculate_levels_spills()`: after accumulation, `current_flow_m3s` is silently clamped to `flow_limit_m3s`. The comment says it "handles any floating-point residual" — then per guardrail 9 it must be a debug `assert`, not a clamp. As written, a future solver grant leak would be masked at the ledger while storage integrates the full flows, converting a loud solver bug into a confusing mass-balance discrepancy. This is the F7 pattern recurring.
**Fix:** replace the clamp with `assert(unit.current_flow_m3s <= unit.flow_limit_m3s + EPSILON, ...)`.

### F2.2-4. Withdrawable-volume math triplicated (Edge Rule 3 letter, guardrail 5) — should fix in WP2.2-R

`min_operating_level_m * surface_area_m2` is computed independently in `FlowSolver._grant_storage_source()` (line ~113), `StorageUnit.available_outlet_withdrawal_m3()`, and `StorageUnit.solve_tick()`. The shared methods the plan mandated exist but the solver does not call them. When elevation–storage curves arrive, these will drift.
**Fix:** solver uses `unit.available_outlet_withdrawal_m3(dt)` / `available_withdrawal_m3(dt)`; `solve_tick` passes the same values through.

### F2.2-5. Two COMMANDED implementations; GRAVITY is a silent placeholder (Edge Rule 6, guardrail 5) — should fix in WP2.2-R

The solver's COMMANDED branch (warn + RESTRICTED@1.0) bypasses `FlowLink.calculate_requested_flow()`, which retains its own **silent** `COMMANDED → max_flow` branch — any other caller gets prohibited silent-placeholder behavior. The `else` branch also makes GRAVITY mode silently behave as full-open max_flow, the same pattern Edge Rule 6 exists to prohibit.
**Fix:** single implementation in `FlowLink` (warn there), solver calls it; GRAVITY either `push_warning`s as unimplemented or is rejected by the validator until specified. Consider warn-once per link — at 100k ticks the current per-tick warning floods the log.

### Minor

- `StorageBalance.solve()` step (g): the sub-epsilon volume clamp's comment claims "guardrail 9: ledgered clamp" but the discarded residual (≤1e-9 m³) feeds no ledger term. Spec-sanctioned by §Numerical tolerances, and covered by the sqrt-scaled tolerance, but fix the comment or add the residual to the ledger — do not leave a comment that mis-states compliance.
- `_step_apply_constraints()` and `_step_transfer_water()` are bare `pass` without the guardrail-4-required comment naming what fills them (constraint work happens inside step 5's solver call; say so).
- `FlowPort.port_type` comment still reads "INLET, OUTLET" — DRAIN exists since the F8 fix.
- `CHANGELOG.md` has no entries for any Phase 2 WP (development checklist item 5).

## Schema workstream, Task 7 (`e5ce9de`) — reviewed here because its own review never ran

Session evidence shows Task 7's reviewer agent failed to start (model unavailable, then session limit); the commit landed unreviewed at HEAD. Reviewed now: **approved.** `tools/ci/validate_configs.sh` verified in sandbox — 8/8 shipped configs pass their schemas, 6/6 negative fixtures rejected, exit 0; the new CI job is correctly formed; `CONFIGURATION_REFERENCE.md` rewrite matches new AGENTS rule 13 (no duplicated field docs). Two nits, non-blocking: (1) when `check-jsonschema` is not installed, the negative-fixture leg mislabels failures as "ok (rejected as intended)" — overall exit still fails via the positive leg, but the output lies; guard with `command -v check-jsonschema || exit 1`. (2) No shipped plant has a `presentation_map.json`, so that schema's positive path is exercised nowhere — fine until WP2.5's review, which should add one.

## Required fix order (WP2.2-R, one commit)

1. F2.2-1: per-type summation in `solve_tick` + totals into `StorageBalance.solve` + Worked-Example-1 integration test.
2. F2.2-2: zero flows on disabled links in Pass 1 + test.
3. F2.2-3: boundary clamp → debug assert.
4. F2.2-4/F2.2-5: consolidate withdrawable-volume and COMMANDED/GRAVITY logic.
5. Minor items above; add Phase 2 entries to `CHANGELOG.md`.

G5 gate closes when WP2.2-R lands with reviewer-verified test output. Reviews of WP2.3–2.6 follow **one per cycle**, in order, after that.
