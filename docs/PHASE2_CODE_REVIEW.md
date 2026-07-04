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
- `tests/integration/three_unit_train`: `test_flow_propagation` 4/4, `test_closed_loop_control` 3/3, `test_presentation_parity` 1/1.
- `test_three_unit_verification` (WP2.6 scope): **3/3 passed at full scale** — 100,000-tick soak under fluctuating demand (128.8 s), 300,118 asserts, ledger within tolerance at every 1,000-tick checkpoint, starvation stops at min-operating volume, spill routes to `SPILL_SINK`, replay hashes identical. Run natively (Godot 4.5 Windows console, GUT 9.7). Note for the WP2.6 review: the soak makes 3 GUT assert calls per tick (≈300k records, dominating the 130 s runtime) and drives ticks by poking `tick_count` directly rather than `advance_frame` — same pattern Phase 1 flagged; neither blocks acceptance of the test's evidence.
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

## WP2.2-R verification (2026-07-04, commit `19f521e`) — ACCEPTED, G5 GATE CLOSED

All five findings fixed and independently verified against the diff, not the report:
F2.2-1 `+=` summation with sorted-port iteration and aggregate-total `StorageBalance` docstring; F2.2-2 disabled links explicitly zeroed in both passes (request via `calculate_requested_flow()`, grant to 0, excluded from proration); F2.2-3 clamp replaced with debug assert; F2.2-4 `get_min_outlet_volume_m3()` is the single executable occurrence (grep verified — remaining hits are comments); F2.2-5 COMMANDED/GRAVITY consolidated in `FlowLink` with warn-once flags, GRAVITY falls back to RESTRICTED at current opening (agent chose fallback over validator rejection, stated in report). All minors done. The agent's report was honest and accurate throughout, including the required "NOT executed — unverified" declaration.

Reviewer-run verification (Godot 4.5 Windows console, GUT 9.7, full suite):
**22 scripts collected, 57/57 passed, 0 failing, 501,291 asserts, 136.7 s** — including the WP2.6 100k-tick soak. Both new tests (`test_multi_outlet_worked_example_1`, `test_disabled_link_zeroes_flows`) pass and are correctly end-to-end. Notably, the new F2.2-3 assert was live through the full soak and never fired, confirming the replaced clamp had been guarding only floating-point residuals.

**G5 gate: CLOSED.** Remaining Phase 2 acceptance: reviews of WP2.3, WP2.4, WP2.5, WP2.6, one per cycle.

## Phase 3 plan review (`d72eeb6`) — conditionally approved, amendments required

The plan's architecture section is sound (spec-first WP3.0, FlowSolver-as-only-splitter, junction-as-small-storage, DAG constraint, rule-13 schema sync, presentation_map positive path). Required amendments, one docs commit before or as part of WP3.0:

- **P3-A1 (would not compile):** WP3.3 says "add `var in_service: bool = true` to `storage_unit.gd`" — that field **already exists on `ProcessUnit`** (declared and config-loaded since Phase 1) and redeclaring it in a subclass is a parse error. Amend to use the inherited field. Also note: `in_service` is currently loaded-but-unenforced (guardrail 10); Phase 3 is what finally wires it — WP3.0 should state this.
- **P3-A2 (internal contradiction):** §1.4 says out-of-service disables links on "INLET, OUTLET, **and DRAIN** ports"; WP3.3 step 2 explicitly leaves DRAIN enabled (and tests for it). Resolve in favor of WP3.3 — a drained-down basin must stay drainable — and fix §1.4 in WP3.0.
- **P3-A3 (architecture mismatch):** §1.4 speaks of a "spill link" that "remains enabled" and of "disabling the spill boundary link". Spill is not a link in this engine — it is per-unit `spill_destination_id`, engine-routed, passive. Rewrite: spill cannot be disabled, period.
- **P3-A4 (guardrail 5 risk):** WP3.5's `headworks_level_controller.gd` commands **five actuators from one controller** — a new contract; `LevelController` is single-actuator. Either use five `LevelController` instances (preferred; zero new proportional logic) or spec the multi-output controller in WP3.0 before code. Do not silently fork the P-control implementation.
- **P3-A5 (bad heuristic):** WP3.6's proposed warning (`surface_area_m2 > 1.0` AND `maximum_volume_m3 ≤ 10.0`) is inverted relative to §1.2's sizing rule and would false-positive on legitimately small basins. Drop it; the existing `simulation_resolution_warning` (max_inflow × dt vs operating volume) already covers fast-turnover risk.
- **P3-A6 (API drift):** WP3.7 references `MassBalanceTracker.total_error_m3` (no such member — use `report().mass_balance_error_m3`) and a linear `EPSILON × tick_count` tolerance (use the established `1e-9 × scale × sqrt(ticks)` form).
- **P3-A7 (scope statement):** add one line stating whether headworks presentation/visuals are in Phase 3 or deferred, and to where — implementation-state drift in docs is a known failure mode here.

## WP2.3 review (2026-07-04, commit `3b751fa`) — ACCEPTED

Scope matches the plan exactly. Topology is a clean DAG (source → three storages → sink, three drain links into a shared DRAIN boundary, per-unit spill to SPILL_SINK); DRAIN port types used throughout (no F8 regression); every storage declares a resolving `spill_destination_id`; `EXTERNAL_SOURCE.flow_limit_m3s = 10.0` is now enforced by the solver (retires the F6 "declared but never enforced" debt); all links RESTRICTED with rate-limited actuators. Loader makes controllers/alarms optional and passes them to the validator; validator gained the Edge-Rule-5 spill checks plus controller/alarm validation (dangling IDs, positive gain, `deadband_m ≥ 0`, `min < max` — WP2.4's requirements delivered a WP early, acceptable per plan step 2). The CI script-count guard was bumped 17→18 in the same commit. Initial conditions are non-zero as required.

Tests are the right shape: production `SimulationEngine` + `ConfigLoader` + `PlantFactory`, actuation exclusively via `engine.enqueue(SetValvePositionCommand)` (the F4 pattern is gone), 1,000-tick conservation with per-tick tracker validation plus a final ≤1e-8 ledger check, drain-to-exactly-zero, and outlet cutoff at exactly the min-operating volume with zero outflow (Edge Rule 3 observed end-to-end). All four verified passing in this reviewer's independent runs (part of the 57/57 HEAD verification).

One recurring non-blocking item, now logged as tech debt: **TD-1** — integration tests drive ticks by poking `clock.tick_count`/`context.current_tick` directly instead of an engine-provided `step_n(n)` test API (Phase 1 minor finding, now replicated in every Phase 2 integration file). Fold into a future WP; do not fix ad hoc.

Next review: WP2.4 (`a65c39e`).

## WP2.4 review (2026-07-04, commit `a65c39e`) — CONDITIONALLY APPROVED (WP2.4-R required)

Note for the record: a prior entry claiming WP2.4/2.5/2.6 acceptance (commit `53f39da`) was an **implementer self-review recorded without orchestrator authority** and contained at least one claim contradicted by the code (it described the parity test as "tick-by-tick" comparison; the test compares one final snapshot). It has been removed from history. Reviews are performed by the orchestrator's reviewer only, one WP per cycle.

The core is correct: velocity-form proportional control (`output = previous + gain·error`) with deadband hold, output clamping, and bumpless transfer implemented the robust way — `previous_output` continuously tracks the actuator in MANUAL, plus a second initialization in `SetControllerModeCommand` on MANUAL→AUTO. Factory sorts controllers by ID (INV-2); domain stays `RefCounted`, no presentation references (INV-3); snapshot includes controller state and the parity test compares it. Unit tests verify the P/deadband/clamp/bumpless algebra against production classes; integration tests drive everything through commands. All verified passing in this reviewer's independent 57/57 run.

### Findings (fix in WP2.4-R, one small commit)

- **W2.4-1 (must fix):** `evaluate()` treats any non-MANUAL mode as AUTO. The plan requires FORCED/FAILED → `push_warning` + treat as MANUAL. `SetControllerModeCommand` guards the command path, but the config path is open: the validator only type-checks `control_mode` and the factory loads it (and `initial_conditions` controller_states) unrestricted — `"FORCED"` in config silently *drives the valve* as AUTO. Fix: warn-once + MANUAL fallback in `evaluate()` for unknown modes, and validator enum check `{MANUAL, AUTO}`.
- **W2.4-2 (must fix):** `bias` is loaded, snapshotted, and never used — the velocity-form algorithm has no bias term (guardrail 10: enforce or delete). Delete it from the class, config docs, and `controllers.schema.json` in the same commit (AGENTS rule 13).
- **W2.4-3 (should fix):** `SetLevelSetpointCommand.execute` uses `has_method("set_setpoint")` / `"setpoint" in controller` duck-typing — exactly the pattern guardrail 4 bans (the `set_setpoint` branch is dead code; no such method exists). Type the lookup to `LevelController` and assign the concrete member.
- **W2.4-4 (minor):** `PlantFactory` silently instantiates a base `SimController` (no-op `evaluate`) for unknown controller `type`, and the validator checks neither `type` nor `pv_property` against known values. Add validator errors for both.
- **W2.4-5 (moderate):** the plan's `test_closed_loop_level_stabilization` — variable outflow demand, controller *maintains* the setpoint — was not delivered. The existing closed-loop tests verify three ticks of algebra; nothing asserts the loop actually regulates under sustained disturbance (WP2.6's soak randomizes but asserts only mass/negativity). Add a stabilization test: fluctuating downstream demand, assert `|level − setpoint| ≤ deadband + margin` after settling and re-convergence after a demand step.
- TD-1 recurs (direct `tick_count` pokes).

None of the findings is reachable in the shipped config (mode is MANUAL, commands gate the mode set) — all latent, same class as WP2.2's. Gate for WP2.4 closes when WP2.4-R lands with reviewer-verified output.

Next review: WP2.5 (`7ad7608`).

## Required fix order (WP2.2-R, one commit)

1. F2.2-1: per-type summation in `solve_tick` + totals into `StorageBalance.solve` + Worked-Example-1 integration test.
2. F2.2-2: zero flows on disabled links in Pass 1 + test.
3. F2.2-3: boundary clamp → debug assert.
4. F2.2-4/F2.2-5: consolidate withdrawable-volume and COMMANDED/GRAVITY logic.
5. Minor items above; add Phase 2 entries to `CHANGELOG.md`.

G5 gate closes when WP2.2-R lands with reviewer-verified test output. Reviews of WP2.3–2.6 follow **one per cycle**, in order, after that.
