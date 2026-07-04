extends "res://addons/gut/test.gd"

func _setup_engine() -> SimulationEngine:
	var engine: SimulationEngine = SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("phase3_headworks")
	assert_true(config.success, "Configuration should load successfully")
	if not config.success:
		print("Config errors: ", config.errors)
	
	var build_ok: bool = PlantFactory.build_plant(
		engine.context, 
		config.topology_data, 
		config.initial_conditions_data,
		config.controllers_data
	)
	assert_true(build_ok, "Factory build should succeed")
	
	# Register alarms from config
	if config.has("alarms_data") and not config.alarms_data.is_empty():
		var alarms_array: Array = config.alarms_data.get("alarms", [])
		for alarm_config in alarms_array:
			var alarm := ThresholdAlarm.new()
			alarm.initialize(alarm_config)
			engine.alarm_engine.register_alarm(alarm)
			
	return engine

func test_five_controllers_stabilize_applied_channel_level() -> void:
	var engine := _setup_engine()
	
	# Enable auto mode for all controllers and check their settings
	var ac: StorageUnit = engine.context.units_dict[&"APPLIED_CHANNEL_01"]
	
	# Open reservoir and manifold valves to ensure supply of water
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	var v_out_fm1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_FM_01"]
	
	# All basin outlets are open to drain water out of the channel to maintain level control
	var basin_valves: Array[SimValve] = []
	for i in range(1, 6):
		basin_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_BASIN_0%d" % i)])
		
	# Configure actuators to run in instant mode for test speed/determinism
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	v_in1.set_commanded_position(100.0)
	v_in1.position = 100.0
	v_in2.set_commanded_position(100.0)
	v_in2.position = 100.0
	v_out_res1.set_commanded_position(100.0)
	v_out_res1.position = 100.0
	v_out_res2.set_commanded_position(100.0)
	v_out_res2.position = 100.0
	v_out_man1.set_commanded_position(100.0)
	v_out_man1.position = 100.0
	v_out_fm1.set_commanded_position(100.0)
	v_out_fm1.position = 100.0
	
	for v in basin_valves:
		v.set_commanded_position(80.0)
		v.position = 80.0
		
	# Let the system run for 1000 ticks to settle
	for tick in range(1, 1001):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Assert level is within deadband
	assert_almost_eq(ac.level_m, 2.0, 0.05, "Level should stabilize at setpoint 2.0 within deadband 0.05")

func test_controller_redistribution_on_basin_loss() -> void:
	var engine := _setup_engine()
	
	var ac: StorageUnit = engine.context.units_dict[&"APPLIED_CHANNEL_01"]
	
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	var v_out_fm1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_FM_01"]
	
	var basin_valves: Array[SimValve] = []
	for i in range(1, 6):
		basin_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_BASIN_0%d" % i)])
		
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	v_in1.set_commanded_position(100.0)
	v_in1.position = 100.0
	v_in2.set_commanded_position(100.0)
	v_in2.position = 100.0
	v_out_res1.set_commanded_position(100.0)
	v_out_res1.position = 100.0
	v_out_res2.set_commanded_position(100.0)
	v_out_res2.position = 100.0
	v_out_man1.set_commanded_position(100.0)
	v_out_man1.position = 100.0
	v_out_fm1.set_commanded_position(100.0)
	v_out_fm1.position = 100.0
	
	for v in basin_valves:
		v.set_commanded_position(80.0)
		v.position = 80.0
		
	# Run 500 ticks to reach steady-state
	for tick in range(1, 501):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	assert_almost_eq(ac.level_m, 2.0, 0.05, "Level should settle at 2.0 first")
	
	# Take BASIN_01 out of service at tick 501
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", false))
	
	# Run 100 ticks for redistribution and settling
	for tick in range(501, 601):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Confirm BASIN_01's inlet valve (VALVE_OUT_DB_01) is no longer modulating flow
	# and is disabled, and that the remaining 4 gates manage the level
	var link1 = engine.context.links_dict[&"LINK_OUT_DB_01"]
	assert_false(link1.is_enabled, "Link 1 must be disabled")
	assert_eq(link1.actual_flow_m3s, 0.0, "Flow to Basin 1 must be zero")
	
	# Level should be maintained within +/- 10% (0.2m) of setpoint (2.0)
	assert_almost_eq(ac.level_m, 2.0, 0.2, "Applied channel level should stabilize within +/-10% after losing one basin")
