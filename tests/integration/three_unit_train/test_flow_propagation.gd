extends "res://addons/gut/test.gd"

func _setup_engine() -> SimulationEngine:
	var engine: SimulationEngine = SimulationEngine.new()
	var config: Dictionary = ConfigLoader.load_plant_config("phase2_three_unit")
	assert_true(config.success, "Configuration should load successfully")
	
	var build_ok: bool = PlantFactory.build_plant(engine.context, config.topology_data, config.initial_conditions_data)
	assert_true(build_ok, "Factory build should succeed")
	
	return engine

func test_three_unit_propagation() -> void:
	var engine: SimulationEngine = _setup_engine()
	
	# Set all valve actuators to instant mode for test convenience
	for act_id in engine.context.actuators_dict:
		var actuator: SimValve = engine.context.actuators_dict[act_id]
		actuator.instant_mode = true
		
	# Command all transit valves to open
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_SRC", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_BASIN", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", 100.0))
	
	var rcv_res: StorageUnit = engine.context.units_dict[&"RECEIVING_RESERVOIR"]
	var initial_rcv_vol: float = rcv_res.volume_m3
	
	# Run 20 ticks. Flow should propagate through the entire train
	for tick in range(1, 21):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Verify that receiving reservoir volume increased
	assert_gt(rcv_res.volume_m3, initial_rcv_vol, "Receiving reservoir volume should have risen due to flow propagation")
	
	# Verify that sink flow is positive
	var sink: ExternalBoundary = engine.context.units_dict[&"EXTERNAL_SINK"]
	assert_gt(sink.current_flow_m3s, 0.0, "Sink should receive positive flow at steady state")

func test_three_unit_mass_conservation() -> void:
	var engine: SimulationEngine = _setup_engine()
	
	for act_id in engine.context.actuators_dict:
		var actuator: SimValve = engine.context.actuators_dict[act_id]
		actuator.instant_mode = true
		
	# Set valves to open to allow mixed flows
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 80.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_SRC", 60.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_BASIN", 50.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", 40.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_SRC", 10.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_BASIN", 10.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_RCV", 10.0))
	
	# Run for 1,000 ticks. The MassBalanceTracker validates mass conservation
	# on each tick and will assert fail if a violation (> tolerance) occurs.
	for tick in range(1, 1001):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Final manual verification of ledger
	var current_storage: float = 0.0
	for unit in engine.context.units_list:
		if unit is StorageUnit:
			current_storage += unit.volume_m3
			
	var report: Dictionary = engine.mass_balance_tracker.report(current_storage)
	assert_lt(abs(report.mass_balance_error_m3), 1e-8, "Final mass balance error must be within strict tolerance")

func test_three_unit_drain_to_zero() -> void:
	var engine: SimulationEngine = _setup_engine()
	
	for act_id in engine.context.actuators_dict:
		var actuator: SimValve = engine.context.actuators_dict[act_id]
		actuator.instant_mode = true
		
	# Close inlet, open all drains, close all outlet transit valves
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_SRC", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_BASIN", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", 0.0))
	
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_SRC", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_BASIN", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_RCV", 100.0))
	
	var src_res: StorageUnit = engine.context.units_dict[&"SOURCE_RESERVOIR"]
	var basin: StorageUnit = engine.context.units_dict[&"BASIN"]
	var rcv_res: StorageUnit = engine.context.units_dict[&"RECEIVING_RESERVOIR"]
	
	# Run 300 ticks to ensure full draining
	for tick in range(1, 301):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Verify all storage units are empty and did not go negative
	assert_eq(src_res.volume_m3, 0.0, "Source reservoir should drain to exactly 0.0")
	assert_eq(basin.volume_m3, 0.0, "Basin should drain to exactly 0.0")
	assert_eq(rcv_res.volume_m3, 0.0, "Receiving reservoir should drain to exactly 0.0")

func test_three_unit_outlet_cutoff() -> void:
	var engine: SimulationEngine = _setup_engine()
	
	for act_id in engine.context.actuators_dict:
		var actuator: SimValve = engine.context.actuators_dict[act_id]
		actuator.instant_mode = true
		
	# Close inlet, close all drains, open all outlet transit valves
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_IN", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_SRC", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_BASIN", 100.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_OUT_RCV", 100.0))
	
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_SRC", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_BASIN", 0.0))
	engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_RCV", 0.0))
	
	var src_res: StorageUnit = engine.context.units_dict[&"SOURCE_RESERVOIR"]
	var basin: StorageUnit = engine.context.units_dict[&"BASIN"]
	var rcv_res: StorageUnit = engine.context.units_dict[&"RECEIVING_RESERVOIR"]
	
	# Each storage unit has surface_area_m2 = 100.0 and min_operating_level_m = 0.5.
	# So min_volume = 0.5 * 100.0 = 50.0 m3.
	
	# Run 300 ticks to ensure outlets draw down to their cutoff limits
	for tick in range(1, 301):
		engine.clock.tick_count = tick
		engine.context.current_tick = tick
		engine.run_tick(1.0)
		
	# Verify all storage units hit and remained at exactly their min operating volume (50.0 m3)
	assert_almost_eq(src_res.volume_m3, 50.0, 1e-4, "Source reservoir should stop at min operating volume (50.0)")
	assert_almost_eq(basin.volume_m3, 50.0, 1e-4, "Basin should stop at min operating volume (50.0)")
	assert_almost_eq(rcv_res.volume_m3, 50.0, 1e-4, "Receiving reservoir should stop at min operating volume (50.0)")
	
	# Outflows must be 0.0 at the cutoff
	assert_eq(src_res.outflow_m3s, 0.0, "Source reservoir outlet flow should starve and stop")
	assert_eq(basin.outflow_m3s, 0.0, "Basin outlet flow should starve and stop")
	assert_eq(rcv_res.outflow_m3s, 0.0, "Receiving reservoir outlet flow should starve and stop")
