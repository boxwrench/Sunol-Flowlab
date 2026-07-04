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
