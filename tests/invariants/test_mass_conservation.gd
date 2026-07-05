extends "res://addons/gut/test.gd"

func test_mass_conservation_100k_ticks() -> void:
	var engine: SimulationEngine = SimulationEngine.new()
	engine.snapshot_mode = SimulationEngine.SNAPSHOT_MODE_OFF
	
	var source: ExternalBoundary = ExternalBoundary.new()
	source.initialize({
		"unit_id": &"SOURCE",
		"boundary_type": &"SOURCE_INFLOW"
	})
	
	var storage: StorageUnit = StorageUnit.new()
	storage.initialize({
		"unit_id": &"BASIN_01",
		"maximum_volume_m3": 1000.0,
		"surface_area_m2": 100.0,
		"bottom_elevation_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5,
		"min_operating_level_m": 0.5,
		"initial_volume_m3": 500.0
	})
	
	var sink: ExternalBoundary = ExternalBoundary.new()
	sink.initialize({
		"unit_id": &"SINK",
		"boundary_type": &"TREATED_DEMAND"
	})
	
	var drain_sink: ExternalBoundary = ExternalBoundary.new()
	drain_sink.initialize({
		"unit_id": &"DRAIN_SINK",
		"boundary_type": &"DRAIN"
	})
	
	var spill_sink: ExternalBoundary = ExternalBoundary.new()
	spill_sink.initialize({
		"unit_id": &"SPILL_SINK",
		"boundary_type": &"SPILL"
	})
	
	# Sort and add units
	var units: Array = [source, storage, sink, drain_sink, spill_sink]
	units.sort_custom(func(a, b) -> bool: return String(a.unit_id) < String(b.unit_id))
	for u in units:
		engine.context.units_list.append(u)
		engine.context.units_dict[u.unit_id] = u
		
	# Setup ports and links
	var port_dict: Dictionary = {}
	var resolver: Callable = func(port_id: StringName) -> FlowPort:
		return port_dict.get(port_id)
		
	var port_src_out: FlowPort = FlowPort.new(&"PORT_SRC_OUT", source, &"OUTLET")
	var port_basin_in: FlowPort = FlowPort.new(&"PORT_BASIN_IN", storage, &"INLET")
	var port_basin_out: FlowPort = FlowPort.new(&"PORT_BASIN_OUT", storage, &"OUTLET")
	var port_sink_in: FlowPort = FlowPort.new(&"PORT_SINK_IN", sink, &"INLET")
	var port_basin_drain: FlowPort = FlowPort.new(&"PORT_BASIN_DRAIN", storage, &"DRAIN")
	var port_drain_in: FlowPort = FlowPort.new(&"PORT_DRAIN_IN", drain_sink, &"INLET")
	
	for p in [port_src_out, port_basin_in, port_basin_out, port_sink_in, port_basin_drain, port_drain_in]:
		port_dict[p.port_id] = p
		p.parent_unit.ports[p.port_id] = p
		
	var valve_in: SimValve = SimValve.new(&"VALVE_IN")
	valve_in.initialize({"opening_rate_percent_per_s": 10.0, "initial_position": 50.0})
	
	var valve_out: SimValve = SimValve.new(&"VALVE_OUT")
	valve_out.initialize({"opening_rate_percent_per_s": 10.0, "initial_position": 40.0})
	
	var valve_drain: SimValve = SimValve.new(&"VALVE_DRAIN")
	valve_drain.initialize({"opening_rate_percent_per_s": 10.0, "initial_position": 0.0})
	
	# Register actuators
	var actuators: Array = [valve_in, valve_out, valve_drain]
	actuators.sort_custom(func(a, b) -> bool: return String(a.actuator_id) < String(b.actuator_id))
	for act in actuators:
		engine.context.actuators_list.append(act)
		engine.context.actuators_dict[act.actuator_id] = act
		
	var link_in: FlowLink = FlowLink.new()
	link_in.initialize({
		"link_id": &"LINK_IN",
		"max_flow_m3s": 10.0,
		"source_port_id": &"PORT_SRC_OUT",
		"destination_port_id": &"PORT_BASIN_IN"
	}, resolver)
	link_in.actuator = valve_in
	
	var link_out: FlowLink = FlowLink.new()
	link_out.initialize({
		"link_id": &"LINK_OUT",
		"max_flow_m3s": 8.0,
		"source_port_id": &"PORT_BASIN_OUT",
		"destination_port_id": &"PORT_SINK_IN"
	}, resolver)
	link_out.actuator = valve_out
	
	var link_drain: FlowLink = FlowLink.new()
	link_drain.initialize({
		"link_id": &"LINK_DRAIN",
		"max_flow_m3s": 5.0,
		"source_port_id": &"PORT_BASIN_DRAIN",
		"destination_port_id": &"PORT_DRAIN_IN"
	}, resolver)
	link_drain.actuator = valve_drain
	
	for l in [link_in, link_out, link_drain]:
		engine.context.links_list.append(l)
		engine.context.links_dict[l.link_id] = l
		
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 98765
	
	var start_time_usec: float = float(Time.get_ticks_usec())
	
	engine.mass_balance_tracker.initialize(500.0)
	
	for tick in range(1, 100001):
		if tick % 100 == 1:
			valve_in.set_commanded_position(rng.randf_range(0.0, 100.0))
			valve_out.set_commanded_position(rng.randf_range(0.0, 100.0))
			valve_drain.set_commanded_position(rng.randf_range(0.0, 100.0))
			
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		if tick % 1000 == 0:
			var report: Dictionary = engine.mass_balance_tracker.report(storage.volume_m3)
			var total_volume_scale: float = max(500.0 + engine.mass_balance_tracker.cumulative_inflow_m3, 1.0)
			var tolerance: float = 1e-9 * total_volume_scale * sqrt(float(tick))
			
			assert_lt(abs(report.mass_balance_error_m3), tolerance, "At tick %d, error %f must be within tolerance %f" % [tick, report.mass_balance_error_m3, tolerance])
			
	var duration_ms: float = (float(Time.get_ticks_usec()) - start_time_usec) / 1000.0
	print("WP1.2 Benchmark: 100,000 ticks took %f ms" % duration_ms)

