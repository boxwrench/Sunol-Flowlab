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

func test_out_of_service_zeroes_all_link_flows() -> void:
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
		
	# Put BASIN_01 out of service
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", false))
	
	# Run 1 tick
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	# Verify that BASIN_01's inlet and outlet links carry zero flow
	var inlet_link = engine.context.links_dict[&"LINK_OUT_DB_01"]
	var outlet_link = engine.context.links_dict[&"LINK_OUT_BASIN_01"]
	
	assert_false(inlet_link.is_enabled, "Inlet link must be disabled")
	assert_false(outlet_link.is_enabled, "Outlet link must be disabled")
	
	assert_eq(inlet_link.requested_flow_m3s, 0.0, "Inlet requested flow should be 0.0")
	assert_eq(inlet_link.granted_flow_m3s, 0.0, "Inlet granted flow should be 0.0")
	assert_eq(inlet_link.actual_flow_m3s, 0.0, "Inlet actual flow should be 0.0")
	
	assert_eq(outlet_link.requested_flow_m3s, 0.0, "Outlet requested flow should be 0.0")
	assert_eq(outlet_link.granted_flow_m3s, 0.0, "Outlet granted flow should be 0.0")
	assert_eq(outlet_link.actual_flow_m3s, 0.0, "Outlet actual flow should be 0.0")

func test_in_service_restore_flows() -> void:
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
		
	# First put out of service, then restore in service
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", false))
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", true))
	
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	var inlet_link = engine.context.links_dict[&"LINK_OUT_DB_01"]
	var outlet_link = engine.context.links_dict[&"LINK_OUT_BASIN_01"]
	
	assert_true(inlet_link.is_enabled, "Inlet link must be restored to enabled")
	assert_true(outlet_link.is_enabled, "Outlet link must be restored to enabled")
	assert_true(inlet_link.actual_flow_m3s > 0.0, "Inlet flow should be active")
	assert_true(outlet_link.actual_flow_m3s > 0.0, "Outlet flow should be active")

func test_drain_stays_enabled_when_out_of_service() -> void:
	var engine := _setup_engine()
	
	var drain_link = engine.context.links_dict[&"LINK_DRAIN_BASIN_01"]
	assert_true(drain_link.is_enabled, "Drain link starts enabled")
	
	# Put BASIN_01 out of service
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", false))
	
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	assert_true(drain_link.is_enabled, "Drain link must remain enabled when basin is out of service")
