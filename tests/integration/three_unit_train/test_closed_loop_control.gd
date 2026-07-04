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

func test_closed_loop_level_stabilization() -> void:
	var engine := _setup_engine()
	
	var src_res: StorageUnit = engine.context.units_dict[&"SOURCE_RESERVOIR"]
	var basin: StorageUnit = engine.context.units_dict[&"BASIN"]
	var rcv_res: StorageUnit = engine.context.units_dict[&"RECEIVING_RESERVOIR"]
	
	var valve_in: SimValve = engine.context.actuators_dict[&"VALVE_IN"]
	var valve_out_src: SimValve = engine.context.actuators_dict[&"VALVE_OUT_SRC"]
	var valve_out_basin: SimValve = engine.context.actuators_dict[&"VALVE_OUT_BASIN"]
	var valve_out_rcv: SimValve = engine.context.actuators_dict[&"VALVE_OUT_RCV"]
	var lc: SimController = engine.context.controllers_dict[&"LC_BASIN"]
	
	# Configure valves: gradual travel for source valve, instant for others
	for act in engine.context.actuators_list:
		act.instant_mode = true
	valve_out_src.instant_mode = false # gradual travel on the control valve
	
	# Stabilizing configuration:
	# Let the level controller regulate the INFLOW to the Basin (VALVE_OUT_SRC)
	lc.target_actuator_id = &"VALVE_OUT_SRC"
	lc.gain = 2.0 # Shipped-scale gain
	lc.deadband_m = 0.01
	
	# Keep reservoir levels replenished
	valve_in.set_commanded_position(100.0)
	valve_in.position = 100.0
	
	# Set downstream valves to constant positions
	valve_out_basin.set_commanded_position(50.0)
	valve_out_basin.position = 50.0
	valve_out_rcv.set_commanded_position(50.0)
	valve_out_rcv.position = 50.0
	
	# Set source reservoir volume high
	src_res.volume_m3 = 800.0
	src_res.update_level()
	
	# Set setpoint and put controller in AUTO
	engine.enqueue(SetLevelSetpointCommand.new(&"LC_BASIN", 5.0))
	engine.enqueue(SetControllerModeCommand.new(&"LC_BASIN", &"AUTO"))
	
	# Initial conditions: Basin starts at setpoint
	basin.volume_m3 = 500.0 # level = 5.0m
	basin.update_level()
	
	# Initialize control valve position to match steady state
	valve_out_src.set_commanded_position(37.5) # 37.5% of 8.0 = 3.0 m3s, matches 50% of 6.0 m3s
	valve_out_src.position = 37.5
	lc.previous_output = 37.5
	
	engine.mass_balance_tracker.is_initialized = false
	
	# Run 200 ticks to settle
	for tick in range(1, 201):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Level should be stable near setpoint (5.0m)
	assert_almost_eq(basin.level_m, 5.0, 0.05, "Level should settle near 5.0m setpoint")
	
	# Now introduce a small sustained disturbance: increase downstream demand
	# by opening VALVE_OUT_BASIN to 52% (shipped-scale droop test)
	valve_out_basin.set_commanded_position(52.0)
	valve_out_basin.position = 52.0
	
	# Run 200 ticks for the controller to adapt and level to re-stabilize.
	# Collect level measurements over the final 50 ticks to compute a time average.
	var final_levels: Array[float] = []
	for tick in range(201, 401):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		if tick >= 350:
			final_levels.append(basin.level_m)
			
	var sum_levels: float = 0.0
	for lvl in final_levels:
		sum_levels += lvl
	var avg_level: float = sum_levels / final_levels.size()
	
	# With gain=2.0, required valve increase is 1.5% (from 37.5% to 39.0%).
	# required_error = 1.5% / 2.0 = 0.75m. Expected level = 5.0m - 0.75m = 4.25m.
	assert_almost_eq(avg_level, 4.25, 0.05, "Time-averaged level over final 50-tick window should stabilize near 4.25m")


