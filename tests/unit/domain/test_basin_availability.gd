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

	# These tests drive VALVE_OUT_DB_01..05 manually. The WP3.5 LevelControllers
	# default to AUTO on these same actuators, so force MANUAL here to keep this
	# suite's direct valve control uncontested.
	for i in range(1, 6):
		var ctrl = engine.context.controllers_dict[StringName("LC_BASIN_0%d" % i)]
		ctrl.control_mode = &"MANUAL"

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
		
	# First put out of service on tick 1
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", false))
	
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	var inlet_link = engine.context.links_dict[&"LINK_OUT_DB_01"]
	var outlet_link = engine.context.links_dict[&"LINK_OUT_BASIN_01"]
	
	assert_false(inlet_link.is_enabled, "Inlet link must be disabled on tick 1")
	assert_false(outlet_link.is_enabled, "Outlet link must be disabled on tick 1")
	assert_eq(inlet_link.actual_flow_m3s, 0.0, "Inlet flow should be zero on tick 1")
	assert_eq(outlet_link.actual_flow_m3s, 0.0, "Outlet flow should be zero on tick 1")
	
	# Restore in service on tick 2
	engine.enqueue(SetBasinServiceCommand.new(&"BASIN_01", true))
	
	engine.clock.tick_count = 2
	engine.context.current_tick = 2
	engine.run_tick(1.0)
	
	assert_true(inlet_link.is_enabled, "Inlet link must be restored to enabled")
	assert_true(outlet_link.is_enabled, "Outlet link must be restored to enabled")
	assert_true(inlet_link.actual_flow_m3s > 0.0, "Inlet flow should be active on tick 2")
	assert_true(outlet_link.actual_flow_m3s > 0.0, "Outlet flow should be active on tick 2")

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

func test_factory_build_precedence_topology_inactive_ic_omitted() -> void:
	var engine := SimulationEngine.new()
	var topology := {
		"units": [
			{
				"unit_id": "TEST_BASIN",
				"type": "StorageUnit",
				"display_name": "Test Basin",
				"in_service": false, # Topology sets out-of-service
				"maximum_volume_m3": 100.0,
				"surface_area_m2": 10.0,
				"bottom_elevation_m": 0.0,
				"high_level_m": 9.0,
				"spill_level_m": 10.0,
				"min_operating_level_m": 0.5,
				"spill_destination_id": "SPILL_SINK",
				"ports": [
					{
						"port_id": "PORT_IN_BASIN",
						"port_type": "INLET"
					}
				]
			},
			{
				"unit_id": "SPILL_SINK",
				"type": "ExternalBoundary",
				"display_name": "Spill Sink",
				"boundary_type": "SPILL",
				"ports": []
			},
			{
				"unit_id": "TEST_SOURCE",
				"type": "ExternalBoundary",
				"display_name": "Test Source",
				"boundary_type": "SOURCE_INFLOW",
				"ports": [
					{
						"port_id": "PORT_OUT_SRC",
						"port_type": "OUTLET"
					}
				]
			}
		],
		"actuators": [],
		"links": [
			{
				"link_id": "LINK_IN_BASIN",
				"display_name": "Inlet Link",
				"max_flow_m3s": 1.0,
				"source_port_id": "PORT_OUT_SRC",
				"destination_port_id": "PORT_IN_BASIN"
			}
		]
	}
	
	var initial_conditions := {
		"unit_states": [
			{
				"unit_id": "TEST_BASIN",
				"volume_m3": 50.0
				# in_service is omitted here!
			}
		],
		"actuator_states": []
	}
	
	var validation = PlantValidator.validate_config(
		{},
		topology,
		initial_conditions,
		1.0,
		{},
		{}
	)
	assert_eq(validation.errors.size(), 0, "Topology configuration should have 0 validation errors")

	var build_ok = PlantFactory.build_plant(engine.context, topology, initial_conditions, {"controllers": []})
	assert_true(build_ok, "Factory build should succeed")
	
	var unit: StorageUnit = engine.context.units_dict[&"TEST_BASIN"]
	assert_false(unit.in_service, "Unit in_service should remain false from topology when omitted in IC")
	
	var link = engine.context.links_dict[&"LINK_IN_BASIN"]
	assert_false(link.is_enabled, "Connected link should be disabled")

func test_factory_build_precedence_ic_overrides_topology() -> void:
	var engine := SimulationEngine.new()
	var topology := {
		"units": [
			{
				"unit_id": "BASIN_1",
				"type": "StorageUnit",
				"display_name": "Basin 1",
				"in_service": true, # Topology has true
				"maximum_volume_m3": 100.0,
				"surface_area_m2": 10.0,
				"bottom_elevation_m": 0.0,
				"high_level_m": 9.0,
				"spill_level_m": 10.0,
				"min_operating_level_m": 0.5,
				"spill_destination_id": "SPILL_SINK",
				"ports": [
					{
						"port_id": "PORT_IN_B1",
						"port_type": "INLET"
					}
				]
			},
			{
				"unit_id": "BASIN_2",
				"type": "StorageUnit",
				"display_name": "Basin 2",
				"in_service": false, # Topology has false
				"maximum_volume_m3": 100.0,
				"surface_area_m2": 10.0,
				"bottom_elevation_m": 0.0,
				"high_level_m": 9.0,
				"spill_level_m": 10.0,
				"min_operating_level_m": 0.5,
				"spill_destination_id": "SPILL_SINK",
				"ports": [
					{
						"port_id": "PORT_IN_B2",
						"port_type": "INLET"
					}
				]
			},
			{
				"unit_id": "SPILL_SINK",
				"type": "ExternalBoundary",
				"display_name": "Spill Sink",
				"boundary_type": "SPILL",
				"ports": []
			},
			{
				"unit_id": "TEST_SOURCE",
				"type": "ExternalBoundary",
				"display_name": "Test Source",
				"boundary_type": "SOURCE_INFLOW",
				"ports": [
					{
						"port_id": "PORT_OUT_SRC_1",
						"port_type": "OUTLET"
					},
					{
						"port_id": "PORT_OUT_SRC_2",
						"port_type": "OUTLET"
					}
				]
			}
		],
		"actuators": [],
		"links": [
			{
				"link_id": "LINK_IN_B1",
				"display_name": "Inlet Link 1",
				"max_flow_m3s": 1.0,
				"source_port_id": "PORT_OUT_SRC_1",
				"destination_port_id": "PORT_IN_B1"
			},
			{
				"link_id": "LINK_IN_B2",
				"display_name": "Inlet Link 2",
				"max_flow_m3s": 1.0,
				"source_port_id": "PORT_OUT_SRC_2",
				"destination_port_id": "PORT_IN_B2"
			}
		]
	}
	
	var initial_conditions := {
		"unit_states": [
			{
				"unit_id": "BASIN_1",
				"in_service": false # Override true -> false
			},
			{
				"unit_id": "BASIN_2",
				"in_service": true # Override false -> true
			}
		],
		"actuator_states": []
	}
	
	var validation = PlantValidator.validate_config(
		{},
		topology,
		initial_conditions,
		1.0,
		{},
		{}
	)
	assert_eq(validation.errors.size(), 0, "Overridden configuration should have 0 validation errors")

	var build_ok = PlantFactory.build_plant(engine.context, topology, initial_conditions, {"controllers": []})
	assert_true(build_ok, "Factory build should succeed")
	
	var b1: StorageUnit = engine.context.units_dict[&"BASIN_1"]
	var b2: StorageUnit = engine.context.units_dict[&"BASIN_2"]
	
	assert_false(b1.in_service, "Basin 1 in_service should be overridden to false")
	assert_true(b2.in_service, "Basin 2 in_service should be overridden to true")
	
	var link1 = engine.context.links_dict[&"LINK_IN_B1"]
	var link2 = engine.context.links_dict[&"LINK_IN_B2"]
	
	assert_false(link1.is_enabled, "Link 1 should be disabled")
	assert_true(link2.is_enabled, "Link 2 should be enabled")

