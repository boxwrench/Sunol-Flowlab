extends "res://addons/gut/test.gd"

func _create_storage_unit(unit_id: StringName, vol: float, area: float, min_level: float) -> StorageUnit:
	var unit := StorageUnit.new()
	unit.initialize({
		"unit_id": unit_id,
		"display_name": "Test Basin",
		"type": "StorageUnit",
		"maximum_volume_m3": 100.0,
		"surface_area_m2": area,
		"bottom_elevation_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5,
		"min_operating_level_m": min_level,
		"initial_volume_m3": vol
	})
	return unit

func _create_boundary(unit_id: StringName, type: StringName, limit: float = -1.0) -> ExternalBoundary:
	var boundary := ExternalBoundary.new()
	boundary.initialize({
		"unit_id": unit_id,
		"display_name": "Test Boundary",
		"type": "ExternalBoundary",
		"boundary_type": type,
		"flow_limit_m3s": limit
	})
	return boundary

func _connect_units(source: ProcessUnit, dest: ProcessUnit, src_port_id: StringName, dest_port_id: StringName, port_type: StringName, max_flow: float, link_id: StringName) -> FlowLink:
	var src_port := FlowPort.new(src_port_id, source, port_type)
	var dest_port := FlowPort.new(dest_port_id, dest, &"INLET")
	source.ports[src_port_id] = src_port
	dest.ports[dest_port_id] = dest_port
	
	var resolver := func(port_id: StringName) -> FlowPort:
		if port_id == src_port_id:
			return src_port
		if port_id == dest_port_id:
			return dest_port
		return null
		
	var link := FlowLink.new()
	link.initialize({
		"link_id": link_id,
		"max_flow_m3s": max_flow,
		"flow_mode": "RESTRICTED",
		"source_port_id": src_port_id,
		"destination_port_id": dest_port_id
	}, resolver)
	return link

func test_no_negative_storage_under_aggressive_drain() -> void:
	var engine: SimulationEngine = SimulationEngine.new()
	
	var source_in := _create_boundary(&"SOURCE", &"SOURCE_INFLOW")
	var storage := _create_storage_unit(&"BASIN_01", 5.0, 10.0, 0.5)
	var sink_out := _create_boundary(&"SINK_OUT", &"TREATED_DEMAND")
	var sink_drain := _create_boundary(&"SINK_DRAIN", &"DRAIN")
	
	var valve_in: SimValve = SimValve.new(&"VALVE_IN")
	valve_in.initialize({"initial_position": 0.0, "instant_mode": true})
	
	var valve_out: SimValve = SimValve.new(&"VALVE_OUT")
	valve_out.initialize({"initial_position": 100.0, "instant_mode": true})
	
	var valve_drain: SimValve = SimValve.new(&"VALVE_DRAIN")
	valve_drain.initialize({"initial_position": 100.0, "instant_mode": true})
	
	var link_in := _connect_units(source_in, storage, &"PORT_SRC_OUT", &"PORT_BASIN_IN", &"OUTLET", 10.0, &"LINK_IN")
	link_in.actuator = valve_in
	
	var link_out := _connect_units(storage, sink_out, &"PORT_BASIN_OUT", &"PORT_SINK_OUT_IN", &"OUTLET", 20.0, &"LINK_OUT")
	link_out.actuator = valve_out
	
	var link_drain := _connect_units(storage, sink_drain, &"PORT_BASIN_DRAIN", &"PORT_SINK_DRAIN_IN", &"DRAIN", 30.0, &"LINK_DRAIN")
	link_drain.actuator = valve_drain
	
	# Register units
	for u in [source_in, storage, sink_out, sink_drain]:
		engine.context.units_list.append(u)
		engine.context.units_dict[u.unit_id] = u
		
	# Register actuators
	var actuators: Array = [valve_in, valve_out, valve_drain]
	actuators.sort_custom(func(a, b) -> bool: return String(a.actuator_id) < String(b.actuator_id))
	for act in actuators:
		engine.context.actuators_list.append(act)
		engine.context.actuators_dict[act.actuator_id] = act
		
	# Register links
	for l in [link_in, link_out, link_drain]:
		engine.context.links_list.append(l)
		engine.context.links_dict[l.link_id] = l
		
	# Topological sorting order for solving
	engine.context.topological_units_list = [source_in, storage, sink_out, sink_drain]
	
	# Tick 1: Outflow + drain total requests = 50 m3, only 5 m3 is available.
	# Outflow (OUTLET) cannot draw below min_operating_level (5.0 m3), so it gets 0.0.
	# Drain (DRAIN) draws from total volume, so it gets the remaining 5.0 m3/s.
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	assert_eq(storage.volume_m3, 0.0, "Storage volume should be exactly 0.0")
	assert_eq(storage.outflow_m3s, 0.0, "Outflow should be 0.0 m3/s (no volume above min level)")
	assert_eq(storage.drain_flow_m3s, 5.0, "Drain should be 5.0 m3/s")
	
	# Tick 2: Volume is 0.0. Requests should fail to get any water.
	engine.clock.tick_count = 2
	engine.context.current_tick = 2
	engine.run_tick(1.0)
	
	assert_eq(storage.volume_m3, 0.0, "Storage volume must remain exactly 0.0 when empty")
	assert_eq(storage.outflow_m3s, 0.0, "Outflow must be 0.0 when volume is 0")
	assert_eq(storage.drain_flow_m3s, 0.0, "Drain flow must be 0.0 when volume is 0")
