extends "res://addons/gut/test.gd"

func _setup_engine() -> SimulationEngine:
	var engine: SimulationEngine = SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("phase1_single_basin")
	assert_true(config.success)
	
	var build_ok: bool = PlantFactory.build_plant(engine.context, config.topology_data, config.initial_conditions_data)
	assert_true(build_ok)
	
	engine.mass_balance_tracker.initialize(500.0)
	
	var alarm: ThresholdAlarm = ThresholdAlarm.new()
	alarm.initialize({
		"alarm_id": &"ALARM_HIGH",
		"display_name": "High level alarm",
		"target_unit_id": &"BASIN_01",
		"target_property": "level_m",
		"alarm_type": "HIGH",
		"threshold_value": 9.0,
		"delay_s": 0.0,
		"deadband": 0.1,
		"message": "Basin high level!"
	})
	engine.alarm_engine.register_alarm(alarm)
	
	return engine

func test_demo_a_level_rises() -> void:
	var engine: SimulationEngine = _setup_engine()
	var storage: StorageUnit = engine.context.units_dict[&"BASIN_01"]
	var initial_volume: float = storage.volume_m3
	
	# Initial configuration from JSON has VALVE_IN = 50%, VALVE_OUT = 0%.
	# No commands needed for tick 1-10 because it's already in positive net inflow.
	for tick in range(1, 11):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		var report: Dictionary = engine.mass_balance_tracker.report(storage.volume_m3)
		assert_lt(abs(report.mass_balance_error_m3), 1e-9, "Ledger error must be < 1e-9")
		
	assert_gt(storage.volume_m3, initial_volume, "Volume should have risen")
	assert_gt(storage.level_m, 5.0, "Level should have risen")

func test_demo_b_level_falls() -> void:
	var engine: SimulationEngine = _setup_engine()
	var storage: StorageUnit = engine.context.units_dict[&"BASIN_01"]
	
	# Enable instant mode on valves for test convenience
	var valve_in: SimValve = engine.context.actuators_dict[&"VALVE_IN"]
	var valve_out: SimValve = engine.context.actuators_dict[&"VALVE_OUT"]
	valve_in.instant_mode = true
	valve_out.instant_mode = true
	
	# Enqueue commands to close inlet and fully open outlet
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT", 100.0))
	
	var initial_volume: float = storage.volume_m3
	
	# Run ticks. Commands will apply on tick 1.
	for tick in range(1, 11):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		var report: Dictionary = engine.mass_balance_tracker.report(storage.volume_m3)
		assert_lt(abs(report.mass_balance_error_m3), 1e-9, "Ledger error must be < 1e-9")
		
	assert_lt(storage.volume_m3, initial_volume, "Volume should have fallen")
	assert_lt(storage.level_m, 5.0, "Level should have fallen")

func test_demo_c_spill_and_alarm() -> void:
	var engine: SimulationEngine = _setup_engine()
	var storage: StorageUnit = engine.context.units_dict[&"BASIN_01"]
	
	var valve_in: SimValve = engine.context.actuators_dict[&"VALVE_IN"]
	var valve_out: SimValve = engine.context.actuators_dict[&"VALVE_OUT"]
	valve_in.instant_mode = true
	valve_out.instant_mode = true
	
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT", 0.0))
	
	var alarm: ThresholdAlarm = engine.alarm_engine.alarms_dict[&"ALARM_HIGH"]
	
	var reached_spill: bool = false
	var alarm_activated: bool = false
	
	for tick in range(1, 201):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		var report: Dictionary = engine.mass_balance_tracker.report(storage.volume_m3)
		assert_lt(abs(report.mass_balance_error_m3), 1e-8, "Ledger error must be < 1e-8")
		
		if storage.spill_flow_m3s > 0.0:
			reached_spill = true
		if alarm.is_active:
			alarm_activated = true
			
	assert_true(reached_spill, "Spill flow should have started")
	assert_true(alarm_activated, "High-level alarm should have activated")
	assert_almost_eq(storage.volume_m3, 950.0, 1e-3, "Volume should be clamped to spill volume (950)")

func test_demo_d_empty_to_zero() -> void:
	var engine: SimulationEngine = _setup_engine()
	var storage: StorageUnit = engine.context.units_dict[&"BASIN_01"]
	
	var valve_in: SimValve = engine.context.actuators_dict[&"VALVE_IN"]
	var valve_out: SimValve = engine.context.actuators_dict[&"VALVE_OUT"]
	var valve_drain: SimValve = engine.context.actuators_dict[&"VALVE_DRAIN"]
	
	valve_in.instant_mode = true
	valve_out.instant_mode = true
	valve_drain.instant_mode = true
	
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN", 100.0))
	
	for tick in range(1, 201):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		var report: Dictionary = engine.mass_balance_tracker.report(storage.volume_m3)
		assert_lt(abs(report.mass_balance_error_m3), 1e-9, "Ledger error must be < 1e-9")
		assert_true(storage.volume_m3 >= 0.0, "Volume must never be negative")
		
	assert_eq(storage.volume_m3, 0.0, "Basin should be empty (exactly 0.0)")

func test_headless_parity() -> void:
	var engine_headless: SimulationEngine = _setup_engine()
	var valve_in_h: SimValve = engine_headless.context.actuators_dict[&"VALVE_IN"]
	valve_in_h.instant_mode = true
	
	engine_headless.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 80.0))
	
	for tick in range(1, 51):
		engine_headless.advance_frame(1.0)
		
	var final_volume_headless: float = engine_headless.context.units_dict[&"BASIN_01"].volume_m3
	
	var main_scene = load("res://scenes/application/main.tscn").instantiate()
	add_child_autofree(main_scene)
	
	var host: SimulationHost = main_scene.get_node("SimulationHost")
	assert_not_null(host, "SimulationHost must exist in main.tscn")
	
	var config: Dictionary = ConfigLoader.load_plant_config("phase1_single_basin")
	var _ok: bool = PlantFactory.build_plant(host.engine.context, config.topology_data, config.initial_conditions_data)
	
	var valve_in_host: SimValve = host.engine.context.actuators_dict[&"VALVE_IN"]
	valve_in_host.instant_mode = true
	
	host.engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 80.0))
	
	# For G4, strengthen headless parity: drive scene run via host.engine.advance_frame()
	# instead of manual run_tick calls.
	var elapsed: float = 0.0
	for tick in range(1, 51):
		host.engine.advance_frame(1.0)
		
	var final_volume_host: float = host.engine.context.units_dict[&"BASIN_01"].volume_m3
	
	assert_eq(final_volume_host, final_volume_headless, "Headless and loaded scene runs must produce identical results")

func test_extended_soak() -> void:
	var engine: SimulationEngine = _setup_engine()
	var storage: StorageUnit = engine.context.units_dict[&"BASIN_01"]
	
	var valve_in: SimValve = engine.context.actuators_dict[&"VALVE_IN"]
	var valve_out: SimValve = engine.context.actuators_dict[&"VALVE_OUT"]
	valve_in.instant_mode = true
	valve_out.instant_mode = true
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	
	var start_time_usec: float = float(Time.get_ticks_usec())
	
	for tick in range(1, 100001):
		if tick % 100 == 1:
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", rng.randf_range(0.0, 100.0)))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT", rng.randf_range(0.0, 100.0)))
			
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		assert_false(is_nan(storage.volume_m3) or is_inf(storage.volume_m3))
		assert_false(is_nan(storage.level_m) or is_inf(storage.level_m))
		
		if tick % 1000 == 0:
			var report: Dictionary = engine.mass_balance_tracker.report(storage.volume_m3)
			var total_scale: float = max(500.0 + engine.mass_balance_tracker.cumulative_inflow_m3, 1.0)
			var tolerance: float = 1e-9 * total_scale * sqrt(float(tick))
			assert_lt(abs(report.mass_balance_error_m3), tolerance, "Ledger error must remain within tolerance")
			
	var duration_ms: float = (float(Time.get_ticks_usec()) - start_time_usec) / 1000.0
	print("Extended soak: 100,000 ticks took %f ms" % duration_ms)
