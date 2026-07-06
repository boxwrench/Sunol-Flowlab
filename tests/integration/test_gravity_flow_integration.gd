extends "res://addons/gut/test.gd"

func _setup_engine() -> SimulationEngine:
	var engine: SimulationEngine = SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("gravity_demo")
	assert_true(config.success, "Configuration should load successfully")
	
	var build_ok: bool = PlantFactory.build_plant(
		engine.context, 
		config.topology_data, 
		config.initial_conditions_data
	)
	assert_true(build_ok, "Factory build should succeed")
	return engine

func test_gravity_flow_self_regulation_and_equalization() -> void:
	var engine := _setup_engine()
	
	var basin_a: StorageUnit = engine.context.units_dict[&"BASIN_A"]
	var basin_b: StorageUnit = engine.context.units_dict[&"BASIN_B"]
	var link_gravity: FlowLink = engine.context.links_dict[&"LINK_GRAVITY"]
	
	# Initial conditions:
	# BASIN_A volume: 80.0m3 (floor 5.0m, area 10.0m2 -> level 8.0m -> surface elev = 13.0m)
	# BASIN_B volume: 20.0m3 (floor 0.0m, area 10.0m2 -> level 2.0m -> surface elev = 2.0m)
	# VALVE_GRAVITY fully open.
	# dh = 11.0m. design_head = 2.0m. max_flow_m3s = 5.0.
	# Q = 5.0 * sqrt(11.0 / 2.0) = 5.0 * 2.345 = 11.72 -> clamped to 5.0m3/s.
	
	# Start mass balance tracking
	var initial_total: float = basin_a.volume_m3 + basin_b.volume_m3
	engine.mass_balance_tracker.initialize(initial_total)
	
	# Run until they equalize.
	# With dt = 1.0s, let's run for 200 ticks.
	# As Basin A levels drop and Basin B levels rise, they will meet.
	# Since total volume is 100.0m3 and surface area is 10.0m2 for each:
	# Final state when equalized:
	# surface_elev_a = surface_elev_b
	# 5.0 + level_a = 0.0 + level_b
	# level_a + 5.0 = level_b
	# Since area is 10.0m2: volume_a + 50.0 = volume_b
	# Also volume_a + volume_b = 100.0 -> volume_a + (volume_a + 50.0) = 100.0 -> 2*volume_a = 50.0 -> volume_a = 25.0, volume_b = 75.0.
	# level_a = 2.5m -> elev_a = 5.0 + 2.5 = 7.5m
	# level_b = 7.5m -> elev_b = 0.0 + 7.5 = 7.5m
	# Perfect! They should equalize at elev = 7.5m, volume_a = 25.0m3, volume_b = 75.0m3.
	
	for tick in range(1, 201):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
		# Mass balance check
		var total_vol = basin_a.volume_m3 + basin_b.volume_m3
		var report: Dictionary = engine.mass_balance_tracker.report(total_vol)
		assert_lt(abs(report.mass_balance_error_m3), 1e-9, "Ledger error must be < 1e-9")
		
	# Verify final states (they converge close to 7.5m, where Basin A drops slightly below B due to explicit Euler step, then reverse flow is blocked)
	assert_almost_eq(basin_a.volume_m3, 24.551049, 1e-3, "Basin A volume should equalize at 24.551m3")
	assert_almost_eq(basin_b.volume_m3, 75.448951, 1e-3, "Basin B volume should equalize at 75.449m3")
	assert_almost_eq(basin_a.water_surface_elevation_m(), 7.455105, 1e-3)
	assert_almost_eq(basin_b.water_surface_elevation_m(), 7.544895, 1e-3)
	assert_almost_eq(link_gravity.actual_flow_m3s, 0.0, 1e-3, "Equalized gravity flow must be 0")
	assert_eq(link_gravity.constraint_reason, "GRAVITY reverse blocked")

func test_gravity_flow_determinism_and_replay() -> void:
	var engine1 := _setup_engine()
	var engine2 := _setup_engine()
	
	# Run both engines for 100 ticks
	for tick in range(1, 101):
		engine1.clock.tick_count = tick
		engine1.context.current_tick = tick
		engine1.run_tick(1.0)
		
		engine2.clock.tick_count = tick
		engine2.context.current_tick = tick
		engine2.run_tick(1.0)
		
	var hash1 := _get_engine_state_hash(engine1)
	var hash2 := _get_engine_state_hash(engine2)
	assert_eq(hash1, hash2, "Command replay must yield identical state hashes")

func test_boundary_interaction_and_proration() -> void:
	var engine := _setup_engine()
	var basin_a: StorageUnit = engine.context.units_dict[&"BASIN_A"]
	
	# Let's verify boundary flow limit proration.
	# If we have a boundary limit, it should cap gravity flow correctly.
	
	var src_boundary: ExternalBoundary = engine.context.units_dict[&"SOURCE"]
	src_boundary.flow_limit_m3s = 2.0
	
	var valve_in: SimValve = engine.context.actuators_dict[&"VALVE_IN"]
	valve_in.instant_mode = true
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 100.0, 1))
	
	basin_a.volume_m3 = 0.0
	basin_a.update_level()
	
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	var link_in: FlowLink = engine.context.links_dict[&"LINK_IN"]
	assert_almost_eq(link_in.actual_flow_m3s, 2.0, 1e-9, "Inflow link must be capped at boundary flow limit (2.0)")

func test_port_order_insertion_independence() -> void:
	# F-11 test: verify sorting of port IDs makes results independent of insertion order.
	var engine1 := _setup_engine()
	
	var config2 = ConfigLoader.load_plant_config("gravity_demo")
	
	# Permute the ports list in BASIN_A
	for u in config2.topology_data.units:
		if u.unit_id == "BASIN_A":
			var ports_arr: Array = u.ports
			var t_port = ports_arr[0]
			ports_arr[0] = ports_arr[1]
			ports_arr[1] = t_port
			
	var engine2 := SimulationEngine.new()
	var build_ok = PlantFactory.build_plant(engine2.context, config2.topology_data, config2.initial_conditions_data)
	assert_true(build_ok)
	
	# Run both for 50 ticks
	for tick in range(1, 51):
		engine1.clock.tick_count = tick
		engine1.context.current_tick = tick
		engine1.run_tick(1.0)
		
		engine2.clock.tick_count = tick
		engine2.context.current_tick = tick
		engine2.run_tick(1.0)
		
	var hash1 := _get_engine_state_hash(engine1)
	var hash2 := _get_engine_state_hash(engine2)
	assert_eq(hash1, hash2, "Results must be identical under different unit/port declaration orders")

func _get_engine_state_hash(engine: SimulationEngine) -> String:
	var parts: Array[String] = []
	parts.append(str(engine.clock.tick_count))
	for unit in engine.context.units_list:
		if unit is StorageUnit:
			parts.append(String(unit.unit_id) + ":vol=" + str(unit.volume_m3) + ":lvl=" + str(unit.level_m))
	for link in engine.context.links_list:
		parts.append(String(link.link_id) + ":act_flow=" + str(link.actual_flow_m3s))
	return ",".join(parts)
