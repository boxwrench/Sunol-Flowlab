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
