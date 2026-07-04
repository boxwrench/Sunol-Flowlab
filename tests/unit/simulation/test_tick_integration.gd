extends "res://addons/gut/test.gd"

func test_tick_integration_full_sequence() -> void:
	var config: Dictionary = ConfigLoader.load_plant_config("phase1_single_basin")
	assert_true(config.success)
	
	var engine: SimulationEngine = SimulationEngine.new()
	var build_ok: bool = PlantFactory.build_plant(engine.context, config.topology_data, config.initial_conditions_data)
	assert_true(build_ok)
	
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
	
	var storage: StorageUnit = engine.context.units_dict[&"BASIN_01"]
	assert_eq(storage.volume_m3, 500.0)
	assert_eq(storage.level_m, 5.0)
	
	# Tick 1: dt = 1.0s
	# Inflow = 5.0 * 0.5 = 2.5 m3/s. Outflow = 0.0 m3/s.
	# volume should increase to 502.5 m3.
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	assert_eq(storage.volume_m3, 502.5)
	assert_eq(storage.level_m, 5.025)
	assert_eq(storage.inflow_m3s, 2.5)
	assert_eq(storage.outflow_m3s, 0.0)
	assert_false(alarm.is_active)
	
	# Command valve_out to 100% (instant_mode is true in config? No, it defaults to false,
	# but we can set commanded_position and wait, or test instant mode)
	var link_out: FlowLink = engine.context.links_dict[&"LINK_OUT"]
	var valve_out: SimValve = link_out.actuator
	valve_out.instant_mode = true
	valve_out.set_commanded_position(100.0)
	
	# Tick 2: dt = 1.0s
	# Inflow = 2.5 m3/s. Outflow = 4.0 m3/s.
	# Net change = -1.5 m3/s.
	# volume should decrease to 501.0 m3.
	engine.clock.tick_count = 2
	engine.context.current_tick = 2
	engine.run_tick(1.0)
	
	assert_eq(storage.volume_m3, 501.0)
	assert_eq(storage.level_m, 5.01)
	assert_eq(storage.inflow_m3s, 2.5)
	assert_eq(storage.outflow_m3s, 4.0)
