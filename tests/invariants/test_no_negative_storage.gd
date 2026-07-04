extends "res://addons/gut/test.gd"

class MockSolveEngine extends SimulationEngine:
	func run_tick(dt: float) -> void:
		_step_receive_commands()
		_step_update_actuators()
		
		# Resolve requested flows (restricted flow only for Phase 1)
		for link in context.links_list:
			link.calculate_requested_flow()
			link.granted_flow_m3s = link.requested_flow_m3s
			link.actual_flow_m3s = link.granted_flow_m3s
			
		var storage: StorageUnit = context.units_dict[&"BASIN_01"]
		var link_in: FlowLink = context.links_dict[&"LINK_IN"]
		var link_out: FlowLink = context.links_dict[&"LINK_OUT"]
		var link_drain: FlowLink = context.links_dict[&"LINK_DRAIN"]
		
		var inflows: Array[float] = [link_in.granted_flow_m3s]
		var balance: Dictionary = StorageBalance.solve(
			storage.volume_m3,
			inflows,
			link_out.granted_flow_m3s,
			link_drain.granted_flow_m3s,
			storage.maximum_volume_m3,
			storage.spill_level_m * storage.surface_area_m2,
			dt
		)
		
		# Update states
		storage.volume_m3 = balance.new_volume_m3
		storage.update_level()
		storage.inflow_m3s = balance.actual_inflow_m3s
		storage.outflow_m3s = balance.actual_outflow_m3s
		storage.drain_flow_m3s = balance.actual_drain_flow_m3s
		storage.spill_flow_m3s = balance.actual_spill_flow_m3s
		
		_step_validate_invariants()

func test_no_negative_storage_under_aggressive_drain() -> void:
	var engine: MockSolveEngine = MockSolveEngine.new()
	
	var storage: StorageUnit = StorageUnit.new()
	storage.initialize({
		"unit_id": &"BASIN_01",
		"maximum_volume_m3": 100.0,
		"surface_area_m2": 10.0,
		"bottom_elevation_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5,
		"min_operating_level_m": 0.5,
		"initial_volume_m3": 5.0
	})
	
	engine.context.units_list.append(storage)
	engine.context.units_dict[storage.unit_id] = storage
	
	var port_dict: Dictionary = {}
	var resolver: Callable = func(port_id: StringName) -> FlowPort:
		return port_dict.get(port_id)
		
	var port_basin_in: FlowPort = FlowPort.new(&"PORT_BASIN_IN", storage, &"INLET")
	var port_basin_out: FlowPort = FlowPort.new(&"PORT_BASIN_OUT", storage, &"OUTLET")
	var port_basin_drain: FlowPort = FlowPort.new(&"PORT_BASIN_DRAIN", storage, &"OUTLET")
	
	port_dict[port_basin_in.port_id] = port_basin_in
	port_dict[port_basin_out.port_id] = port_basin_out
	port_dict[port_basin_drain.port_id] = port_basin_drain
	
	var valve_in: SimValve = SimValve.new(&"VALVE_IN")
	valve_in.initialize({"initial_position": 0.0, "instant_mode": true})
	
	var valve_out: SimValve = SimValve.new(&"VALVE_OUT")
	valve_out.initialize({"initial_position": 100.0, "instant_mode": true})
	
	var valve_drain: SimValve = SimValve.new(&"VALVE_DRAIN")
	valve_drain.initialize({"initial_position": 100.0, "instant_mode": true})
	
	var link_in: FlowLink = FlowLink.new()
	link_in.initialize({
		"link_id": &"LINK_IN",
		"max_flow_m3s": 10.0,
		"destination_port_id": &"PORT_BASIN_IN"
	}, resolver)
	link_in.actuator = valve_in
	
	var link_out: FlowLink = FlowLink.new()
	link_out.initialize({
		"link_id": &"LINK_OUT",
		"max_flow_m3s": 20.0,
		"source_port_id": &"PORT_BASIN_OUT"
	}, resolver)
	link_out.actuator = valve_out
	
	var link_drain: FlowLink = FlowLink.new()
	link_drain.initialize({
		"link_id": &"LINK_DRAIN",
		"max_flow_m3s": 30.0,
		"source_port_id": &"PORT_BASIN_DRAIN"
	}, resolver)
	link_drain.actuator = valve_drain
	
	for l in [link_in, link_out, link_drain]:
		engine.context.links_list.append(l)
		engine.context.links_dict[l.link_id] = l
		
	# Tick 1: Outflow + drain total requests = 50 m3, only 5 m3 is available.
	# Outflow granted = 2.0 m3/s, drain granted = 3.0 m3/s.
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	assert_eq(storage.volume_m3, 0.0, "Storage volume should be exactly 0.0")
	assert_eq(storage.outflow_m3s, 2.0, "Outflow should be prorated to 2.0 m3/s")
	assert_eq(storage.drain_flow_m3s, 3.0, "Drain should be prorated to 3.0 m3/s")
	
	# Tick 2: Volume is 0.0. Requests should fail to get any water.
	engine.clock.tick_count = 2
	engine.context.current_tick = 2
	engine.run_tick(1.0)
	
	assert_eq(storage.volume_m3, 0.0, "Storage volume must remain exactly 0.0 when empty")
	assert_eq(storage.outflow_m3s, 0.0, "Outflow must be 0.0 when volume is 0")
	assert_eq(storage.drain_flow_m3s, 0.0, "Drain flow must be 0.0 when volume is 0")
