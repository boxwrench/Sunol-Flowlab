# Next Task — WP3.5 controller retune + bank the approved fixes, then resume WP3.6

[CONTEXT — verified by orchestrator]
The WP3.4 capacity fix (LINK_OUT_AC_01 15→10) and the test-isolation MANUAL-mode fixes worked:
full suite went 6 failing → 2 failing. The remaining 2 failures are both in
tests/integration/phase3_headworks/test_headworks_controller.gd and are a control-loop TUNING
problem, not capacity.

Root cause (confirmed against committed level_controller.gd @ ee2716b):
`LevelController` is a velocity-form INTEGRAL controller with a deadband hold —
`if abs(error) > deadband_m: output = previous_output + gain*error` (clamped 0..100). Five of
these run in parallel on the SAME shared PV (APPLIED_CHANNEL_01.level_m), each driving its own
basin gate. Level is itself an integrator, so this is integral control of an integrating plant
(undamped), and because all five push on the same error the EFFECTIVE loop gain ≈ 5 × gain = 10.
Result: the level limit-cycles around 2.0 (sampled at 1.58 and 2.12), never resting inside the
0.05 deadband.

[STEP 0 — housekeeping]
- Delete the leftover debug script: `rm -f tools/debug/tmp_diag2.gd` (and remove tools/debug if
  empty). Do NOT commit any debug/diagnostic scripts.
- Confirm `git config -l` works (a corrupted .git/config with trailing NUL bytes on "line 14" was
  found and repaired in the reviewer's environment; verify yours is clean — the valid file ends at
  the `[branch "main"]` block).

[STEP 1 — BANK the two already-approved, already-verified fixes as separate commits]
Do this BEFORE chasing the tuning issue, so proven progress is committed:
1. `WP3.4:` — topology.json `LINK_OUT_AC_01.max_flow_m3s` 15.0 → 10.0.
2. `WP3.5:` — the test-isolation fix (force LC_BASIN_01..05 to MANUAL in _setup_engine) across
   test_distribution_box.gd, test_basin_availability_integration.gd, test_basin_availability.gd.
Each commit: clean scope, message prefix as shown, and `git diff --check` clean.

[STEP 2 — retune the controllers (WP3.5 config scope ONLY)]
Goal: both tests in test_headworks_controller.gd settle and STAY within ±0.05 of setpoint 2.0.

- Edit ONLY config/plants/phase3_headworks/controllers.json. Reduce `gain` substantially on all
  five controllers (combined gain is ~5×, so 2.0 is far too hot). Start around 0.2–0.4 and tune
  empirically. Keep all five identical (same gain/deadband/setpoint) per the plan's design.
- Use your (uncommitted, deleted-after) diagnostic to distinguish limit-cycle vs slow-convergence
  and to confirm the level enters the deadband-hold region near zero net flow and stays.
- HARD GUARDRAILS:
  * Do NOT widen `deadband_m` to pass. The test asserts `|level - setpoint| <= deadband_m`, so
    inflating the deadband just games the check. Keep it tight (0.05).
  * Do NOT modify scripts/simulation/automation/level_controller.gd or any domain class (shared
    with phase2).
  * Lengthening the settling window in the test is acceptable if a stable gain needs more than
    1000 ticks (the plan says "after settling"); widening the pass tolerance is not.
- ESCALATION: if NO gain yields a stable settle within 0.05 (persistent undamped limit cycle),
  STOP and report to the orchestrator. That means the velocity-form integrator lacks damping and
  the control law itself needs a design change — out of WP3.5 scope, orchestrator decision
  required. Do not silently change the control law.

Commit the retune as its own `WP3.5:` commit once both tests pass.

[STEP 3 — full re-verification]
- `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/phase3_headworks -ginclude_subdirs -gexit`
- `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  → 0 failing, no parse errors, no skipped scripts. Paste Scripts/Tests/Passing/Failing.
- `bash tools/ci/validate_configs.sh` → exit 0.
- `git diff --check` and `git status --short` → clean.
Paste all summaries.

[STEP 4 — only after the suite is fully green, resume WP3.6]
Proceed with the WP3.6 deliverable per WP36_KICKOFF.md (author phase3_headworks/presentation_map.json,
do NOT add the P3-A5 heuristic, do NOT edit validate_configs.sh). Commit `WP3.6:` separately.

[HANDOFF]
Report: the four commit hashes/messages (WP3.4 capacity, WP3.5 test-isolation, WP3.5 retune, WP3.6),
the final full-suite summary, the chosen gain value and why, and confirmation that deadband_m and
level_controller.gd were NOT changed. Stop for orchestrator review before WP3.7.
