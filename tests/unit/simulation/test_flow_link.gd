extends "res://addons/gut/test.gd"

func test_flow_link_request_logic() -> void:
	var dummy_unit: RefCounted = RefCounted.new()
	var src_port: FlowPort = FlowPort.new(&"PORT_SRC", dummy_unit, &"OUTLET")
	var dest_port: FlowPort = FlowPort.new(&"PORT_DEST", dummy_unit, &"INLET")
	
	var resolver: Callable = func(port_id: StringName) -> FlowPort:
		if port_id == &"PORT_SRC":
			return src_port
		if port_id == &"PORT_DEST":
			return dest_port
		return null
		
	var valve: SimValve = SimValve.new(&"VALVE_01")
	valve.initialize({
		"opening_rate_percent_per_s": 10.0,
		"initial_position": 100.0,
		"instant_mode": true
	})
	
	var link: FlowLink = FlowLink.new()
	link.initialize({
		"link_id": &"LINK_01",
		"max_flow_m3s": 2.5,
		"flow_mode": "RESTRICTED",
		"source_port_id": &"PORT_SRC",
		"destination_port_id": &"PORT_DEST"
	}, resolver)
	link.actuator = valve
	
	# Test 1: Fully open
	assert_eq(link.calculate_requested_flow(), 2.5)
	assert_eq(link.constraint_reason, "")
	
	# Test 2: Closed
	valve.set_commanded_position(0.0)
	assert_eq(link.calculate_requested_flow(), 0.0)
	assert_eq(link.constraint_reason, "Valve Closed")
	
	# Test 3: Partially open
	valve.set_commanded_position(50.0)
	assert_eq(link.calculate_requested_flow(), 1.25)
	assert_eq(link.constraint_reason, "Valve Restricted")
	
	# Test 4: Disabled link
	link.is_enabled = false
	assert_eq(link.calculate_requested_flow(), 0.0)
	assert_eq(link.constraint_reason, "Link Disabled")

func test_gravity_flow_orifice_law() -> void:
	var unit_a := StorageUnit.new()
	unit_a.initialize({
		"unit_id": &"BASIN_A",
		"type": "StorageUnit",
		"maximum_volume_m3": 100.0,
		"surface_area_m2": 10.0,
		"bottom_elevation_m": 2.0,
		"floor_elevation_m": 2.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5,
		"min_operating_level_m": 0.5,
		"spill_destination_id": "SPILL_SINK"
	})
	
	var unit_b := StorageUnit.new()
	unit_b.initialize({
		"unit_id": &"BASIN_B",
		"type": "StorageUnit",
		"maximum_volume_m3": 100.0,
		"surface_area_m2": 10.0,
		"bottom_elevation_m": 0.0,
		"floor_elevation_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5,
		"min_operating_level_m": 0.5,
		"spill_destination_id": "SPILL_SINK"
	})
	
	var port_a = FlowPort.new(&"PORT_A", unit_a, &"OUTLET")
	port_a.owner_unit = unit_a
	var port_b = FlowPort.new(&"PORT_B", unit_b, &"INLET")
	port_b.owner_unit = unit_b
	
	var resolver = func(port_id: StringName) -> FlowPort:
		if port_id == &"PORT_A": return port_a
		if port_id == &"PORT_B": return port_b
		return null
		
	var valve: SimValve = SimValve.new(&"VALVE_01")
	valve.initialize({
		"opening_rate_percent_per_s": 10.0,
		"initial_position": 100.0,
		"instant_mode": true
	})
	
	var link = FlowLink.new()
	link.initialize({
		"link_id": &"LINK_01",
		"max_flow_m3s": 4.0,
		"flow_mode": "GRAVITY",
		"design_head_m": 2.0,
		"source_port_id": &"PORT_A",
		"destination_port_id": &"PORT_B"
	}, resolver)
	link.actuator = valve
	
	# Set levels:
	# Basin A has 80m3 -> level_m = 8.0 -> elev = 2.0 + 8.0 = 10.0m
	# Basin B has 80m3 -> level_m = 8.0 -> elev = 0.0 + 8.0 = 8.0m
	# dh = 10.0 - 8.0 = 2.0m (which equals design_head_m = 2.0)
	unit_a.volume_m3 = 80.0
	unit_a.update_level()
	unit_b.volume_m3 = 80.0
	unit_b.update_level()
	
	# dh = 2.0 -> should yield max_flow (4.0)
	assert_almost_eq(link.calculate_requested_flow(), 4.0, 1e-9)
	assert_eq(link.constraint_reason, "GRAVITY self-regulating")
	
	# Test 0.25 * design_head -> dh = 0.5m
	# Set Basin B to 9.5m surface elevation -> dh = 10.0 - 9.5 = 0.5m
	# Q = 4.0 * sqrt(0.5 / 2.0) = 4.0 * sqrt(0.25) = 2.0
	unit_b.volume_m3 = 95.0
	unit_b.update_level()
	assert_almost_eq(link.calculate_requested_flow(), 2.0, 1e-9)
	assert_eq(link.constraint_reason, "GRAVITY self-regulating")
	
	# Test dh = 0 -> equalized
	unit_b.volume_m3 = 100.0 # B elevation is 10.0m
	unit_b.update_level()
	assert_almost_eq(link.calculate_requested_flow(), 0.0, 1e-9)
	assert_eq(link.constraint_reason, "GRAVITY equalized")
	
	# Test dh < 0 with reverse flow disallowed (default is false)
	# Basin B elevation is 11.0m (dh = 10.0 - 11.0 = -1.0)
	unit_b.volume_m3 = 110.0
	unit_b.update_level()
	assert_almost_eq(link.calculate_requested_flow(), 0.0, 1e-9)
	assert_eq(link.constraint_reason, "GRAVITY reverse blocked")
	
	# Test dh < 0 with reverse flow allowed
	link.reverse_flow_allowed = true
	# dh = -0.5m -> Q = -base * sqrt(0.5/2.0) = -4.0 * 0.5 = -2.0
	unit_b.volume_m3 = 105.0
	unit_b.update_level()
	assert_almost_eq(link.calculate_requested_flow(), -2.0, 1e-9)
	assert_eq(link.constraint_reason, "GRAVITY self-regulating")
	
	# Test clamping: dh = 10.0m (Basin B = 0m, Basin A = 10.0m -> dh = 10.0m)
	# base = 4.0
	# Q = 4.0 * sqrt(10.0 / 2.0) = 4.0 * sqrt(5.0) = 8.94 > 4.0 -> should clamp to 4.0
	unit_b.volume_m3 = 0.0
	unit_b.update_level()
	assert_almost_eq(link.calculate_requested_flow(), 4.0, 1e-9)
	assert_eq(link.constraint_reason, "GRAVITY clamped@max")
	
	# Test design_head <= 0 runtime rejection
	link.design_head_m = 0.0
	assert_almost_eq(link.calculate_requested_flow(), 0.0, 1e-9)
