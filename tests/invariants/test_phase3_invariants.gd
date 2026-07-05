extends "res://addons/gut/test.gd"

func _setup_engine() -> SimulationEngine:
	var engine := SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("phase3_headworks")
	assert_true(config.success, "Config should load")
	var ok: bool = PlantFactory.build_plant(engine.context, config.topology_data,
		config.initial_conditions_data, config.controllers_data)
	assert_true(ok, "Factory build should succeed")
	return engine

func test_no_water_created_phase3() -> void:
	var engine := _setup_engine()

	# Open manual valves
	engine.context.actuators_dict[&"VALVE_OUT_RES_01"].set_commanded_position(80.0)
	engine.context.actuators_dict[&"VALVE_OUT_RES_01"].position = 80.0
	engine.context.actuators_dict[&"VALVE_OUT_RES_02"].set_commanded_position(80.0)
	engine.context.actuators_dict[&"VALVE_OUT_RES_02"].position = 80.0
	engine.context.actuators_dict[&"VALVE_OUT_MAN_01"].set_commanded_position(80.0)
	engine.context.actuators_dict[&"VALVE_OUT_MAN_01"].position = 80.0
	engine.context.actuators_dict[&"VALVE_OUT_FM_01"].set_commanded_position(80.0)
	engine.context.actuators_dict[&"VALVE_OUT_FM_01"].position = 80.0

	for i in range(1, 6):
		var act_id = StringName("VALVE_OUT_BASIN_0%d" % i)
		engine.context.actuators_dict[act_id].set_commanded_position(80.0)
		engine.context.actuators_dict[act_id].position = 80.0

	var initial_total_volume := 0.0
	for u in engine.context.units_list:
		if u is StorageUnit:
			initial_total_volume += u.volume_m3

	engine.mass_balance_tracker.initialize(initial_total_volume)

	var rng := RandomNumberGenerator.new()
	rng.seed = 98765

	for tick in range(1, 10001):
		if tick % 100 == 1:
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN_01", rng.randf_range(0.0, 100.0)))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN_02", rng.randf_range(0.0, 100.0)))

		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)

		if tick % 1000 == 0:
			var current_storage := 0.0
			for u in engine.context.units_list:
				if u is StorageUnit:
					current_storage += u.volume_m3

			var report: Dictionary = engine.mass_balance_tracker.report(current_storage)
			var scale: float = max(initial_total_volume + engine.mass_balance_tracker.cumulative_inflow_m3, 1.0)
			var tolerance: float = 1e-9 * scale * sqrt(float(tick))
			assert_lt(abs(report.mass_balance_error_m3), tolerance,
				"Ledger error at tick %d must be within tolerance (error: %f, tolerance: %f)" % [tick, report.mass_balance_error_m3, tolerance])

func test_dag_unchanged_after_availability_toggle() -> void:
	var engine := _setup_engine()

	var list_before := []
	for u in engine.context.topological_units_list:
		list_before.append(u)

	# Take BASIN_03 out of service
	var cmd := SetBasinServiceCommand.new(&"BASIN_03", false)
	cmd.execute(engine.context)

	var list_after := []
	for u in engine.context.topological_units_list:
		list_after.append(u)

	assert_eq(list_before.size(), list_after.size(), "Topological list size must be unchanged")
	for i in range(list_before.size()):
		assert_eq(list_before[i], list_after[i], "ProcessUnit at index %d must be identical" % i)
