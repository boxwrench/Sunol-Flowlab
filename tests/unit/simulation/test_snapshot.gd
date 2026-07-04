extends "res://addons/gut/test.gd"

func test_snapshot_contents_and_mutation_guard() -> void:
	var engine: SimulationEngine = SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("phase1_single_basin")
	assert_true(config.success)
	
	var build_ok: bool = PlantFactory.build_plant(engine.context, config.topology_data, config.initial_conditions_data)
	assert_true(build_ok)
	
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	var snap1: Dictionary = engine.latest_snapshot
	assert_not_null(snap1)
	assert_eq(snap1.tick, 1)
	assert_eq(snap1.units.BASIN_01.volume_m3, 502.5)
	
	# Mutation guard check: modifying the returned snapshot dictionary doesn't change domain state
	snap1.units.BASIN_01.volume_m3 = 9999.0
	assert_eq(engine.context.units_dict.BASIN_01.volume_m3, 502.5)
	
	# Verify that in-place modification of engine.latest_snapshot alters its hash representation
	var original_hash: int = engine.previous_snapshot_hash
	engine.latest_snapshot.units.BASIN_01.volume_m3 = 9999.0
	var modified_hash: int = str(engine.latest_snapshot).hash()
	assert_ne(original_hash, modified_hash, "Hash should be different after in-place mutation")
