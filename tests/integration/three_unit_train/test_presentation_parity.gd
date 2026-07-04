extends "res://addons/gut/test.gd"

func test_presentation_parity_run() -> void:
	# 1. Pure Headless Run
	var engine_headless := SimulationEngine.new()
	var config := ConfigLoader.load_plant_config("phase2_three_unit")
	assert_true(config.success, "Headless config load should succeed")
	
	var build_ok = PlantFactory.build_plant(
		engine_headless.context,
		config.topology_data,
		config.initial_conditions_data,
		config.controllers_data
	)
	assert_true(build_ok, "Headless build should succeed")
	
	# Configure valves to instant mode
	for act_id in engine_headless.context.actuators_dict:
		var actuator: SimValve = engine_headless.context.actuators_dict[act_id]
		actuator.instant_mode = true
		
	# Enqueue commands
	engine_headless.enqueue(SetControllerModeCommand.new(&"LC_BASIN", &"AUTO"))
	engine_headless.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", 6.0))
	engine_headless.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 80.0))
	engine_headless.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", 30.0))
	
	# Run 100 ticks
	for tick in range(1, 101):
		engine_headless.clock.tick_count = tick
		engine_headless.context.current_tick = tick
		engine_headless.run_tick(1.0)
		
	var headless_snap = SnapshotService.take_snapshot(engine_headless.context, engine_headless)
	
	# 2. Visual Scene Run
	var visual_scene = load("res://scenes/plant/three_unit_train.tscn").instantiate()
	add_child_autofree(visual_scene)
	
	# SimulationHost is initialized and app_bootstrap runs when added to scene tree
	var host: SimulationHost = visual_scene.get_node("SimulationHost")
	assert_not_null(host, "SimulationHost must exist in visual scene")
	
	# Configure host valves to instant mode
	for act_id in host.engine.context.actuators_dict:
		var actuator: SimValve = host.engine.context.actuators_dict[act_id]
		actuator.instant_mode = true
		
	# Enqueue same commands
	host.engine.enqueue(SetControllerModeCommand.new(&"LC_BASIN", &"AUTO"))
	host.engine.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", 6.0))
	host.engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 80.0))
	host.engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", 30.0))
	
	# Run 100 ticks via advance_frame (simulates process loops)
	for tick in range(1, 101):
		host.engine.advance_frame(1.0)
		
	var visual_snap = SnapshotService.take_snapshot(host.engine.context, host.engine)
	
	# Compare final snapshots for exact parity
	assert_eq(visual_snap.tick, headless_snap.tick, "Tick count should match")
	
	for unit_id in headless_snap.units:
		var h_unit: Dictionary = headless_snap.units[unit_id]
		var v_unit: Dictionary = visual_snap.units[unit_id]
		if h_unit.has("volume_m3"):
			assert_eq(v_unit.volume_m3, h_unit.volume_m3, "Volume mismatch on unit " + String(unit_id))
			assert_eq(v_unit.level_m, h_unit.level_m, "Level mismatch on unit " + String(unit_id))
		if h_unit.has("current_flow_m3s"):
			assert_eq(v_unit.current_flow_m3s, h_unit.current_flow_m3s, "Flow mismatch on unit " + String(unit_id))
		
	for act_id in headless_snap.actuators:
		var h_act: Dictionary = headless_snap.actuators[act_id]
		var v_act: Dictionary = visual_snap.actuators[act_id]
		assert_eq(v_act.position, h_act.position, "Position mismatch on actuator " + String(act_id))
		assert_eq(v_act.commanded_position, h_act.commanded_position, "Commanded position mismatch on actuator " + String(act_id))
		
	for ctrl_id in headless_snap.controllers:
		var h_ctrl: Dictionary = headless_snap.controllers[ctrl_id]
		var v_ctrl: Dictionary = visual_snap.controllers[ctrl_id]
		assert_eq(v_ctrl.setpoint, h_ctrl.setpoint, "Setpoint mismatch on controller " + String(ctrl_id))
		assert_eq(v_ctrl.control_mode, h_ctrl.control_mode, "Mode mismatch on controller " + String(ctrl_id))
		assert_eq(v_ctrl.previous_output, h_ctrl.previous_output, "Previous output mismatch on controller " + String(ctrl_id))
