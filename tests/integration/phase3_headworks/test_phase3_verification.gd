extends "res://addons/gut/test.gd"

func _setup_engine() -> SimulationEngine:
	var engine := SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("phase3_headworks")
	assert_true(config.success, "Config should load")
	var ok: bool = PlantFactory.build_plant(engine.context, config.topology_data,
		config.initial_conditions_data, config.controllers_data)
	assert_true(ok, "Factory build should succeed")
	return engine

func _state_hash(engine: SimulationEngine) -> String:
	var parts: Array[String] = [str(engine.clock.tick_count)]
	for u in engine.context.units_list:
		if u is StorageUnit:
			parts.append("%s:vol=%s:lvl=%s" % [u.unit_id, u.volume_m3, u.level_m])
	for a in engine.context.actuators_list:
		parts.append("%s:pos=%s:cmd=%s" % [a.actuator_id, a.position, a.commanded_position])
	for c in engine.context.controllers_list:
		parts.append("%s:mode=%s:sp=%s" % [c.controller_id, c.control_mode, c.get("setpoint")])
	return ",".join(parts)

func test_phase3_soak_100k_ticks() -> void:
	var engine := _setup_engine()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Open intermediate manual valves so flow propagates
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

	var start_time_usec: float = float(Time.get_ticks_usec())
	var negative_volume_detected := false

	for tick in range(1, 100001):
		# Every 5000 ticks, change commanded position of source valves
		if tick % 5000 == 1:
			var target_pos_1 := rng.randf_range(20.0, 100.0)
			var target_pos_2 := rng.randf_range(20.0, 100.0)
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN_01", target_pos_1))
			engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN_02", target_pos_2))

		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)

		# Direct volume check (every tick)
		for u in engine.context.units_list:
			if u is StorageUnit and u.volume_m3 < 0.0:
				negative_volume_detected = true

		# Ledger error check
		if tick % 1000 == 0:
			var current_storage := 0.0
			for u in engine.context.units_list:
				if u is StorageUnit:
					current_storage += u.volume_m3

			var report := engine.mass_balance_tracker.report(current_storage)
			var scale: float = max(initial_total_volume + engine.mass_balance_tracker.cumulative_inflow_m3, 1.0)
			var tolerance: float = 1e-9 * scale * sqrt(float(tick))
			assert_lt(abs(report.mass_balance_error_m3), tolerance,
				"Ledger error at tick %d must be within tolerance (error: %f, tolerance: %f)" % [tick, report.mass_balance_error_m3, tolerance])

	assert_false(negative_volume_detected, "No unit volume must be negative during the soak")
	var duration_ms: float = (float(Time.get_ticks_usec()) - start_time_usec) / 1000.0
	print("test_phase3_soak_100k_ticks Benchmark: 100,000 ticks took %f ms" % duration_ms)

func test_availability_churn_100k_ticks() -> void:
	var engine := _setup_engine()
	engine.context.rng.seed = 12345

	# Open intermediate manual valves so flow propagates
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

	var start_time_usec: float = float(Time.get_ticks_usec())
	var negative_volume_detected := false

	for tick in range(1, 100001):
		# Toggle basins in/out of service every 500 ticks using context.rng
		if tick % 500 == 0:
			var basin_idx = engine.context.rng.randi_range(1, 5)
			var basin_id = StringName("BASIN_0%d" % basin_idx)
			var current_state = engine.context.units_dict[basin_id].in_service
			engine.enqueue(SetBasinServiceCommand.new(basin_id, not current_state))

		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)

		# Direct volume check (every tick)
		for u in engine.context.units_list:
			if u is StorageUnit and u.volume_m3 < 0.0:
				negative_volume_detected = true

		# Ledger error check
		if tick % 1000 == 0:
			var current_storage := 0.0
			for u in engine.context.units_list:
				if u is StorageUnit:
					current_storage += u.volume_m3

			var report := engine.mass_balance_tracker.report(current_storage)
			var scale: float = max(initial_total_volume + engine.mass_balance_tracker.cumulative_inflow_m3, 1.0)
			var tolerance: float = 1e-9 * scale * sqrt(float(tick))
			assert_lt(abs(report.mass_balance_error_m3), tolerance,
				"Ledger error at tick %d must be within tolerance (error: %f, tolerance: %f)" % [tick, report.mass_balance_error_m3, tolerance])

	assert_false(negative_volume_detected, "No unit volume must be negative during availability churn")
	var duration_ms: float = (float(Time.get_ticks_usec()) - start_time_usec) / 1000.0
	print("test_availability_churn_100k_ticks Benchmark: 100,000 ticks took %f ms" % duration_ms)

func test_deterministic_replay_phase3() -> void:
	var engine1 := _setup_engine()

	# Open manual valves
	for act_id in [&"VALVE_OUT_RES_01", &"VALVE_OUT_RES_02", &"VALVE_OUT_MAN_01", &"VALVE_OUT_FM_01"]:
		engine1.context.actuators_dict[act_id].set_commanded_position(80.0)
		engine1.context.actuators_dict[act_id].position = 80.0

	for i in range(1, 6):
		var act_id = StringName("VALVE_OUT_BASIN_0%d" % i)
		engine1.context.actuators_dict[act_id].set_commanded_position(80.0)
		engine1.context.actuators_dict[act_id].position = 80.0

	# Let's seed the RNG for command generation
	var cmd_rng := RandomNumberGenerator.new()
	cmd_rng.seed = 54321

	# Generate a sequence of commands for ticks 1 to 1000
	var command_list: Array[SimulationCommand] = []
	for tick in range(1, 1001):
		if tick % 50 == 0:
			var valves := [&"VALVE_IN_01", &"VALVE_IN_02", &"VALVE_OUT_RES_01", &"VALVE_OUT_RES_02", &"VALVE_OUT_MAN_01", &"VALVE_OUT_FM_01"]
			var valve_id = valves[cmd_rng.randi_range(0, valves.size() - 1)]
			var target_pos = cmd_rng.randf_range(10.0, 90.0)
			command_list.append(SetValvePositionCommand.new(valve_id, target_pos, tick))
		if tick % 120 == 0:
			var basin_idx = cmd_rng.randi_range(1, 5)
			var basin_id = StringName("BASIN_0%d" % basin_idx)
			var in_service = cmd_rng.randf() > 0.5
			command_list.append(SetBasinServiceCommand.new(basin_id, in_service, tick))

	# Enqueue all commands to engine1
	for cmd in command_list:
		engine1.enqueue(cmd)

	# Run engine1 for 1000 ticks and record state trajectory
	var trajectory1: Array[String] = []
	for tick in range(1, 1001):
		engine1.clock.tick_count = tick
		engine1.context.current_tick = tick
		engine1.run_tick(1.0)
		trajectory1.append(_state_hash(engine1))

	# Now, create engine2 (identical fresh build)
	var engine2 := _setup_engine()

	# Open manual valves identically
	for act_id in [&"VALVE_OUT_RES_01", &"VALVE_OUT_RES_02", &"VALVE_OUT_MAN_01", &"VALVE_OUT_FM_01"]:
		engine2.context.actuators_dict[act_id].set_commanded_position(80.0)
		engine2.context.actuators_dict[act_id].position = 80.0

	for i in range(1, 6):
		var act_id = StringName("VALVE_OUT_BASIN_0%d" % i)
		engine2.context.actuators_dict[act_id].set_commanded_position(80.0)
		engine2.context.actuators_dict[act_id].position = 80.0

	# Enqueue all the SAME commands to engine2
	for cmd in command_list:
		var new_cmd: SimulationCommand
		if cmd is SetValvePositionCommand:
			new_cmd = SetValvePositionCommand.new(cmd.actuator_id, cmd.target_position, cmd.apply_tick)
		elif cmd is SetBasinServiceCommand:
			new_cmd = SetBasinServiceCommand.new(cmd.target_unit_id, cmd.put_in_service, cmd.apply_tick)
		engine2.enqueue(new_cmd)

	# Run engine2 and compare trajectory at every step
	for tick in range(1, 1001):
		engine2.clock.tick_count = tick
		engine2.context.current_tick = tick
		engine2.run_tick(1.0)
		var hash2 = _state_hash(engine2)
		assert_eq(trajectory1[tick - 1], hash2, "Replay must be bit-identical at tick %d" % tick)
