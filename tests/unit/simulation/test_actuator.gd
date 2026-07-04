extends "res://addons/gut/test.gd"

func test_valve_travel_time() -> void:
	var valve: SimValve = SimValve.new(&"VALVE_01")
	valve.initialize({
		"opening_rate_percent_per_s": 5.0,
		"initial_position": 0.0,
		"commanded_position": 100.0,
		"instant_mode": false
	})
	
	assert_eq(valve.position, 0.0)
	
	# 20 ticks at 5%/tick = 100%
	for i in range(20):
		valve.update(1.0)
		var expected: float = min(100.0, (i + 1) * 5.0)
		assert_eq(valve.position, expected, "At step %d, position should be %f" % [i + 1, expected])
		
	assert_eq(valve.position, 100.0, "Valve should reach 100% after 20 seconds at 5%/s")

func test_valve_clamping() -> void:
	var valve: SimValve = SimValve.new(&"VALVE_01")
	valve.initialize({
		"initial_position": 50.0,
		"instant_mode": true
	})
	
	valve.set_commanded_position(150.0)
	assert_eq(valve.commanded_position, 100.0, "Commanded position should clamp to 100.0")
	assert_eq(valve.position, 100.0, "Actual position should match commanded position in instant mode")
	
	valve.set_commanded_position(-50.0)
	assert_eq(valve.commanded_position, 0.0, "Commanded position should clamp to 0.0")
	assert_eq(valve.position, 0.0, "Actual position should match commanded position in instant mode")

func test_instant_mode() -> void:
	var valve: SimValve = SimValve.new(&"VALVE_01")
	valve.initialize({
		"initial_position": 0.0,
		"opening_rate_percent_per_s": 5.0,
		"instant_mode": true
	})
	
	valve.set_commanded_position(50.0)
	assert_eq(valve.position, 50.0, "In instant mode, position should immediately update to commanded position")
