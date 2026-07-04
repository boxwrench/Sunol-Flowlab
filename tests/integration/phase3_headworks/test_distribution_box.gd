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

func test_equal_split_five_basins() -> void:
	var engine := _setup_engine()
	
	# Open everything upstream fully
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	var v_out_fm1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_FM_01"]
	
	# Dist Box outlet valves
	var db_valves: Array[SimValve] = []
	for i in range(1, 6):
		db_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_DB_0%d" % i)])
		
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
	
	# Open all DB outlet valves fully (100%)
	for v in db_valves:
		v.set_commanded_position(100.0)
		v.position = 100.0
		
	# Dist Box outlet links each have max_flow_m3s = 3.0.
	# With valves fully open, each requests 3.0 m3s.
	# Total request = 15.0 m3s.
	# Let's run 1 tick
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	# Get granted flows from links
	var total_granted_outflow: float = 0.0
	var granted_flows: Array[float] = []
	for i in range(1, 6):
		var link = engine.context.links_dict[StringName("LINK_OUT_DB_0%d" % i)]
		granted_flows.append(link.actual_flow_m3s)
		total_granted_outflow += link.actual_flow_m3s
		
	assert_true(total_granted_outflow > 0.0, "Total granted outflow from Dist Box should be positive")
	
	# Verify equal split (each link should receive exactly 1/5th of total)
	for i in range(5):
		var expected = total_granted_outflow / 5.0
		assert_almost_eq(granted_flows[i], expected, 1e-4, "Link %d flow should be equal split" % (i+1))

func test_proportional_split_capacity() -> void:
	var engine := _setup_engine()
	
	# Dist Box outlet links: we configure different capacities: 4:2:2:1:1
	# We can adjust max_flow_m3s on the links directly
	var db_links: Array[FlowLink] = []
	var capacities = [4.0, 2.0, 2.0, 1.0, 1.0]
	for i in range(1, 6):
		var link = engine.context.links_dict[StringName("LINK_OUT_DB_0%d" % i)]
		link.max_flow_m3s = capacities[i-1]
		db_links.append(link)
		
	# Open everything upstream fully
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	var v_out_fm1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_FM_01"]
	
	var db_valves: Array[SimValve] = []
	for i in range(1, 6):
		db_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_DB_0%d" % i)])
		
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	# Restrict upstream inflow so that total available supply triggers proration at Dist Box.
	# Reservoir outlet valves set to restrict flow: e.g. 50%
	v_in1.set_commanded_position(100.0)
	v_in1.position = 100.0
	v_in2.set_commanded_position(100.0)
	v_in2.position = 100.0
	v_out_res1.set_commanded_position(25.0)
	v_out_res1.position = 25.0 # 25% of 8 = 2.0 m3s
	v_out_res2.set_commanded_position(25.0)
	v_out_res2.position = 25.0 # 25% of 8 = 2.0 m3s
	v_out_man1.set_commanded_position(100.0)
	v_out_man1.position = 100.0
	v_out_fm1.set_commanded_position(100.0)
	v_out_fm1.position = 100.0
	
	for v in db_valves:
		v.set_commanded_position(100.0)
		v.position = 100.0
		
	# Total demand = 4 + 2 + 2 + 1 + 1 = 10.0 m3s.
	# Upstream supply is limited (reservoirs provide ~4.0 m3s total, manifold/mix buffer some,
	# so available supply at DB is less than 10.0 m3s, triggering proration).
	
	# Run 5 ticks to propagate and settle
	for tick in range(1, 6):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Retrieve actual flows
	var total_granted_outflow: float = 0.0
	var granted_flows: Array[float] = []
	for link in db_links:
		granted_flows.append(link.actual_flow_m3s)
		total_granted_outflow += link.actual_flow_m3s
		
	assert_true(total_granted_outflow > 0.0, "Total granted outflow from Dist Box should be positive under proration")
	
	# Verify proration split matches ratio 4:2:2:1:1
	var sum_ratios: float = 10.0
	var expected_pcts = [0.40, 0.20, 0.20, 0.10, 0.10]
	for i in range(5):
		var actual_pct = granted_flows[i] / total_granted_outflow
		assert_almost_eq(actual_pct, expected_pcts[i], 1e-4, "Link %d proration percentage should match expected ratio" % (i+1))

func test_dist_box_mass_conservation_1k_ticks() -> void:
	var engine := _setup_engine()
	
	# Set valves to arbitrary positions
	var v_in1: SimValve = engine.context.actuators_dict[&"VALVE_IN_01"]
	var v_in2: SimValve = engine.context.actuators_dict[&"VALVE_IN_02"]
	var v_out_res1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_01"]
	var v_out_res2: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RES_02"]
	var v_out_man1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_MAN_01"]
	var v_out_fm1: SimValve = engine.context.actuators_dict[&"VALVE_OUT_FM_01"]
	
	var db_valves: Array[SimValve] = []
	for i in range(1, 6):
		db_valves.append(engine.context.actuators_dict[StringName("VALVE_OUT_DB_0%d" % i)])
		
	for act in engine.context.actuators_list:
		act.instant_mode = true
		
	v_in1.set_commanded_position(80.0)
	v_in1.position = 80.0
	v_in2.set_commanded_position(60.0)
	v_in2.position = 60.0
	v_out_res1.set_commanded_position(70.0)
	v_out_res1.position = 70.0
	v_out_res2.set_commanded_position(50.0)
	v_out_res2.position = 50.0
	v_out_man1.set_commanded_position(80.0)
	v_out_man1.position = 80.0
	v_out_fm1.set_commanded_position(80.0)
	v_out_fm1.position = 80.0
	
	# Arbitrary positions for db outlets
	db_valves[0].set_commanded_position(90.0)
	db_valves[0].position = 90.0
	db_valves[1].set_commanded_position(60.0)
	db_valves[1].position = 60.0
	db_valves[2].set_commanded_position(50.0)
	db_valves[2].position = 50.0
	db_valves[3].set_commanded_position(30.0)
	db_valves[3].position = 30.0
	db_valves[4].set_commanded_position(10.0)
	db_valves[4].position = 10.0
	
	engine.mass_balance_tracker.is_initialized = false
	
	# Run 1000 ticks
	for tick in range(1, 1001):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	var report = engine.mass_balance_tracker.report()
	assert_true(report.mass_balance_error_m3 <= 1e-4, "Mass balance error should be within tolerance")
