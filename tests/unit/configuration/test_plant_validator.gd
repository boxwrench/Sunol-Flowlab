extends "res://addons/gut/test.gd"

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var text: String = file.get_as_text()
		file.close()
		var val = JSON.parse_string(text)
		if typeof(val) == TYPE_DICTIONARY:
			return val
	return {}

func test_invalid_geometry() -> void:
	var topology: Dictionary = _read_json("res://tests/fixtures/invalid_geometry.json")
	var res: Dictionary = PlantValidator.validate_config({}, topology, {})
	
	assert_gt(res.errors.size(), 0, "Should have validation errors for invalid geometry")
	var found: bool = false
	for err in res.errors:
		if "inconsistent" in err:
			found = true
			break
	assert_true(found, "Error list should mention geometry inconsistency")

func test_cyclic_topology() -> void:
	var topology: Dictionary = _read_json("res://tests/fixtures/cyclic_topology.json")
	var res: Dictionary = PlantValidator.validate_config({}, topology, {})
	
	assert_gt(res.errors.size(), 0, "Should have validation errors for cyclic topology")
	var found: bool = false
	for err in res.errors:
		if "cyclic" in err:
			found = true
			break
	assert_true(found, "Error list should mention cyclic flow path detected")

func test_dangling_ports() -> void:
	var topology: Dictionary = _read_json("res://tests/fixtures/dangling_port.json")
	var res: Dictionary = PlantValidator.validate_config({}, topology, {})
	
	assert_gt(res.errors.size(), 0, "Should have validation errors for dangling ports")
	var found_src: bool = false
	var found_dest: bool = false
	for err in res.errors:
		if "PORT_A_OUT" in err:
			found_src = true
		if "PORT_B_IN" in err:
			found_dest = true
	assert_true(found_src, "Should catch dangling source port")
	assert_true(found_dest, "Should catch dangling destination port")

func test_valid_loader_load() -> void:
	var res: Dictionary = ConfigLoader.load_plant_config("phase1_single_basin")
	assert_true(res.success, "Valid config load should succeed")
	assert_eq(res.errors.size(), 0, "Should have no errors")

func test_invalid_controller_config() -> void:
	var plant_data := {}
	var topology := {
		"units": [
			{
				"unit_id": "BASIN",
				"type": "StorageUnit",
				"display_name": "Basin",
				"maximum_volume_m3": 100.0,
				"surface_area_m2": 10.0,
				"bottom_elevation_m": 0.0,
				"high_level_m": 9.0,
				"spill_level_m": 10.0,
				"min_operating_level_m": 0.5,
				"spill_destination_id": "SPILL_SINK",
				"ports": []
			},
			{
				"unit_id": "SPILL_SINK",
				"type": "ExternalBoundary",
				"display_name": "Spill Sink",
				"boundary_type": "SPILL",
				"ports": []
			}
		],
		"actuators": [
			{
				"actuator_id": "VALVE_OUT",
				"display_name": "Valve",
				"opening_rate_percent_per_s": 5.0,
				"closing_rate_percent_per_s": 5.0
			}
		],
		"links": []
	}
	
	# Case 1: invalid type, control_mode, and pv_property
	var controllers := {
		"controllers": [
			{
				"controller_id": "LC_BASIN",
				"type": "InvalidControllerType",
				"display_name": "Invalid Controller",
				"target_actuator_id": "VALVE_OUT",
				"pv_unit_id": "BASIN",
				"pv_property": "volume_m3", # invalid for LevelController which requires level_m
				"control_mode": "FORCED", # invalid starting mode
				"gain": 2.0,
				"deadband_m": 0.05,
				"min_output": 0.0,
				"max_output": 100.0
			}
		]
	}
	
	var res := PlantValidator.validate_config(plant_data, topology, {}, 1.0, controllers, {})
	assert_gt(res.errors.size(), 0, "Should have validation errors for invalid controller configuration")
	
	var found_type := false
	var found_mode := false
	var found_prop := false
	for err in res.errors:
		if "unknown controller type" in err:
			found_type = true
		if "control_mode must be 'MANUAL' or 'AUTO'" in err:
			found_mode = true
		if "pv_property must be 'level_m'" in err:
			found_prop = true
			
	assert_true(found_type, "Should catch unknown controller type")
	assert_true(found_mode, "Should catch invalid control mode")
	assert_true(found_prop, "Should catch invalid pv_property")

