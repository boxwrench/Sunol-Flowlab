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

func test_applied_channel_receives_all_basin_flow() -> void:
	var engine := _setup_engine()
	
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	var v_out_fm1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_FM_01"]
	
	var db_valves: Array[SimValve] = []
	for i in range(1, 6):
		db_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_DB_0%d" % i)])
		
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
	
	for v in db_valves:
		v.set_commanded_position(100.0)
		v.position = 100.0
	for v in basin_valves:
		v.set_commanded_position(100.0)
		v.position = 100.0
		
	# Run 1 tick to execute solver and balance
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	var ac: StorageUnit = engine.context.units_dict[&"APPLIED_CHANNEL_01"]
	
	# Sum up basin outflows
	var expected_sum: float = 0.0
	for i in range(1, 6):
		var link = engine.context.links_dict[StringName("LINK_OUT_BASIN_0%d" % i)]
		expected_sum += link.actual_flow_m3s
		
	assert_almost_eq(ac.inflow_m3s, expected_sum, 1e-5, "Applied channel inflow should equal the sum of basin outflows")
	assert_true(ac.inflow_m3s > 0.0, "There should be positive flow entering the applied channel")

func test_applied_channel_high_level_alarm() -> void:
	var engine := _setup_engine()
	
	var ac: StorageUnit = engine.context.units_dict[&"APPLIED_CHANNEL_01"]
	
	# Set volume to drive level above high_level_m = 4.5 (area = 40.0, volume = 190.0 => level = 4.75)
	ac.volume_m3 = 190.0
	ac.update_level()
	
	# Run 1 tick
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	var alarm = engine.alarm_engine.alarms_dict[&"APPLIED_CHANNEL_HIGH_LEVEL"]
	assert_true(alarm.is_active, "APPLIED_CHANNEL_HIGH_LEVEL alarm should be active")

func test_applied_channel_mass_conservation_1k_ticks() -> void:
	var engine := _setup_engine()
	
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	var v_out_fm1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_FM_01"]
	
	var db_valves: Array[SimValve] = []
	for i in range(1, 6):
		db_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_DB_0%d" % i)])
		
	var basin_valves: Array[SimValve] = []
	for i in range(1, 6):
		basin_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_BASIN_0%d" % i)])
		
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	v_in1.set_commanded_position(80.0)
	v_in1.position = 80.0
	v_in2.set_commanded_position(60.0)
	v_in2.position = 60.0
	v_out_res1.set_commanded_position(70.0)
	v_out_res1.position = 70.0
	v_out_res2.set_commanded_position(70.0)
	v_out_res2.position = 70.0
	v_out_man1.set_commanded_position(80.0)
	v_out_man1.position = 80.0
	v_out_fm1.set_commanded_position(80.0)
	v_out_fm1.position = 80.0
	
	for v in db_valves:
		v.set_commanded_position(80.0)
		v.position = 80.0
	for v in basin_valves:
		v.set_commanded_position(80.0)
		v.position = 80.0
		
	engine.mass_balance_tracker.is_initialized = false
	
	# Run 1000 ticks
	for tick in range(1, 1001):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Compute total current storage across all StorageUnits
	var current_storage: float = 0.0
	for unit in engine.context.units_list:
		if unit is StorageUnit:
			current_storage += unit.volume_m3
			
	var report = engine.mass_balance_tracker.report(current_storage)
	assert_true(abs(report.mass_balance_error_m3) <= 1e-4, "Mass balance error should be within tolerance after 1000 ticks")
