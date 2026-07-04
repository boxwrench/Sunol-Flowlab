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

func test_topological_sort_order() -> void:
	var context := SimulationContext.new()
	var res := ConfigLoader.load_plant_config("phase1_single_basin")
	assert_true(res.success, "Config should load successfully")
	
	var ok := PlantFactory.build_plant(context, res.topology_data, res.initial_conditions_data)
	assert_true(ok, "Factory build should succeed")
	
	# Verify that the sorted order matches the expected topological order:
	# [SOURCE, BASIN_01, DRAIN_SINK, SINK, SPILL_SINK]
	var order: Array = []
	for unit in context.topological_units_list:
		order.append(unit.unit_id)
		
	assert_eq(order.size(), 5)
	assert_eq(order[0], &"SOURCE")
	assert_eq(order[1], &"BASIN_01")
	assert_eq(order[2], &"DRAIN_SINK")
	assert_eq(order[3], &"SINK")
	assert_eq(order[4], &"SPILL_SINK")

func test_topological_sort_permutation_invariance() -> void:
	var res := ConfigLoader.load_plant_config("phase1_single_basin")
	assert_true(res.success, "Config should load")
	
	var original_units: Array = res.topology_data["units"].duplicate()
	
	# Permute declaration order (e.g. reverse it)
	var permuted_units := original_units.duplicate()
	permuted_units.reverse()
	
	var permuted_topology: Dictionary = res.topology_data.duplicate()
	permuted_topology["units"] = permuted_units
	
	var context1 := SimulationContext.new()
	var ok1 := PlantFactory.build_plant(context1, res.topology_data, res.initial_conditions_data)
	assert_true(ok1)
	
	var context2 := SimulationContext.new()
	var ok2 := PlantFactory.build_plant(context2, permuted_topology, res.initial_conditions_data)
	assert_true(ok2)
	
	# Assert that both lists of unit IDs are identical
	var order1: Array = []
	for unit in context1.topological_units_list:
		order1.append(unit.unit_id)
		
	var order2: Array = []
	for unit in context2.topological_units_list:
		order2.append(unit.unit_id)
		
	assert_eq(order1, order2, "Topological order must be invariant to declaration order permutation")

func test_topological_sort_cycle_detection() -> void:
	# Temporarily disable crash on assert in GUT so we can verify the assertion failure
	# Or, since PlantValidator already fails on cycle, we can verify cycle detection there,
	# and assert that PlantFactory.build_plant returns false/fails on cyclic data.
	var cyclic_topology := _read_json("res://tests/fixtures/cyclic_topology.json")
	var context := SimulationContext.new()
	
	# Since GUT test runner handles assert(false, ...), we can run it or use validate_config
	var validation := PlantValidator.validate_config({}, cyclic_topology, {})
	assert_gt(validation.errors.size(), 0, "Validator should detect cycles")
