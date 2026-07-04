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

func test_dual_reservoir_flow_combines() -> void:
	var engine := _setup_engine()
	
	var res1: StorageUnit = engine.context.units_dict[&"RESERVOIR_01"]
	var res2: StorageUnit = engine.context.units_dict[&"RESERVOIR_02"]
	var manifold: StorageUnit = engine.context.units_dict[&"MANIFOLD_01"]
	
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	
	# Configure all actuators to be in instant mode
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	# Replenish source reservoirs and set volumes high
	res1.volume_m3 = 500.0
	res1.update_level()
	res2.volume_m3 = 500.0
	res2.update_level()
	manifold.volume_m3 = 5.0
	manifold.update_level()
	
	# Keep inflows active
	v_in1.set_commanded_position(100.0)
	v_in1.position = 100.0
	v_in2.set_commanded_position(100.0)
	v_in2.position = 100.0
	
	# Open reservoir outlets and manifold outlet
	v_out_res1.set_commanded_position(50.0)
	v_out_res1.position = 50.0 # 50% of 8 = 4.0 m3s
	v_out_res2.set_commanded_position(50.0)
	v_out_res2.position = 50.0 # 50% of 8 = 4.0 m3s
	
	# Manifold outlet is open fully
	v_out_man1.set_commanded_position(100.0)
	v_out_man1.position = 100.0 # 100% of 12 = 12.0 m3s
	
	# Initialize mass balance tracker
	engine.mass_balance_tracker.is_initialized = false
	
	# Run 100 ticks
	for tick in range(1, 101):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Manifold inflow rate must equal the sum of outlet flows of Reservoirs 1 and 2
	var res1_out_link = engine.context.links_dict[&"LINK_OUT_RES_01"]
	var res2_out_link = engine.context.links_dict[&"LINK_OUT_RES_02"]
	var manifold_in_flow = res1_out_link.actual_flow_m3s + res2_out_link.actual_flow_m3s
	
	# Check manifold inflows
	assert_almost_eq(manifold_in_flow, 8.0, 1e-5, "Manifold inlet flow sum should equal 8.0 m3/s")

func test_single_reservoir_starvation() -> void:
	var engine := _setup_engine()
	
	var res1: StorageUnit = engine.context.units_dict[&"RESERVOIR_01"]
	var res2: StorageUnit = engine.context.units_dict[&"RESERVOIR_02"]
	
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	# Starve reservoir 1, replenish reservoir 2
	res1.volume_m3 = 0.0
	res1.update_level()
	res2.volume_m3 = 500.0
	res2.update_level()
	
	# Open outlet valves
	v_out_res1.set_commanded_position(100.0)
	v_out_res1.position = 100.0
	v_out_res2.set_commanded_position(100.0)
	v_out_res2.position = 100.0
	v_out_man1.set_commanded_position(100.0)
	v_out_man1.position = 100.0
	
	# Run 1 tick
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	# Reservoir 1 outflow must be 0 because it's empty and below min_operating_level (0.5m)
	var res1_out_link = engine.context.links_dict[&"LINK_OUT_RES_01"]
	var res2_out_link = engine.context.links_dict[&"LINK_OUT_RES_02"]
	assert_almost_eq(res1_out_link.actual_flow_m3s, 0.0, 1e-5, "Starved Reservoir 1 outflow must be 0.0")
	assert_true(res2_out_link.actual_flow_m3s > 0.0, "Reservoir 2 outflow should be active")

func test_manifold_mass_conservation_1k_ticks() -> void:
	var engine := _setup_engine()
	
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	
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
	
	engine.mass_balance_tracker.is_initialized = false
	
	# Run 1000 ticks
	for tick in range(1, 1001):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	var report = engine.mass_balance_tracker.report()
	assert_true(report.mass_balance_error_m3 <= 1e-4, "Mass balance error should be within tolerance")
