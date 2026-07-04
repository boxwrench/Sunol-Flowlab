extends "res://addons/gut/test.gd"

func test_level_controller_proportional_response() -> void:
	var context := SimulationContext.new()
	
	var valve := SimValve.new(&"VALVE_OUT")
	valve.instant_mode = true
	valve.set_commanded_position(50.0)
	context.actuators_dict[&"VALVE_OUT"] = valve
	
	var basin := StorageUnit.new()
	basin.initialize({
		"unit_id": "BASIN",
		"maximum_volume_m3": 1000.0,
		"surface_area_m2": 100.0,
		"bottom_elevation_m": 0.0,
		"min_operating_level_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5
	})
	basin.volume_m3 = 400.0 # level = 4.0m
	basin.update_level()
	context.units_dict[&"BASIN"] = basin
	
	var lc := LevelController.new()
	lc.initialize({
		"controller_id": "LC_BASIN",
		"type": "LevelController",
		"target_actuator_id": "VALVE_OUT",
		"pv_unit_id": "BASIN",
		"pv_property": "level_m",
		"control_mode": "AUTO",
		"setpoint": 5.0,
		"gain": 2.0,
		"deadband_m": 0.05,
		"min_output": 10.0,
		"max_output": 90.0
	})
	
	# Bumpless transfer initialization: previous_output should start from valve's current position (50)
	lc.previous_output = valve.commanded_position
	
	# Run 1: level = 4.0m, setpoint = 5.0m, error = 1.0m (positive error).
	# Since error > deadband (0.05), output = previous_output + gain * error = 50 + 2 * 1.0 = 52.0
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 52.0)
	assert_eq(lc.previous_output, 52.0)
	assert_false(valve.is_manual)
	
	# Run 2: level changes to 5.02m. setpoint = 5.0m, error = -0.02m.
	# abs(error) (0.02) <= deadband (0.05), output should not change (stay at 52.0)
	basin.volume_m3 = 502.0
	basin.update_level()
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 52.0)
	assert_eq(lc.previous_output, 52.0)
	
	# Run 3: level changes to 6.0m. setpoint = 5.0m, error = -1.0m.
	# error = -1.0, which is outside deadband.
	# output = 52.0 + 2.0 * (-1.0) = 50.0
	basin.volume_m3 = 600.0
	basin.update_level()
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 50.0)
	assert_eq(lc.previous_output, 50.0)

func test_level_controller_clamping() -> void:
	var context := SimulationContext.new()
	var valve := SimValve.new(&"VALVE_OUT")
	valve.instant_mode = true
	valve.set_commanded_position(50.0)
	context.actuators_dict[&"VALVE_OUT"] = valve
	
	var basin := StorageUnit.new()
	basin.initialize({
		"unit_id": "BASIN",
		"maximum_volume_m3": 1000.0,
		"surface_area_m2": 100.0,
		"bottom_elevation_m": 0.0,
		"min_operating_level_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5
	})
	basin.volume_m3 = 100.0 # level = 1.0m
	basin.update_level()
	context.units_dict[&"BASIN"] = basin
	
	var lc := LevelController.new()
	lc.initialize({
		"controller_id": "LC_BASIN",
		"type": "LevelController",
		"target_actuator_id": "VALVE_OUT",
		"pv_unit_id": "BASIN",
		"pv_property": "level_m",
		"control_mode": "AUTO",
		"setpoint": 5.0,
		"gain": 20.0,
		"deadband_m": 0.0,
		"min_output": 10.0,
		"max_output": 90.0
	})
	lc.previous_output = valve.commanded_position
	
	# error = 5 - 1 = 4. gain = 20. output = 50 + 20 * 4 = 130 -> clamped to max_output (90.0)
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 90.0)
	assert_eq(lc.previous_output, 90.0)
	
	# Test min output clamp
	basin.volume_m3 = 900.0 # level = 9.0m
	basin.update_level()
	# error = 5 - 9 = -4. output = 90 + 20 * (-4) = 10 -> clamped to min_output (10.0)
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 10.0)
	assert_eq(lc.previous_output, 10.0)

func test_level_controller_manual_mode_and_bumpless_transfer() -> void:
	var context := SimulationContext.new()
	var valve := SimValve.new(&"VALVE_OUT")
	valve.instant_mode = true
	valve.set_commanded_position(30.0)
	context.actuators_dict[&"VALVE_OUT"] = valve
	
	var basin := StorageUnit.new()
	basin.initialize({
		"unit_id": "BASIN",
		"maximum_volume_m3": 1000.0,
		"surface_area_m2": 100.0,
		"bottom_elevation_m": 0.0,
		"min_operating_level_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5
	})
	basin.volume_m3 = 400.0 # level = 4.0m
	basin.update_level()
	context.units_dict[&"BASIN"] = basin
	
	var lc := LevelController.new()
	lc.initialize({
		"controller_id": "LC_BASIN",
		"type": "LevelController",
		"target_actuator_id": "VALVE_OUT",
		"pv_unit_id": "BASIN",
		"pv_property": "level_m",
		"control_mode": "MANUAL",
		"setpoint": 5.0,
		"gain": 2.0,
		"deadband_m": 0.0,
		"min_output": 0.0,
		"max_output": 100.0
	})
	
	# In MANUAL mode, evaluate shouldn't touch valve position, and should track valve's commanded position
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 30.0)
	assert_eq(lc.previous_output, 30.0)
	assert_true(valve.is_manual)
	
	# Register controller in context before validating/running the command
	context.controllers_dict[&"LC_BASIN"] = lc
	
	# Command changes the mode to AUTO (bumpless transfer)
	var cmd := SetControllerModeCommand.new(&"LC_BASIN", &"AUTO")
	var errs := cmd.validate(context)
	assert_true(errs.is_empty())
	
	cmd.execute(context)
	assert_eq(lc.control_mode, &"AUTO")
	assert_eq(lc.previous_output, 30.0, "Bumpless transfer: previous_output must be initialized to current valve commanded position")
	
	# Next tick evaluate: error = 5 - 4 = 1. output = 30 + 2 * 1 = 32.0.
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 32.0)
	assert_eq(lc.previous_output, 32.0)
	assert_false(valve.is_manual)

func test_level_controller_unknown_mode_fallback() -> void:
	var context := SimulationContext.new()
	var valve := SimValve.new(&"VALVE_OUT")
	valve.instant_mode = true
	valve.set_commanded_position(45.0)
	context.actuators_dict[&"VALVE_OUT"] = valve
	
	var basin := StorageUnit.new()
	basin.initialize({
		"unit_id": "BASIN",
		"maximum_volume_m3": 1000.0,
		"surface_area_m2": 100.0,
		"bottom_elevation_m": 0.0,
		"min_operating_level_m": 0.0,
		"high_level_m": 9.0,
		"spill_level_m": 9.5
	})
	basin.volume_m3 = 400.0
	basin.update_level()
	context.units_dict[&"BASIN"] = basin
	
	var lc := LevelController.new()
	lc.initialize({
		"controller_id": "LC_BASIN",
		"type": "LevelController",
		"target_actuator_id": "VALVE_OUT",
		"pv_unit_id": "BASIN",
		"pv_property": "level_m",
		"control_mode": "FORCED", # Unknown mode
		"setpoint": 5.0,
		"gain": 2.0,
		"deadband_m": 0.0,
		"min_output": 0.0,
		"max_output": 100.0
	})
	
	# Evaluate under unknown mode (FORCED)
	# Should fallback to MANUAL behavior: set valve to manual, track position, no closed loop updates
	lc.evaluate(context)
	assert_eq(valve.commanded_position, 45.0)
	assert_eq(lc.previous_output, 45.0)
	assert_true(valve.is_manual)

