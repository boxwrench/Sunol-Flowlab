extends "res://addons/gut/test.gd"

func _setup_engine(snapshot_mode: int = SimulationEngine.SNAPSHOT_MODE_EVERY_TICK) -> SimulationEngine:
	var engine: SimulationEngine = SimulationEngine.new()
	engine.snapshot_mode = snapshot_mode
	var config: Dictionary = ConfigLoader.load_plant_config("phase2_three_unit")
	assert_true(config.success, "Configuration should load successfully")
	
	var build_ok: bool = PlantFactory.build_plant(
		engine.context, 
		config.topology_data, 
		config.initial_conditions_data,
		config.controllers_data
	)
	assert_true(build_ok, "Factory build should succeed")
	return engine

func test_continuous_soak_100k_ticks() -> void:
	var engine: SimulationEngine = _setup_engine(SimulationEngine.SNAPSHOT_MODE_OFF)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 88888
	
	var src_res: StorageUnit = engine.context.units_dict[&"SOURCE_RESERVOIR"]
	var basin: StorageUnit = engine.context.units_dict[&"BASIN"]
	var rcv_res: StorageUnit = engine.context.units_dict[&"RECEIVING_RESERVOIR"]
	
	# Set valves to gradual travel for realistic simulation
	for act in engine.context.actuators_list:
		act.instant_mode = false
		
	# Start mass tracker
	var initial_total_volume: float = src_res.volume_m3 + basin.volume_m3 + rcv_res.volume_m3
	engine.mass_balance_tracker.initialize(initial_total_volume)
	
	var start_time_usec: float = float(Time.get_ticks_usec())
	
	# Run 100,000 ticks
	for tick in range(1, 100001):
		# Every 200 ticks, change setpoint and valve commands
		if tick % 200 == 1:
			var sp_val = rng.randf_range(2.0, 8.0)
			var ctrl_mode = &"AUTO" if rng.randf() > 0.3 else &"MANUAL"
			
			engine.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", sp_val, tick))
			engine.enqueue(SetControllerModeCommand.new(&"LC_BASIN", ctrl_mode, tick))
			
			# Set other non-controlled valves randomly
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", rng.randf_range(0.0, 100.0), tick))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_SRC", rng.randf_range(0.0, 100.0), tick))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", rng.randf_range(0.0, 100.0), tick))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_SRC", rng.randf_range(0.0, 20.0), tick))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_BASIN", rng.randf_range(0.0, 20.0), tick))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_RCV", rng.randf_range(0.0, 20.0), tick))
			
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		# Invariant checks: no storage unit volume goes negative
		assert_true(src_res.volume_m3 >= 0.0, "Source reservoir volume must be >= 0")
		assert_true(basin.volume_m3 >= 0.0, "Basin volume must be >= 0")
		assert_true(rcv_res.volume_m3 >= 0.0, "Receiving reservoir volume must be >= 0")
		
		# Periodically verify mass-ledger error via GUT asserts to keep the test log clean
		if tick % 1000 == 0:
			var current_total_storage: float = src_res.volume_m3 + basin.volume_m3 + rcv_res.volume_m3
			var report: Dictionary = engine.mass_balance_tracker.report(current_total_storage)
			var scale: float = max(initial_total_volume + engine.mass_balance_tracker.cumulative_inflow_m3, 1.0)
			var tolerance: float = 1e-9 * scale * sqrt(float(tick))
			assert_lt(abs(report.mass_balance_error_m3), tolerance, "Ledger error at tick %d must be within tolerance" % tick)
			
	var duration_ms: float = (float(Time.get_ticks_usec()) - start_time_usec) / 1000.0
	print("WP2.6 Benchmark: 100,000 ticks took %f ms" % duration_ms)

func test_boundary_starvation_and_spill() -> void:
	var engine := _setup_engine()
	
	var src_res: StorageUnit = engine.context.units_dict[&"SOURCE_RESERVOIR"]
	var basin: StorageUnit = engine.context.units_dict[&"BASIN"]
	var rcv_res: StorageUnit = engine.context.units_dict[&"RECEIVING_RESERVOIR"]
	
	var valve_in: SimValve = engine.context.actuators_dict[&"VALVE_IN"]
	var valve_out_src: SimValve = engine.context.actuators_dict[&"VALVE_OUT_SRC"]
	var valve_out_basin: SimValve = engine.context.actuators_dict[&"VALVE_OUT_BASIN"]
	var valve_out_rcv: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RCV"]
	
	# Set valves to instant mode
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	# 1. Starvation: Close VALVE_IN, open all outlets
	engine.enqueue(SetControllerModeCommand.new(&"LC_BASIN", &"MANUAL"))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_SRC", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_BASIN", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", 100.0))
	
	# Run 300 ticks to deplete
	for tick in range(1, 301):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Verify units are starved and stop at min operating level (0.5m elevation = 50.0m3 volume)
	assert_almost_eq(src_res.volume_m3, 50.0, 1e-3)
	assert_almost_eq(basin.volume_m3, 50.0, 1e-3)
	assert_almost_eq(rcv_res.volume_m3, 50.0, 1e-3)
	assert_eq(src_res.outflow_m3s, 0.0)
	assert_eq(basin.outflow_m3s, 0.0)
	assert_eq(rcv_res.outflow_m3s, 0.0)
	
	# Reset tracker for the next phase
	engine.mass_balance_tracker.is_initialized = false
	
	# 2. Spill: Close VALVE_OUT_SRC, fully open VALVE_IN
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_SRC", 0.0))
	
	# Run 200 ticks to trigger overflow/spill
	for tick in range(301, 501):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Source Reservoir spill level = 9.5m, area = 100m2 -> spill volume = 950.0m3
	assert_almost_eq(src_res.volume_m3, 950.0, 1e-3, "Volume must clamp at spill level")
	assert_gt(src_res.spill_flow_m3s, 0.0, "Spill flow must be active")
	
	var spill_sink: ExternalBoundary = engine.context.units_dict[&"SPILL_SINK"]
	assert_almost_eq(spill_sink.current_flow_m3s, src_res.spill_flow_m3s, 1e-3, "Spill flow must route to SPILL_SINK")

func test_deterministic_command_replay() -> void:
	var engine1 := _setup_engine()
	var engine2 := _setup_engine()
	
	# Enqueue same random commands to both engines
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	
	for i in range(1, 1001, 50):
		var sp = rng.randf_range(2.0, 8.0)
		var mode = &"AUTO" if rng.randf() > 0.5 else &"MANUAL"
		var pos = rng.randf_range(0.0, 100.0)
		
		engine1.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", sp, i))
		engine1.enqueue(SetControllerModeCommand.new(&"LC_BASIN", mode, i))
		engine1.enqueue(SetValvePositionCommand.new(&"VALVE_IN", pos, i))
		
		engine2.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", sp, i))
		engine2.enqueue(SetControllerModeCommand.new(&"LC_BASIN", mode, i))
		engine2.enqueue(SetValvePositionCommand.new(&"VALVE_IN", pos, i))
		
	# Run 1,000 ticks
	for tick in range(1, 1001):
		engine1.clock.tick_count = tick
		engine1.context.current_tick = tick
		engine1.run_tick(1.0)
		
		engine2.clock.tick_count = tick
		engine2.context.current_tick = tick
		engine2.run_tick(1.0)
		
	var hash1 := _get_engine_state_hash(engine1)
	var hash2 := _get_engine_state_hash(engine2)
	
	assert_eq(hash1, hash2, "Command replay must yield identical state hashes")

func _get_engine_state_hash(engine: SimulationEngine) -> String:
	var parts: Array[String] = []
	parts.append(str(engine.clock.tick_count))
	for unit in engine.context.units_list:
		if unit is StorageUnit:
			parts.append(String(unit.unit_id) + ":vol=" + str(unit.volume_m3) + ":lvl=" + str(unit.level_m))
	for act in engine.context.actuators_list:
		parts.append(String(act.actuator_id) + ":pos=" + str(act.position) + ":cmd=" + str(act.commanded_position))
	for ctrl in engine.context.controllers_list:
		parts.append(String(ctrl.controller_id) + ":mode=" + str(ctrl.control_mode) + ":sp=" + str(ctrl.get("setpoint")))
	return ",".join(parts)
