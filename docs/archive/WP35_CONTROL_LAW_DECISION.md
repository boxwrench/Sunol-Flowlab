# WP3.5 Control-Law Damping — Decision and Brief (historical)

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Orchestrator decision and follow-on brief for WP3.5 control-law damping. First committed 2026-07-04.
> Titled "Next Task" as written — it is not a live instruction. Do not execute it.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

[ESCALATION ACCEPTED]
Your gain scan correctly proved this is structural: an I-only velocity-form controller
(`output = previous_output + gain*error`) on an effectively integrating plant is undamped at ANY
gain — gain sets oscillation frequency/onset, not decay. Good call stopping instead of gaming the
test or silently editing the control law. The two banked commits stand:
- cf64d5e  WP3.4: LINK_OUT_AC_01 15→10
- c7ef0e2  WP3.5: MANUAL-mode test isolation (3 files)

[DECISION]
Add the missing proportional + derivative damping to LevelController, in a STRICTLY
backward-compatible way, then have phase3 opt in. The plan already describes these controllers as
"proportional demand signals" — I-only was the latent defect. This is authorized as a minimal,
Phase-3-scoped, default-OFF enhancement; it is NOT a phase2 reopening because existing configs
compute identical output.

[STRICT SCOPE + SAFETY INVARIANT]
- The new proportional gain `kp` and derivative gain `kd` MUST default to 0.0. With kp=kd=0 the
  arithmetic is identical to today, so phase1/phase2 behavior is byte-for-byte unchanged. This is
  the invariant that keeps this from reopening Phase 2 — preserve it exactly.
- Only phase3's controllers.json opts in with nonzero kp (and kd if needed).
- Keep `deadband_m = 0.05` (do NOT widen it to pass — the test uses it as its tolerance).
- No changes to the plant/topology, the solver, or other domain classes.

[IMPLEMENTATION]
1. scripts/simulation/automation/level_controller.gd — velocity-form PID increment:
   - Add fields: `var kp: float = 0.0`, `var kd: float = 0.0`, `var previous_error: float = 0.0`,
     `var previous_error2: float = 0.0`.
   - In initialize(): `kp = float(config.get("kp", 0.0))`, `kd = float(config.get("kd", 0.0))`,
     and reset `previous_error = 0.0`, `previous_error2 = 0.0`.
   - In evaluate(), keep everything (MANUAL/AUTO handling, deadband hold, clamp) and change ONLY
     the increment when `abs(error) > deadband_m`:
     ```
     var d_out: float = gain * error \
                      + kp * (error - previous_error) \
                      + kd * (error - 2.0 * previous_error + previous_error2)
     output = previous_output + d_out
     ```
     Then update history every tick: `previous_error2 = previous_error; previous_error = error`
     (and `previous_output = output` as today). With kp=kd=0 the extra terms vanish → unchanged.
   - Extend get_snapshot()/state as needed but keep existing keys intact.

2. config/schema/controllers.schema.json — add `kp` and `kd` as optional number properties
   (default 0.0). This must be done WITH this change so validate_configs stays green (the schema
   is additionalProperties:false). This also satisfies part of WP3.6's schema-sync obligation.

3. config/plants/phase3_headworks/controllers.json — set a stabilizing `kp` on all five (and `kd`
   only if kp alone doesn't damp). Tuning notes:
   - Effective loop gain is ~5x (five controllers push the same error), so keep everything SMALL.
   - kp provides the damping (proportional action); keep the integral `gain` modest so it only
     trims steady-state offset. Start e.g. gain ~0.05–0.1, kp ~0.5–1.0, kd 0; increase kd only if
     residual oscillation remains. Tune empirically with a scratch (uncommitted, deleted-after)
     diagnostic until BOTH tests settle and STAY within ±0.05 of 2.0.
   - Lengthening the test's settling window is acceptable if a stable tuning needs >1000 ticks;
     widening the pass tolerance is not.

4. docs: add a one-line note in docs/CONTROL_LOGIC.md that LevelController is a velocity-form PID
   (I-only when kp=kd=0), and a CHANGELOG entry.

[FALLBACK — only if PID cannot stabilize]
If no (gain,kp,kd) yields a stable in-band settle (should not happen for this plant), STOP and
report again. The next lever would be restructuring the loop (local per-basin level control), a
larger design change — do not attempt it silently.

[VERIFICATION — run and paste all]
1. FULL suite first, to PROVE no phase1/phase2 regression (kp=kd=0 path):
   `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
   → 0 failing, no parse errors, no skips. Confirm previously-green phase1/phase2 counts are
   unchanged and the two test_headworks_controller.gd tests now pass.
2. `bash tools/ci/validate_configs.sh` → exit 0 (controllers.json with kp/kd validates).
3. `git diff --check` ; `git status --short` → clean.

[COMMIT]
One coherent commit, message `WP3.5:` (control-law damping): level_controller.gd + controllers
schema + phase3 controllers.json + CONTROL_LOGIC.md + CHANGELOG. Report the chosen gain/kp/kd and
why, and explicitly confirm the kp=kd=0 default keeps phase2 identical.

[THEN] Resume WP3.6 per WP36_KICKOFF.md (presentation_map.json). Note: kp/kd are now already in
the controllers schema, so WP3.6's schema-sync is partly done — just don't re-add them. Stop for
orchestrator review before WP3.7.
