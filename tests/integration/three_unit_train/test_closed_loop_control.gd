extends "res://addons/gut/test.gd"

func _setup_engine() -> SimulationEngine:
	var engine: SimulationEngine = SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("phase2_three_unit")
	assert_true(config.success, "Configuration should load successfully")
	
	# Pass controllers_data to PlantFactory
	var build_ok: bool = PlantFactory.build_plant(
		engine.context, 
		config.topology_data, 
		config.initial_conditions_data,
		config.controllers_data
	)
	assert_true(build_ok, "Factory build should succeed")
	
	return engine

func test_closed_loop_control_logic() -> void:
	var engine: SimulationEngine = _setup_engine()
	
	var basin: StorageUnit = engine.context.units_dict[&"BASIN"]
	var valve: SimValve = engine.context.actuators_dict[&"VALVE_OUT_BASIN"]
	var lc: SimController = engine.context.controllers_dict[&"LC_BASIN"]
	
	# Set valves to instant mode for simplicity in this test
	valve.instant_mode = true
	valve.set_commanded_position(50.0)
	
	# Set controller settings via commands
	engine.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", 5.0))
	engine.enqueue(SetControllerModeCommand.new(&"LC_BASIN", &"AUTO"))
	
	# Initial conditions: basin level = 4.0m
	basin.volume_m3 = 400.0
	basin.update_level()
	
	# Tick 1: commands execute and controller evaluates
	# valve starts at 50.0, so bumpless transfer initializes previous_output = 50.0
	# error = 5.0 - 4.0 = 1.0 (positive error)
	# output = 50.0 + 2.0 * 1.0 = 52.0
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	assert_eq(lc.control_mode, &"AUTO")
	assert_eq(valve.commanded_position, 52.0)
	assert_false(valve.is_manual)
	
	# Tick 2: change level to 6.0m
	# error = 5.0 - 6.0 = -1.0
	# output = 52.0 + 2.0 * -1.0 = 50.0
	basin.volume_m3 = 600.0
	basin.update_level()
	engine.mass_balance_tracker.is_initialized = false
	
	engine.clock.tick_count = 2
	engine.context.current_tick = 2
	engine.run_tick(1.0)
	
	assert_eq(valve.commanded_position, 50.0)
	
	# Tick 3: change level to 5.02m (error = -0.02, within deadband of 0.05)
	# output should remain 50.0
	basin.volume_m3 = 502.0
	basin.update_level()
	engine.mass_balance_tracker.is_initialized = false
	
	engine.clock.tick_count = 3
	engine.context.current_tick = 3
	engine.run_tick(1.0)
	
	assert_eq(valve.commanded_position, 50.0)

func test_manual_override() -> void:
	var engine: SimulationEngine = _setup_engine()
	
	var valve: SimValve = engine.context.actuators_dict[&"VALVE_OUT_BASIN"]
	var lc: SimController = engine.context.controllers_dict[&"LC_BASIN"]
	
	valve.instant_mode = true
	valve.set_commanded_position(50.0)
	
	# Puts controller in MANUAL mode
	engine.enqueue(SetControllerModeCommand.new(&"LC_BASIN", &"MANUAL"))
	
	# Send manual valve control command
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_BASIN", 75.0))
	
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	assert_eq(lc.control_mode, &"MANUAL")
	assert_true(valve.is_manual)
	assert_eq(valve.commanded_position, 75.0)
	
	# Run another tick, verify controller doesn't override manual setting
	engine.clock.tick_count = 2
	engine.context.current_tick = 2
	engine.run_tick(1.0)
	
	assert_eq(valve.commanded_position, 75.0)

func test_bumpless_transfer() -> void:
	var engine: SimulationEngine = _setup_engine()
	
	var basin: StorageUnit = engine.context.units_dict[&"BASIN"]
	var valve: SimValve = engine.context.actuators_dict[&"VALVE_OUT_BASIN"]
	var lc: SimController = engine.context.controllers_dict[&"LC_BASIN"]
	
	valve.instant_mode = true
	
	# Controller starts in MANUAL
	lc.control_mode = &"MANUAL"
	valve.set_commanded_position(75.0)
	
	# Run a tick in manual to ensure previous_output tracks the valve position
	engine.clock.tick_count = 1
	engine.context.current_tick = 1
	engine.run_tick(1.0)
	
	assert_eq(lc.previous_output, 75.0)
	
	# Switch to AUTO
	engine.enqueue(SetControllerModeCommand.new(&"LC_BASIN", &"AUTO"))
	engine.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", 5.0))
	
	# Basin level = 4.0m (error = 1.0)
	basin.volume_m3 = 400.0
	basin.update_level()
	engine.mass_balance_tracker.is_initialized = false
	
	# Run tick where transfer takes effect
	# output = 75.0 (initialised from current valve pos) + 2.0 * 1.0 = 77.0
	engine.clock.tick_count = 2
	engine.context.current_tick = 2
	engine.run_tick(1.0)
	
	assert_eq(lc.control_mode, &"AUTO")
	assert_eq(valve.commanded_position, 77.0, "Should transition smoothly from 75.0 without jump")
