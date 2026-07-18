# WP3.7 Verification & Soak Suite — Kickoff Prompt (historical)

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Kickoff cold-start prompt for WP3.7 Phase 3 verification and soak suite. First committed 2026-07-04.
> Written as a cold-start prompt — it is not a live instruction. Do not execute it.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

[ROLE]
You are the implementation agent for Sunol FlowLab, a deterministic Godot 4.x / GDScript
drinking-water simulator. Work from the repository's actual committed code and
`docs/PHASE3_IMPLEMENTATION_PLAN.md` §4 "WP3.7" — not from any prior chat summary. Follow AGENTS.md.

[REPOSITORY]  C:\Github\Sunol FlowLab
[START ONLY AFTER] WP3.6 is committed with a clean tree and the full suite green.

[STRICT SCOPE]
Verification/soak/invariant TESTS ONLY. No production, domain, solver, or config changes. If a
test cannot pass without changing production code, STOP and report it as a finding — do not edit
production to make a test green (this suite is exactly what the reviewer re-runs at the WP3.8
audit). No scene/UI work. Do not modify review-verdict docs. Do not begin WP3.8.

[FILES TO CREATE]
- tests/integration/phase3_headworks/test_phase3_verification.gd
- tests/invariants/test_phase3_invariants.gd

[THE FIVE TESTS] (per plan §4 WP3.7)
test_phase3_verification.gd:
  1. test_phase3_soak_100k_ticks — full headworks topology, 100,000 ticks, inflow/demand ramped
     up and down every 5000 ticks. Assert zero mass-balance error (tolerance form below) and no
     negative volume on any unit.
  2. test_availability_churn_100k_ticks — toggle basins in/out of service every 500 ticks over
     100,000 ticks, choices driven by the SEEDED context RNG. Assert ledger error within tolerance
     and no negative volume.
  3. test_deterministic_replay_phase3 — record a 1000-tick command sequence, replay from an
     identical fresh build, assert bit-identical state hashes.
test_phase3_invariants.gd:
  4. test_no_water_created_phase3 — mass conservation over a 10,000-tick run (tolerance form below).
  5. test_dag_unchanged_after_availability_toggle — assert context.topological_units_list is
     identical (same size, same unit objects/order) before and after a basin goes out of service.

──────────────────────────────────────────────────────────────────────────────
[VERIFIED API REFERENCE — use these exact signatures (confirmed against committed code @ ee2716b)]

Setup boilerplate (mirror the Phase 2 verification test):
    func _setup_engine() -> SimulationEngine:
        var engine := SimulationEngine.new()
        var config: Dictionary = ConfigLoader.load_plant_config("phase3_headworks")
        assert_true(config.success, "Config should load")
        var ok: bool = PlantFactory.build_plant(engine.context, config.topology_data,
            config.initial_conditions_data, config.controllers_data)
        assert_true(ok, "Factory build should succeed")
        return engine

Tick advance (per tick, dt = 1.0 — no special 60x handling needed; determinism is per-tick):
    engine.clock.tick_count = tick
    engine.context.current_tick = tick
    engine.run_tick(1.0)

Mass-balance tracker:
    engine.mass_balance_tracker.initialize(initial_total_volume)   # sum of all StorageUnit volumes at t0
    var current_storage := 0.0
    for u in engine.context.units_list:
        if u is StorageUnit: current_storage += u.volume_m3
    var report: Dictionary = engine.mass_balance_tracker.report(current_storage)
    # report.mass_balance_error_m3 is the residual; other keys: cumulative_inflow_m3, etc.

MASS-BALANCE ASSERTION — use the EXACT Phase 2 form (do NOT invent a tolerance):
    var scale: float = max(initial_total_volume + engine.mass_balance_tracker.cumulative_inflow_m3, 1.0)
    var tolerance: float = 1e-9 * scale * sqrt(float(tick))
    assert_lt(abs(report.mass_balance_error_m3), tolerance,
        "Ledger error at tick %d must be within tolerance" % tick)

No-negative-storage (check every tick, direct property, no epsilon):
    for u in engine.context.units_list:
        if u is StorageUnit:
            assert_true(u.volume_m3 >= 0.0, "%s volume must be >= 0" % u.unit_id)

Seeded RNG (REQUIRED for churn/soak randomness — never use unseeded Randomize):
    engine.context.rng.seed = 12345          # field: rng: RandomNumberGenerator
    var v := engine.context.rng.randf_range(0.0, 100.0)
    var i := engine.context.rng.randi_range(0, 4)

DAG list (invariant #5):
    context.topological_units_list   # Array of ProcessUnit objects, Kahn-sorted, static under toggles
    # capture size + object refs before/after a SetBasinServiceCommand and assert identical

Commands for churn/soak (constructors: (id, value, apply_tick=0)):
    SetBasinServiceCommand.new(&"BASIN_01", false)     # take out of service
    SetBasinServiceCommand.new(&"BASIN_01", true)      # restore
    SetValvePositionCommand.new(&"VALVE_IN_01", 50.0)  # 0..100 percent  (ramp inflow/demand)
    SetLevelSetpointCommand.new(&"LC_BASIN_01", 2.0)
    SetControllerModeCommand.new(&"LC_BASIN_01", &"AUTO")
    engine.enqueue(cmd)   # apply_tick<=current_tick auto-bumps to current_tick+1

Deterministic replay — build TWO engines, same seed, same command sequence, compare a state hash.
Mirror the Phase 2 helper (tests/invariants/test_deterministic_replay.gd and the phase2
verification test); use a hash over stable fields:
    func _state_hash(engine) -> String:
        var parts: Array[String] = [str(engine.clock.tick_count)]
        for u in engine.context.units_list:
            if u is StorageUnit:
                parts.append("%s:vol=%s:lvl=%s" % [u.unit_id, u.volume_m3, u.level_m])
        for a in engine.context.actuators_list:
            parts.append("%s:pos=%s:cmd=%s" % [a.actuator_id, a.position, a.commanded_position])
        for c in engine.context.controllers_list:
            parts.append("%s:mode=%s:sp=%s" % [c.controller_id, c.control_mode, c.get("setpoint")])
        return ",".join(parts)
    assert_eq(_state_hash(engine1), _state_hash(engine2), "Replay must be bit-identical")
    # (Alternatively SnapshotService.take_snapshot(context, engine) then compare str(snap).hash().)

Inflow/demand ramp for the soak (every 5000 ticks): modulate source/inlet valve positions via
SetValvePositionCommand using the seeded RNG or a deterministic ramp function of tick — keep it
reproducible.
──────────────────────────────────────────────────────────────────────────────

[DETERMINISM REQUIREMENTS]
- All randomness through engine.context.rng only. Same seed ⇒ identical run.
- Production ConfigLoader + PlantFactory + domain classes only. Do not recreate solver/tick/balance
  logic in the test.
- 100k-tick tests must finish headless in reasonable time; keep per-tick work on production paths,
  avoid per-tick allocations in the harness. Print a Time.get_ticks_usec() benchmark like Phase 2.

[VERIFICATION — run and paste exact output]
1. Targeted:
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/phase3_headworks -ginclude_subdirs -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/invariants -ginclude_subdirs -gexit
   → all five WP3.7 tests passing, 0 failing.
2. Full suite:
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
   → 0 failing, no parse errors, no skipped scripts. Paste Scripts/Tests/Passing/Failing counts.
3. bash tools/ci/validate_configs.sh → exit 0.
4. git diff --check ; git status --short → clean.

[HANDOFF]
Commit with a message beginning `WP3.7:`. Report the runner summaries (include the 100k-tick
results + wall-clock), validate_configs result, and changed files. Update CHANGELOG.md. Leave a
clean tree. This is the last WP before the WP3.8 BATCH AUDIT — STOP for orchestrator review; the
reviewer will re-run this soak suite from a clean checkout. Do NOT begin WP3.8 until authorized.
