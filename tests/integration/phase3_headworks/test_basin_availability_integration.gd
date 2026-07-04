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
	
	return engine

func test_four_basin_proration() -> void:
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
		
	# Upstream supply is exactly 10.0 m3s (RESERVOIR_01 outflow restricted to 5.0, RESERVOIR_02 restricted to 5.0)
	v_in1.set_commanded_position(100.0)
	v_in1.position = 100.0
	v_in2.set_commanded_position(100.0)
	v_in2.position = 100.0
	v_out_res1.set_commanded_position(62.5)
	v_out_res1.position = 62.5 # 62.5% of 8 = 5.0 m3s
	v_out_res2.set_commanded_position(62.5)
	v_out_res2.position = 62.5 # 62.5% of 8 = 5.0 m3s
	v_out_man1.set_commanded_position(100.0)
	v_out_man1.position = 100.0
	v_out_fm1.set_commanded_position(100.0)
	v_out_fm1.position = 100.0
	
	# Open all DB outlet valves fully (100%)
	for v in db_valves:
		v.set_commanded_position(100.0)
		v.position = 100.0
		
	for v in basin_valves:
		v.set_commanded_position(100.0)
		v.position = 100.0
		
	# Start with all 5 basins in service. Run 50 ticks to reach steady state
	for tick in range(1, 51):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Record flow on DB outlets when all 5 basins are in service
	var flows_5_basins: Array[float] = []
	var total_outflow_5_basins: float = 0.0
	for i in range(1, 6):
		var link = engine.context.links_dict[StringName("LINK_OUT_DB_0%d" % i)]
		flows_5_basins.append(link.actual_flow_m3s)
		total_outflow_5_basins += link.actual_flow_m3s
		
	# Each should be 2.0 m3s (10.0 / 5)
	for i in range(5):
		assert_almost_eq(flows_5_basins[i], 2.0, 0.05, "Basin %d flow should be 2.0 m3s" % (i+1))
	assert_almost_eq(total_outflow_5_basins, 10.0, 0.05, "Total Dist Box outflow should be 10.0 m3s")
	
	# Now take BASIN_01 out of service
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", false))
	
	# Run 50 more ticks to adapt and propagate
	for tick in range(51, 101):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Record flow on DB outlets when 4 basins are in service
	var flows_4_basins: Array[float] = []
	var total_outflow_4_basins: float = 0.0
	for i in range(1, 6):
		var link = engine.context.links_dict[StringName("LINK_OUT_DB_0%d" % i)]
		flows_4_basins.append(link.actual_flow_m3s)
		total_outflow_4_basins += link.actual_flow_m3s
		
	# BASIN_01 gets 0.0, others get 2.5 m3s (10.0 / 4)
	assert_almost_eq(flows_4_basins[0], 0.0, 1e-5, "Out of service Basin 1 flow should be 0.0")
	for i in range(1, 5):
		assert_almost_eq(flows_4_basins[i], 2.5, 0.05, "Active Basin %d flow should be 2.5 m3s" % (i+1))
	assert_almost_eq(total_outflow_4_basins, 10.0, 0.05, "Total Dist Box outflow should remain 10.0 m3s")

func test_availability_churn_mass_conservation() -> void:
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
	v_in2.set_commanded_position(70.0)
	v_in2.position = 70.0
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
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	
	# Churn basins in/out of service over 1000 ticks.
	# We toggle a random basin service status every 10 ticks.
	for tick in range(1, 1001):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		
		if tick % 10 == 0:
			var rand_basin_idx = rng.randi_range(1, 5)
			var rand_basin_id = StringName("BASIN_0%d" % rand_basin_idx)
			var current_state = engine.context.units_dict[rand_basin_id].in_service
			engine.enqueue(SetBasinServiceCommand.new(rand_basin_id, not current_state))
			
		engine.run_tick(1.0)
		
		# Assert no negative volumes
		for uid in [&"RESERVOIR_01", &"RESERVOIR_02", &"MANIFOLD_01", &"FLASH_MIX_01", &"DIST_BOX_01", &"BASIN_01", &"BASIN_02", &"BASIN_03", &"BASIN_04", &"BASIN_05"]:
			var unit: StorageUnit = engine.context.units_dict[uid]
			assert_true(unit.volume_m3 >= 0.0, "Volume of %s must not be negative" % uid)
			
	var current_storage: float = 0.0
	for unit in engine.context.units_list:
		if unit is StorageUnit:
			current_storage += unit.volume_m3
			
	var report = engine.mass_balance_tracker.report(current_storage)
	assert_true(abs(report.mass_balance_error_m3) <= 1e-4, "Mass balance error should be within tolerance after service churn")

