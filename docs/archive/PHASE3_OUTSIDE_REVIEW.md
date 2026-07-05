# Sunol FlowLab — Phase 3 (WP3.0–WP3.8) Architecture & Code Review Report

**Reviewer:** Independent outside review (Claude Fable 5)
**Date:** 2026-07-04
**Review baseline:** commit `46481aa` ("WP3.6: Author Presentation Map Configuration") — all code citations are to `git show 46481aa:<path>` unless noted.

---

## 0. Verdict up front

**Phase 3 cannot be accepted at this time — and not primarily because of code quality.** The committed simulation domain is in good shape: the two-pass solver, availability semantics, and mass-balance machinery match their binding specs closely, and the control-law defect was diagnosed and fixed correctly rather than gamed. Phase 3 fails its own exit gate for structural reasons: WP3.7 (soak/churn/replay) and WP3.8 (presentation/parity) do not exist in the repository, **no Phase 3 commit has ever been executed by CI** (origin/main is 31 commits behind local main at review time), and the CI workflow itself is guaranteed to fail the moment it runs (stale script-count gate). Every "tests pass" claim for Phase 3 is currently implementer-self-reported.

A note on review conditions: **the repository changed under the reviewer during this review.** The review began at `c7ef0e2`; commits `b972214` (control-law damping) and `46481aa` (WP3.6 presentation map) landed mid-session, and ~147 lines of uncommitted test edits visible at session start were discarded. The review was re-pinned to `46481aa` and affected files re-verified. This is a live instance of Open Question 5 and is treated as evidence there.

**What was executed vs. assumed:** All `git` verification commands were run directly, and `tools/ci/validate_configs.sh` was executed locally (all 13 schema checks pass, positive and negative fixtures). The GUT suite could **not** be run — no Godot executable exists on the review machine (searched PATH, Program Files, LOCALAPPDATA, registry app paths, C:\ to depth 3). All GUT pass/fail statements below are therefore labeled as claims or assumptions.

---

## 1. The Eight Open Questions

### Q1 — Control law adequacy

**[Topic]** Five shared-PV level controllers on a non-self-regulating plant. Domain: `control`.

**[Stated Spec/Doc]**
- `docs/PHASE3_IMPLEMENTATION_PLAN.md` §WP3.5: gates modulated "proportionally to the level error"; controllers provide "equal proportional demand signals"; config should use `min_output = 0.0, max_output = 1.0`.
- `docs/CONTROL_LOGIC.md` §"Control loop characteristics": documents the velocity-form law as a **pure integral controller**, warns the closed loop is an undamped double integrator with deadband-bounded limit cycles.
- `docs/KNOWN_LIMITATIONS.md` (line 26): "Control logic is limited to proportional controllers; integral/derivative terms, deadbands … are out of scope."

**[Actual Code State]**
- At `ee2716b`/`c7ef0e2`, `scripts/simulation/automation/level_controller.gd` was I-only (`output = previous_output + gain * error` behind a `deadband_m` hold). Five instances (`LC_BASIN_01..05`) in `config/plants/phase3_headworks/controllers.json` share `pv_unit_id: APPLIED_CHANNEL_01`, each driving one `VALVE_OUT_DB_0x`; downstream demand `LINK_OUT_AC_01` is an unactuated RESTRICTED link that requests its full 10 m³/s unconditionally (`flow_link.gd`, `calculate_requested_flow()` — no actuator ⇒ `requested = max_flow_m3s`). This is exactly the integrating-plant/fixed-demand structure the review brief describes; `WP35_TUNING_TASK.md` (untracked working doc) records the observed limit cycle (~0.5 m to ~3.5 m) and a gain sweep proving it structural.
- At `b972214` (review-time HEAD), the law is a **velocity-form PID increment**: `Δu = gain·e + kp·(e − e₋₁) + kd·(e − 2e₋₁ + e₋₂)`, with `kp`/`kd` defaulting to 0.0 (backward-compatible; Phase 1/2 arithmetic is unchanged). Phase 3 opts in with `gain: 1.5, kp: 20.0, kd: 0.0` on all five. Schema updated in the same commit (`config/schema/controllers.schema.json` lines 58–64) — AGENTS rule 13 honored.

**[Risk Assessment]** MEDIUM (was HIGH pre-`b972214`).
The fix is the right one for this plant class: on an integrating process, integral-only control is undamped at any gain, and velocity-form P adds phase lead (damping) without reintroducing position-form droop. Restructuring to per-basin local level control is **not** warranted for Phase 3 — the five basins share one PV by design, and FlowSolver proration handles redistribution — but note the current arrangement is effectively *one* controller with 5× authority, since all five instances have identical config and identical inputs. Residual defects, all verified in code at the review baseline:

1. **Bumpless transfer is violated on cold start (CONFIRMED in code).** `SimController.initialize()` sets `previous_output = 0.0`; `controllers.json` boots all five in `AUTO`; `initial_conditions.json` boots `VALVE_OUT_DB_0x` at position 50.0. On tick 1 (channel level 2.5 m vs setpoint 2.0), `Δu = 1.5(−0.5) + 20(−0.5−0) = −10.75`, clamped to 0 — all five gates are commanded from 50 % to 0 % in one tick. `CONTROL_LOGIC.md` §"Bumpless transfer" requires AUTO to start from the current position. The `previous_output` sync exists only in the MANUAL branch of `evaluate()`.
2. **Stale derivative history on MANUAL→AUTO (CONFIRMED in code).** The MANUAL branch returns before `previous_error`/`previous_error2` are updated, so the first AUTO tick applies `kp·(e − e_stale)`. With `kp = 20`, a 0.5 m error change accumulated during MANUAL produces a 10-percentage-point valve kick.
3. **No tests for the new law (CONFIRMED).** `b972214` touches no file under `tests/` (verified via `git show b972214 --stat`); `tests/unit/automation/test_level_controller.gd` is unchanged. The kp/kd math has zero direct coverage.
4. **The stabilization test repeats a rejected Phase 2 pattern (CONFIRMED).** `tests/integration/phase3_headworks/test_headworks_controller.gd` asserts *instantaneous* level within ±deadband at a fixed tick (`assert_almost_eq(ac.level_m, 2.0, 0.05)`). The WP2.4-R review cycle rejected exactly this ("stabilization test asserts instantaneous level on an undamped integral-action loop", commit `5b48204`) and replaced it with a time-averaged assertion (`5849926`). On a deadband-held loop the level can still drift through the band; the assertion is phase-of-cycle fragile.

**[Recommended Action]** Keep the velocity-PID structure. Fix bumpless transfer (initialize `previous_output` from the actuator's commanded position on first AUTO evaluation, and refresh error history in the MANUAL branch). Add a unit test for the increment arithmetic (kp=kd=0 equivalence, plus a damping case). Convert the two headworks assertions to time-averaged form per the WP2.4-R3 precedent.

---

### Q2 — Test-execution debt

**[Topic]** Deferred test execution and the audit cadence. Domain: `verification / process`.

**[Stated Spec/Doc]** `PHASE3_IMPLEMENTATION_PLAN.md` §8: every WP report must contain a pasted GUT Run Summary or the exact wording "Tests written but NOT executed — unverified"; an unverified WP is a hard stop; **any failing test is a hard stop**. `.github/workflows/tests.yml` runs the full GUT suite on every push to main and pins `EXPECTED_SCRIPTS`, with the comment "Update this number whenever a test script is added or removed."

**[Actual Code State]**
- **CI has never run any Phase 3 commit (CONFIRMED).** `git branch -vv` shows local main **31 commits ahead of origin/main**; `git ls-remote origin main` returns `e5ce9de` — a pre-WP3.1 commit. The declared CI backstop is disconnected from all of Phase 3.
- **CI is guaranteed red on push (CONFIRMED by arithmetic).** `EXPECTED_SCRIPTS=26` was last set at WP3.3 (`97356b3`) and is still 26 at the review baseline. Test-script counts per commit (count of `test_*.gd` files under `tests/`): 26 at `97356b3`, 27 at `d6e72b6` (WP3.4), 28 from `ee2716b` (WP3.5) onward — matching the "Scripts: 28" in the `b972214`/`46481aa` commit messages. WP3.4 and WP3.5 each added a script without bumping the gate.
- **The debt produced real, committed defects.** WP3.5 was committed at `ee2716b` with both of its own tests failing (recorded in `WP35_TUNING_TASK.md`: "full suite went 6 failing → 2 failing"); the capacity mismatch (Q3) and the AUTO-controller/manual-valve test interference (`c7ef0e2`) also surfaced only when the suite was finally run. The protocol's "any failing test = halt" rule was honored in spirit (the agent escalated rather than gamed the test) but not in letter (the WP was committed while red).
- **Current pass claims are unverifiable.** `b972214` and `46481aa` both paste "Scripts 28, Tests 79, Passing 79, Failing 0". This could not be reproduced in the review environment (no Godot binary), and CI has not run. Per the project's own methodology ("audit committed code and *reproduced* test output — never implementation summaries"), these numbers are **assumptions**, not evidence.

**[Risk Assessment]** HIGH. This is the most consequential finding in the review. The deferred-execution model is survivable *only* because of the batch-audit rerun — and the one mechanism that would make verification continuous and third-party (GitHub CI) has been idle for the entire phase.

**[Recommended Action]** (1) Push main to origin now, bumping `EXPECTED_SCRIPTS` to 28 **in the same push** so the first CI run can be green. (2) Make "CI green on origin/main" a per-WP gate — it is automation, not review overhead, and it removes the self-reporting problem entirely. (3) The WP3.8 batch audit must include a reviewer-side rerun of the full suite at a pinned hash (already planned; keep it non-negotiable).

---

### Q3 — Hydraulic sizing coherence

**[Topic]** Design-flow consistency across the headworks train. Domain: `hydraulics / configuration`.

**[Stated Spec/Doc]** `PHASE3_IMPLEMENTATION_PLAN.md` specifies no plant design flow anywhere; each WP chose `max_flow_m3s` values independently. The plan's §WP3.2 says DB outlet links get "the per-basin design capacity" — a capacity that is defined nowhere.

**[Actual Code State]** The defect happened as predicted and was fixed: `cf64d5e` reduced `LINK_OUT_AC_01` from 15.0 to 10.0 m³/s because the unactuated demand link "always outstrip[ped] supply" behind the 12 m³/s trunk. At the review baseline the chain is coherent (verified in `topology.json`): sources 2×10 → reservoir outlets 2×8 → trunk (manifold→flash-mix→dist-box) 12 → basin inlet gates 5×3 = 15 → basin outlets 5×4 = 20 → fixed demand 10. Demand (10) < trunk (12) < gate total (15), so the five controllers have real authority margin (each gate needs ~2.0 of 3.0 m³/s at steady state, ~67 % open).

**[Risk Assessment]** MEDIUM. The current numbers work, but they are an emergent property of one remediation commit, not a specification. The next phase (twelve filters, clearwell) will repeat the WP3.4 failure mode unless capacities derive from a single design basis. Related design note: the plant is deliberately non-self-regulating (fixed-max unactuated demand); that choice is what made Q1 hard, and it should be recorded as intentional or scheduled to change (e.g., when plant flow control arrives in a later phase).

**[Recommended Action]** Add an authoritative design-basis table (plant design flow, per-train flow, per-link capacity with margins) to `docs/PLANT_TOPOLOGY.md` or the Phase 3/4 plan, and require future WPs to cite it when setting any `max_flow_m3s`.

---

### Q4 — Doc-vs-code drift

**[Topic]** Which documents are the source of truth, and where they diverge from code. Domain: `documentation`.

**[Stated Spec/Doc]** `docs/INDEX.md` defines an explicit authority order: REPOSITORY_ARCHITECTURE wins all conflicts; SIMULATION_RULES / PROCESS_UNIT_CONTRACTS / CONTROL_LOGIC are "binding on code." So the intended source of truth *is* defined; the problem is drift within binding tiers.

**[Actual Code State]** Verified divergences at the review baseline:

| # | Document says | Code says | Severity |
|---|---|---|---|
| 1 | `KNOWN_LIMITATIONS.md`: "limited to proportional controllers; integral/derivative terms, deadbands … out of scope" | `level_controller.gd` is a velocity-form PID with a deadband | Worst offender — flatly false on three counts |
| 2 | `PROCESS_UNIT_CONTRACTS.md` canonical-class table: `JunctionUnit`, `SimAlarm`, `SimInstrument` | No `JunctionUnit` class (doc §"JunctionUnit Contract" honestly says "Realized as StorageUnit"); alarm class is `ThresholdAlarm`; no instrument class exists | Aspirational table vs. shipped code |
| 3 | `PHASE3_IMPLEMENTATION_PLAN.md` WP3.5: `max_output = 1.0` | `controllers.json`: `max_output: 100.0` — correct for `SimValve`'s 0–100 % convention | Plan error; code is right |
| 4 | `SIMULATION_RULES.md` Determinism rule 3: "All loops over process units, flow links, **and ports** iterate over explicitly ordered arrays sorted alphabetically" | `FlowSolver.solve_flows()` iterates `unit.ports` in dictionary insertion order (both passes); only `StorageUnit.solve_tick()` sorts port IDs | Benign for same-config replay (Godot dicts preserve insertion order) but a literal spec violation; permuting port declaration order in config could change float-summation order |
| 5 | `SIMULATION_RULES.md` flow mode 3: gravity formula given as a rule | `flow_link.gd`: GRAVITY unimplemented, warn-once fallback (correctly per Edge Rule 6 pattern) | Documented-but-unimplemented; handled loudly, acceptable |

Where it matters most, though, drift is *absent*: the Basin Availability Semantics spec (`SIMULATION_RULES.md` §Phase 3) matches `storage_unit.gd::set_in_service()` and `set_basin_service_command.gd` point-for-point (INLET/OUTLET disabled, DRAIN exempt, spill engine-routed, DAG static), and `plant_validator.gd` implements the promised `in_service` boolean checks (lines 61–62, 218–219) and spill-destination resolution (lines 112–122).

**[Risk Assessment]** MEDIUM. The project's own history shows why this matters: the WP2.4-R2 rejection called a wrong CONTROL_LOGIC section "spec poisoning" (`082015e`). Items 1–3 are the same hazard for future agents.

**[Recommended Action]** A docs-only WP: rewrite the KNOWN_LIMITATIONS control section; mark the contracts class table entries as implemented/planned; correct the plan's `max_output`; either add sorted-port iteration to FlowSolver or narrow rule 3 to units/links. Drift control going forward is already solved in principle by the spec-first WP pattern — apply it to *amendments* too (the damping change updated CONTROL_LOGIC in the same commit, which is the right template).

---

### Q5 — Environment / tooling fragility

**[Topic]** Stale mounts, git corruption, phantom diffs, and reviewer trust. Domain: `infrastructure`.

**[Stated Spec/Doc]** The review brief and `WP35_TUNING_TASK.md` (which records a NUL-corrupted `.git/config` "repaired in the reviewer's environment").

**[Actual Code State]**
- `.git/config` is clean at review time (verified by `od -c`: file ends `refs/heads/main\n`, no NUL bytes; `git config -l` parses).
- No leftover debug scripts (`tools/` contains only `ci/`; the `tmp_diag2.gd` cleanup demanded by WP35_TUNING_TASK was done).
- **Fragility is real and was observed directly during this review:** at session start, `git diff HEAD --stat` reported 6 modified files (+204/−12) including 147 added lines in `test_headworks_controller.gd`; minutes later the tree was clean, HEAD had advanced two commits, and the test-file additions appeared in **neither** commit. Whether those lines were a stale-view phantom or genuinely discarded work-in-progress, the effect on a reviewer is identical: observations against a floating HEAD are unreproducible.

**[Risk Assessment]** MEDIUM. None of this corrupts committed history (all Phase 3 commits are internally consistent), but it degrades exactly the thing the methodology depends on — the reviewer's ability to trust what they measured.

**[Recommended Action]** (1) Single-writer discipline during any audit window. (2) All reviews and reports pin and quote a commit hash (this report does). (3) Push to origin regularly so a third party (CI) holds the canonical execution record — this also mitigates the loss of local work if the environment misbehaves.

---

### Q6 — Determinism at scale

**[Topic]** Bit-exact replay and conservation over 100k ticks. Domain: `verification / core engine`.

**[Stated Spec/Doc]** `SIMULATION_RULES.md` §Determinism Mechanics (5 rules) and §Edge Rules; `PHASE3_IMPLEMENTATION_PLAN.md` §WP3.7 and §7 exit conditions 1–2 (100k soak, churn, bit-exact replay, zero ledger error).

**[Actual Code State]** The *mechanisms* are implemented and verifiable by inspection:
- Tick-stamped commands with next-tick clamping (`simulation_engine.gd::enqueue`); fixed-order 14-step tick; actuator slew before controller evaluation (one-tick lag, as documented).
- Kahn topological sort with lexicographic tie-breaking and cycle detection (`plant_factory.gd` step 6); all context registries rebuilt as ID-sorted arrays (step 5).
- Seeded RNG on the context (`simulation_context.gd`, seed 12345 — unused by any domain code so far, which is fine).
- Snapshot deep-duplication plus a mutation-detection hash assert (`_step_publish_snapshot`).
- An existing replay test (`tests/invariants/test_deterministic_replay.gd`) asserting state-hash equality over 10,000 ticks — but against **stub units**, not a real plant.

What does *not* exist at the review baseline: `test_phase3_verification.gd` and `test_phase3_invariants.gd` (absent from `git ls-tree -r 46481aa`). The 100k soak, availability churn, and full-plant bit-exact replay have **never been run**. One quantitative note for WP3.7: `mass_balance_tracker.gd` sets tolerance = `1e-9 × (initial + cumulative_inflow) × √ticks`; at 100k ticks and ~10 m³/s this is ≈ 0.3–0.6 m³ of allowed drift — reasonable for float accumulation, but the WP3.7 report should state the realized error against it, not just "passed."

**[Risk Assessment]** HIGH until WP3.7 executes — not because failure is likely (the architecture is genuinely determinism-friendly), but because this is the phase's central claim and it is currently 100 % untested at Phase 3 scale. Assumption flagged: "bit-exact replay works for the headworks plant" is unproven.

**[Recommended Action]** WP3.7 as planned, run by the reviewer (or CI) at a pinned hash. No design changes needed first.

---

### Q7 — Methodology cost/benefit

**[Topic]** Reviewer/implementer separation, batch audits, cold-start briefs. Domain: `process`.

**[Stated Spec/Doc]** `PHASE3_IMPLEMENTATION_PLAN.md` §8 Execution Protocol (batch audits at WP3.3 and WP3.8, hard-stop rules); AGENTS.md guardrails referenced throughout.

**[Actual Code State]** Evidence on both sides, all from git history:
- **Working:** the WP2.4 review chain caught and named spec poisoning (`082015e`); the WP3.3 batch audit produced four substantive remediation commits (`97356b3`…`3183b92`); the control-law escalation was handled exactly right — the implementing agent stopped, proved the defect structural with a gain sweep, and the orchestrator authorized a scoped, default-off fix instead of letting the test be gamed or the deadband widened (`WP35_CONTROL_LAW_DECISION.md` explicitly forbids both).
- **Leaking:** the batch-audit gap (WP3.4–3.7 unreviewed until WP3.8) is where the control-law defect, the capacity mismatch, and the stale CI count all lived; WP3.5 was committed while red despite the hard-stop rule; the CI script count went stale twice in a row; and near-duplicate commands (`SetUnitServiceCommand` and `SetBasinServiceCommand` — the latter a thin StorageUnit-validating wrapper over the former's behavior via `set_in_service`) suggest WP-scoped file ownership producing parallel implementations.

**[Risk Assessment]** LOW–MEDIUM. The expensive parts of the methodology (reviewer reruns, cold-start re-reading) are earning their cost — every serious defect so far was caught by them. The cheap part that's missing is *continuous automated* verification between human audits.

**[Recommended Action]** Don't add more human review; add the free machine check: push-per-WP with CI green as a protocol gate (see Q2). Consolidate the two service commands (keep `SetBasinServiceCommand` as the documented operator surface, or delete it in favor of the general one and update `PROCESS_UNIT_CONTRACTS.md` — either way, one implementation).

---

### Q8 — Portability claim (~95 %, three touch points)

**[Topic]** Wastewater/other-utility port feasibility. Domain: `architecture`.

**[Stated Spec/Doc]** `docs/BUILDING_A_PLANT_SIMULATOR.md` Appendix (committed in `b972214`): "~95 % portable … A port … touches exactly three things: boundary labels, ledger fields, display vocabulary. No changes are required to the flow solver, storage balance, port/link topology, control system, or tick cycle."

**[Actual Code State]** The string-level claim was verified independently: `git grep` at the review baseline confirms the boundary-type vocabulary appears in exactly `external_boundary.gd` (validation list), `mass_balance_tracker.gd` (ledger match), and `topology.schema.json` (enum), plus plant configs. Reading the solver, links, ports, and storage classes confirms no water-treatment semantics anywhere — it is a generic volume/flow/level engine.

**However, the appendix omits the one constraint that matters most for wastewater specifically:** the engine is a **strict DAG**. `PlantFactory` fails the build on any cycle (step 6 cycle detection, verified), and `SIMULATION_RULES.md` bans recirculation. A wastewater plant is built around recycle streams — return activated sludge, supernatant returns, backwash recovery. Those are not relabelings; they require the cyclic-network spec the roadmap defers. The "three touch points" claim is true for the code you'd *edit*, but "a wastewater plant … is just a different set of config files" overstates it.

**[Risk Assessment]** LOW (no near-term work depends on it), but the claim as written is the kind of aspirational statement Q4 warns about.

**[Recommended Action]** Amend the appendix: name "DAG-only topology (no recycle streams until a cyclic-network spec exists)" as the fourth — and structurally hardest — touch point. One sentence fixes it.

---

## 2. Consolidated findings register

| ID | Finding | Domain | Verdict | Risk | Cited evidence |
|----|---------|--------|---------|------|----------------|
| F-1 | GitHub CI has never run a Phase 3 commit; origin/main 31 commits behind | verification | CONFIRMED | **HIGH** | `git branch -vv`; `git ls-remote origin main` → `e5ce9de` |
| F-2 | CI `EXPECTED_SCRIPTS=26` vs 28 actual scripts — first push will fail CI | verification | CONFIRMED | **HIGH** | `tests.yml:48` at review baseline; per-commit script counts 26/27/28 |
| F-3 | WP3.7 soak/churn/replay and WP3.8 presentation/parity absent; phase exit conditions 1–4 unmet | verification | CONFIRMED | **HIGH** | `git ls-tree -r 46481aa` (no `test_phase3_verification.gd` / `test_phase3_invariants.gd` / `headworks.tscn`) |
| F-4 | GUT results (79/79) for `b972214`/`46481aa` are implementer-self-reported; unreproducible in review environment | verification | ASSUMPTION | HIGH | commit messages; no local Godot found |
| F-5 | Bumpless-transfer violation: AUTO cold start slams gates 50 %→0 %; stale error history on MANUAL→AUTO with kp=20 | control | CONFIRMED (code); consequence PLAUSIBLE | MEDIUM | `controller.gd` (`previous_output = 0.0`), `level_controller.gd` MANUAL branch, `controllers.json` (`AUTO`), `initial_conditions.json` (DB valves at 50) |
| F-6 | No unit tests for the new kp/kd law | verification | CONFIRMED | MEDIUM | `git show b972214 --stat` — no `tests/` files |
| F-7 | WP3.5 tests assert instantaneous level, the pattern WP2.4-R rejected | verification | CONFIRMED | MEDIUM | `test_headworks_controller.gd`; commits `5b48204`, `5849926` |
| F-8 | No authoritative design-flow basis; capacity coherence is one remediation commit deep | hydraulics | CONFIRMED | MEDIUM | `cf64d5e`; plan §WP3.2 "per-basin design capacity" undefined |
| F-9 | `KNOWN_LIMITATIONS.md` control section contradicts shipped controller on three counts | docs | CONFIRMED | MEDIUM | `KNOWN_LIMITATIONS.md:26` vs `level_controller.gd` |
| F-10 | Plan/config/doc mismatches: `max_output` 1.0 vs 100.0; contracts class table lists unbuilt classes | docs | CONFIRMED | LOW | plan §WP3.5; `controllers.json`; `PROCESS_UNIT_CONTRACTS.md:9–19` |
| F-11 | FlowSolver iterates ports in insertion order vs spec's "sorted" rule | determinism | CONFIRMED | LOW | `flow_solver.gd` both passes vs `SIMULATION_RULES.md` rule 3 |
| F-12 | Duplicate service commands (`SetUnitServiceCommand` / `SetBasinServiceCommand`) | architecture | CONFIRMED | LOW | both files at review baseline |
| F-13 | Portability appendix omits the DAG-only constraint as a wastewater blocker | architecture | CONFIRMED | LOW | `BUILDING_A_PLANT_SIMULATOR.md` appendix; `plant_factory.gd` cycle detection |
| F-14 | Repository mutated during review; 147 lines of test edits discarded uncommitted | infra | CONFIRMED (observed) | MEDIUM | session `git status`/`git log` deltas, `c7ef0e2` → `46481aa` |
| F-15 | Availability semantics, mass-balance ledger, proration solver, and validator match their binding specs | domain | CONFIRMED (positive) | — | `storage_unit.gd`, `flow_solver.gd`, `mass_balance_tracker.gd`, `plant_validator.gd` vs `SIMULATION_RULES.md` §Basin Availability, Edge Rules 1–6 |

---

## 3. Decision framework: Phase 3 acceptance checklist

**Current status: REJECT for acceptance — ACCEPT direction of travel.** WP3.0–WP3.6 are substantively done and largely spec-faithful; the phase gate (plan §7) has six conditions and, at `46481aa`, none of the six is verifiably met.

### Blockers — all must be true before G-Phase3 closes

- [ ] **B1.** Push main to origin with `EXPECTED_SCRIPTS` updated to the true count in the same push; GitHub CI green on origin/main. *(F-1, F-2)*
- [ ] **B2.** The 28-script / 79-test pass claim reproduced by the reviewer or by CI at a pinned hash — not by the implementing agent. *(F-4)*
- [ ] **B3.** WP3.7 written and passing under B2 conditions: 100k-tick soak, availability churn, full-plant bit-exact replay, `test_no_water_created_phase3`, DAG-static invariant — with the realized mass-balance error reported against the computed tolerance. *(F-3, Q6)*
- [ ] **B4.** WP3.8 delivered: `headworks.tscn`, extended presentation map, asset-panel service toggle via CommandBus only, parity test passing, W2.5-1 closed, zero `scripts/simulation/` diffs in the WP3.8 commit. *(F-3)*
- [ ] **B5.** Bumpless transfer resolved: either code fix (sync `previous_output` and error history on AUTO entry) or an explicit, spec-documented exemption for cold start. Given kp=20, the code fix is recommended. *(F-5)*

### Should-fix — acceptance may proceed with these logged as conditions

- [ ] **S1.** Docs reconciliation WP: `KNOWN_LIMITATIONS.md` control section, plan `max_output`, contracts class table. *(F-9, F-10)*
- [ ] **S2.** Unit tests for the velocity-PID increment (kp=kd=0 backward-compat equivalence + one damping case). *(F-6)*
- [ ] **S3.** Time-averaged level assertions in `test_headworks_controller.gd`, per the WP2.4-R3 precedent. *(F-7)*
- [ ] **S4.** Design-flow basis table; future `max_flow_m3s` values must cite it. *(F-8)*
- [ ] **S5.** Consolidate the two service commands into one documented implementation. *(F-12)*

### Notes for the next phase (no action required for acceptance)

- **N1.** Add the DAG-only caveat to the portability appendix. *(F-13)*
- **N2.** Sort FlowSolver port iteration or narrow the spec's rule 3 wording. *(F-11)*
- **N3.** Adopt single-writer + pinned-hash discipline for all future audits. *(F-14)*

---

## 4. Verification ledger

**Executed by the reviewer during this review:**
- All `git` evidence commands (`git show`, `git ls-tree`, `git log`, `git diff`, `git grep`, `git branch -vv`, `git ls-remote`) against pinned hashes.
- `tools/ci/validate_configs.sh` — exit 0; all Phase 1/2/3 configs validate positively and all six `schema_invalid` fixtures are rejected as intended.
- `od -c .git/config` — no NUL bytes.
- Filesystem search for a Godot executable — none found; GUT suite not runnable locally.

**Assumed (not reproduced):**
- GUT results "Scripts 28 / Tests 79 / Passing 79 / Failing 0" claimed in `b972214` and `46481aa`.
- The limit-cycle measurements (~0.5–3.5 m) and gain-sweep results recorded in the untracked WP3.5 working documents.

**Bottom line for the team:** the simulation core is sound and the hard control problem was solved the right way. What stands between here and Phase 3 acceptance is not engineering quality — it is that the phase's verification story currently rests entirely on self-reported numbers, with the two proof work packages (WP3.7, WP3.8) still unwritten and the CI safety net unplugged. Reconnect the net (push + fix the script count), let a third party run the suite, and finish the two remaining WPs; the should-fix list can ride along in the same window.
