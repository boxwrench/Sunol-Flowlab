# WP3.5 Control-Law Damping — Cold-Start Prompt (historical)

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Cold-start prompt for WP3.5 control-law damping, then WP3.6. First committed 2026-07-04.
> Written as a cold-start prompt — it is not a live instruction. Do not execute it.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

[ROLE]
You are the implementation agent for Sunol FlowLab, a deterministic Godot 4.x / GDScript
drinking-water simulator. Work from the repository's actual committed code and
`docs/PHASE3_IMPLEMENTATION_PLAN.md` — not from any prior chat summary. Follow AGENTS.md exactly.

[REPOSITORY]  C:\Github\Sunol FlowLab
[HEAD]  c7ef0e2  (recent line, newest first):
  - c7ef0e2  WP3.5: Force LC_BASIN_01..05 to MANUAL in pre-existing manual-valve tests
  - cf64d5e  WP3.4: Reduce LINK_OUT_AC_01 capacity 15→10 to match sustainable trunk supply
  - ee2716b  WP3.5: Level Controllers for Applied-Channel Regulation
  - d6e72b6  WP3.4: Applied Channel Config + Level Alarm

[SITUATION]
The Phase 3 headworks plant has five `LevelController` instances (LC_BASIN_01..05) in AUTO,
all regulating `APPLIED_CHANNEL_01.level_m` to setpoint 2.0 m by modulating the five basin inlet
gates (VALVE_OUT_DB_01..05). Two integration tests in
`tests/integration/phase3_headworks/test_headworks_controller.gd` fail:
  - test_five_controllers_stabilize_applied_channel_level
  - test_controller_redistribution_on_basin_loss
The applied-channel level never settles inside ±0.05 m of 2.0; it limit-cycles (~0.5 m to ~3.5 m).

[ROOT CAUSE — already diagnosed and confirmed]
`LevelController.evaluate()` is a velocity-form INTEGRAL-only controller
(`output = previous_output + gain*error`, with a deadband hold and a clamp). The applied channel
is an integrating process whose outflow is a FIXED demand (LINK_OUT_AC_01 has no actuator and
GRAVITY/level-dependent flow is unimplemented), so the plant has no self-regulation. An I-only
controller on an integrating plant is UNDAMPED at any gain — a full gain sweep
({1.0,0.5,0.2,0.1,0.05,0.02,0.01,0.005}) confirmed gain only changes oscillation onset/frequency,
never amplitude/decay. This is structural, not a tuning problem. (The implementation plan even
describes these controllers as "proportional demand signals" — the I-only law was the latent defect.)

[ORCHESTRATOR DECISION — AUTHORIZED]
Add proportional + derivative damping to LevelController in a STRICTLY backward-compatible way,
defaulting the new terms to zero, then have phase3 opt in. This is a minimal, Phase-3-scoped,
default-OFF enhancement — NOT a Phase-2 reopening, because with the new gains at 0 the arithmetic
is byte-identical for every existing config.

[SAFETY INVARIANT — do not violate]
New proportional gain `kp` and derivative gain `kd` MUST default to 0.0. With kp=kd=0, output must
be identical to the current behavior, so phase1/phase2 are unchanged. Only
`config/plants/phase3_headworks/controllers.json` sets nonzero kp (and kd if needed).
Keep `deadband_m = 0.05` (do NOT widen it — the test uses it as its pass tolerance). Do NOT change
the plant/topology, the solver, or any other domain class.

[STEP 0 — housekeeping]
- Confirm a clean working tree on Windows: `git status --short` should show only untracked task
  markdown files. If tracked files appear modified unexpectedly, stop and report before editing.
- Confirm `git config -l` works (a valid .git/config ends at the `[branch "main"]` block).
- Do NOT commit any debug/diagnostic scripts; delete any you create when done.

[STEP 1 — LevelController velocity-form PID (backward compatible)]
Edit `scripts/simulation/automation/level_controller.gd`:
- Add fields: `var kp: float = 0.0`, `var kd: float = 0.0`, `var previous_error: float = 0.0`,
  `var previous_error2: float = 0.0`.
- In `initialize(config)`: `kp = float(config.get("kp", 0.0))`, `kd = float(config.get("kd", 0.0))`,
  and reset `previous_error = 0.0`, `previous_error2 = 0.0`.
- In `evaluate()`, keep MANUAL/AUTO handling, the `abs(error) > deadband_m` deadband hold, and the
  final clamp EXACTLY as they are. Change ONLY the increment computed when outside the deadband:
    ```
    var d_out: float = gain * error \
                     + kp * (error - previous_error) \
                     + kd * (error - 2.0 * previous_error + previous_error2)
    output = previous_output + d_out
    ```
  Then each tick update history: `previous_error2 = previous_error`; `previous_error = error`;
  `previous_output = output` (as today). With kp=kd=0 the added terms are 0 → identical output.
- Keep all existing get_snapshot() keys; you may add kp/kd/previous_error if useful, but do not
  remove or rename anything.

[STEP 2 — schema]
Edit `config/schema/controllers.schema.json`: add optional number properties `kp` and `kd`
(default 0.0). Required because the schema is `additionalProperties:false`. (This also satisfies
part of WP3.6's schema-sync — do not re-add them later.)

[STEP 3 — tune phase3 controllers]
Edit `config/plants/phase3_headworks/controllers.json`: set stabilizing `kp` on all five entries
(and `kd` only if kp alone leaves residual oscillation). Keep all five identical.
- Effective loop gain is ~5x (five controllers act on the same error) — keep every gain SMALL.
- `kp` supplies damping; keep the integral `gain` modest (it only trims steady-state offset).
- Suggested starting point: gain ~0.05–0.1, kp ~0.5–1.0, kd 0; raise kd only if needed.
- Tune with a scratch (uncommitted, deleted-after) diagnostic until BOTH failing tests settle and
  STAY within ±0.05 of 2.0. Lengthening the test settling window (>1000 ticks) is acceptable;
  widening the pass tolerance is not.

[STEP 4 — docs]
Add a one-line note to `docs/CONTROL_LOGIC.md` that LevelController is a velocity-form PID
(I-only when kp=kd=0). Add a CHANGELOG entry.

[FALLBACK]
If no (gain, kp, kd) achieves a stable in-band settle (not expected), STOP and report — do not
restructure the loop or edit the plant silently.

[VERIFICATION — run and paste all output]
1. FULL suite first (proves no phase1/phase2 regression via the kp=kd=0 path):
   `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
   → 0 failing, no parse errors, no skipped scripts. Confirm previously-green phase1/phase2 counts
   are unchanged and both test_headworks_controller.gd tests now pass.
2. `bash tools/ci/validate_configs.sh` → exit 0 (controllers.json with kp/kd validates).
3. `git diff --check` and `git status --short` → clean.

[COMMIT]
One coherent commit, message begins `WP3.5:` (control-law damping): level_controller.gd +
controllers.schema.json + phase3 controllers.json + CONTROL_LOGIC.md + CHANGELOG. In the report,
state the chosen gain/kp/kd and rationale, and explicitly confirm the kp=kd=0 default leaves
phase1/phase2 byte-identical.

[THEN — resume WP3.6]
Author `config/plants/phase3_headworks/presentation_map.json` per the schema (top-level object
with a required `units` array; each entry `unit_id` required, optional `scene`/`position_m`/
`rotation_deg`; omit `scene` — no .tscn until WP3.8; additionalProperties is false). Do NOT add
any sizing heuristic to plant_validator.gd; do NOT edit tools/ci/validate_configs.sh (it
auto-discovers the file). Commit `WP3.6:` separately. Then STOP for orchestrator review before
WP3.7.
