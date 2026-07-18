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

func test_commanded_flow_mode_rejected() -> void:
	# WP4.3: COMMANDED is no longer a supported flow_mode. A link configured with
	# it must be rejected clearly by the validator (the schema enum rejects it too).
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
				"spill_destination_id": "SINK",
				"ports": [{"port_id": "BASIN_OUT", "port_type": "OUTLET"}]
			},
			{
				"unit_id": "SINK",
				"type": "ExternalBoundary",
				"display_name": "Sink",
				"boundary_type": "TREATED_DEMAND",
				"ports": [{"port_id": "SINK_IN", "port_type": "INLET"}]
			}
		],
		"actuators": [],
		"links": [
			{
				"link_id": "LINK_OUT",
				"display_name": "Basin Out",
				"max_flow_m3s": 1.0,
				"flow_mode": "COMMANDED",
				"source_port_id": "BASIN_OUT",
				"destination_port_id": "SINK_IN"
			}
		]
	}

	var res: Dictionary = PlantValidator.validate_config({}, topology, {})
	assert_gt(res.errors.size(), 0, "COMMANDED flow_mode should be rejected")
	var found: bool = false
	for err in res.errors:
		if "invalid flow_mode 'COMMANDED'" in err:
			found = true
			break
	assert_true(found, "Error list should name the invalid flow_mode 'COMMANDED'")

	# RESTRICTED and GRAVITY remain valid flow modes.
	for mode in ["RESTRICTED", "GRAVITY"]:
		topology.links[0].flow_mode = mode
		if mode == "GRAVITY":
			topology.links[0]["design_head_m"] = 2.0
		var ok: Dictionary = PlantValidator.validate_config({}, topology, {})
		for err in ok.errors:
			assert_false("invalid flow_mode" in err, "%s must remain a valid flow_mode" % mode)

func test_invalid_in_service_config() -> void:
	var plant_data := {}
	var topology_invalid_in_service := {
		"units": [
			{
				"unit_id": "BASIN",
				"type": "StorageUnit",
				"display_name": "Basin",
				"in_service": "not_a_boolean", # invalid type
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
		"actuators": [],
		"links": []
	}
	
	var res1 := PlantValidator.validate_config(plant_data, topology_invalid_in_service, {}, 1.0, {}, {})
	assert_gt(res1.errors.size(), 0, "Should reject non-boolean in_service in topology")
	var found_topo_err := false
	for err in res1.errors:
		if "in_service must be a boolean" in err:
			found_topo_err = true
	assert_true(found_topo_err, "Should report in_service type error in topology")
	
	var topology_valid := {
		"units": [
			{
				"unit_id": "BASIN",
				"type": "StorageUnit",
				"display_name": "Basin",
				"in_service": true,
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
		"actuators": [],
		"links": []
	}
	
	var init_conditions_invalid_in_service := {
		"unit_states": [
			{
				"unit_id": "BASIN",
				"in_service": "not_a_boolean_either" # invalid type
			}
		]
	}
	
	var res2 := PlantValidator.validate_config(plant_data, topology_valid, init_conditions_invalid_in_service, 1.0, {}, {})
	assert_gt(res2.errors.size(), 0, "Should reject non-boolean in_service in initial conditions")
	var found_init_err := false
	for err in res2.errors:
		if "in_service must be a boolean" in err:
			found_init_err = true
	assert_true(found_init_err, "Should report in_service type error in initial conditions")


