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

	# Let the system run to settle, collecting levels over the final 50 ticks (951 to 1000)
	var final_levels: Array[float] = []
	for tick in range(1, 1001):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		if tick >= 950:
			final_levels.append(ac.level_m)

	var sum_levels: float = 0.0
	var max_dev: float = 0.0
	for lvl in final_levels:
		sum_levels += lvl
		var dev = abs(lvl - 2.0)
		if dev > max_dev:
			max_dev = dev
	var avg_level: float = sum_levels / final_levels.size()

	assert_almost_eq(avg_level, 2.0, 0.05, "Time-averaged level over final 50-tick window should regulate close to 2.0m setpoint")
	assert_true(max_dev <= 0.1, "Maximum level deviation over final window should be bounded within 0.1m")

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

	# Run 500 ticks to reach steady-state, collecting levels over the final 50 ticks (451 to 500)
	var final_levels_pre: Array[float] = []
	for tick in range(1, 501):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		if tick >= 450:
			final_levels_pre.append(ac.level_m)

	var sum_levels_pre: float = 0.0
	var max_dev_pre: float = 0.0
	for lvl in final_levels_pre:
		sum_levels_pre += lvl
		var dev = abs(lvl - 2.0)
		if dev > max_dev_pre:
			max_dev_pre = dev
	var avg_level_pre: float = sum_levels_pre / final_levels_pre.size()

	assert_almost_eq(avg_level_pre, 2.0, 0.05, "Time-averaged level over pre-disturbance window should regulate close to 2.0m")
	assert_true(max_dev_pre <= 0.1, "Maximum level deviation pre-disturbance should be bounded within 0.1m")

	# Take BASIN_01 out of service at tick 501
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", false))

	# Run 100 ticks for redistribution and settling, collecting levels over final 50 ticks
	var final_levels_post: Array[float] = []
	for tick in range(501, 601):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		if tick >= 550:
			final_levels_post.append(ac.level_m)

	# Confirm BASIN_01's inlet valve (VALVE_OUT_DB_01) is no longer modulating flow
	# and is disabled, and that the remaining 4 gates manage the level
	var link1 = engine.context.links_dict[&"LINK_OUT_DB_01"]
	assert_false(link1.is_enabled, "Link 1 must be disabled")
	assert_eq(link1.actual_flow_m3s, 0.0, "Flow to Basin 1 must be zero")

	var sum_levels_post: float = 0.0
	var max_dev_post: float = 0.0
	for lvl in final_levels_post:
		sum_levels_post += lvl
		var dev = abs(lvl - 2.0)
		if dev > max_dev_post:
			max_dev_post = dev
	var avg_level_post: float = sum_levels_post / final_levels_post.size()

	assert_almost_eq(avg_level_post, 2.0, 0.2, "Time-averaged level over post-disturbance window should stabilize within +/-10%")
	assert_true(max_dev_post <= 0.3, "Maximum level deviation post-disturbance should be bounded within 0.3m")
