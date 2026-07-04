extends "res://addons/gut/test.gd"

class TestEngine extends SimulationEngine:
	var step_history: Array[String] = []
	
	func _step_receive_commands() -> void:
		step_history.append("1.receive_commands")
		super._step_receive_commands()
		
	func _step_apply_changes() -> void:
		step_history.append("2.apply_changes")
		super._step_apply_changes()
		
	func _step_update_actuators() -> void:
		step_history.append("3.update_actuators")
		super._step_update_actuators()
		
	func _step_evaluate_controllers() -> void:
		step_history.append("4.evaluate_controllers")
		super._step_evaluate_controllers()
		
	func _step_resolve_requested_flows() -> void:
		step_history.append("5.resolve_requested_flows")
		super._step_resolve_requested_flows()
		
	func _step_apply_constraints() -> void:
		step_history.append("6.apply_constraints")
		super._step_apply_constraints()
		
	func _step_transfer_water() -> void:
		step_history.append("7.transfer_water")
		super._step_transfer_water()
		
	func _step_update_volumes() -> void:
		step_history.append("8.update_volumes")
		super._step_update_volumes()
		
	func _step_calculate_levels_spills() -> void:
		step_history.append("9.calculate_levels_spills")
		super._step_calculate_levels_spills()
		
	func _step_update_state_machines() -> void:
		step_history.append("10.update_state_machines")
		super._step_update_state_machines()
		
	func _step_evaluate_alarms() -> void:
		step_history.append("11.evaluate_alarms")
		super._step_evaluate_alarms()
		
	func _step_record_telemetry() -> void:
		step_history.append("12.record_telemetry")
		super._step_record_telemetry()
		
	func _step_validate_invariants() -> void:
		step_history.append("13.validate_invariants")
		super._step_validate_invariants()
		
	func _step_publish_snapshot() -> void:
		step_history.append("14.publish_snapshot")
		super._step_publish_snapshot()

func test_engine_14_step_tick_order() -> void:
	var engine: TestEngine = TestEngine.new()
	var stub: StubUnit = StubUnit.new(&"UNIT_A")
	engine.context.units_list.append(stub)
	engine.context.units_dict[&"UNIT_A"] = stub
	
	engine.run_tick(1.0)
	
	var expected_steps: Array[String] = [
		"1.receive_commands",
		"2.apply_changes",
		"3.update_actuators",
		"4.evaluate_controllers",
		"5.resolve_requested_flows",
		"6.apply_constraints",
		"7.transfer_water",
		"8.update_volumes",
		"9.calculate_levels_spills",
		"10.update_state_machines",
		"11.evaluate_alarms",
		"12.record_telemetry",
		"13.validate_invariants",
		"14.publish_snapshot"
	]
	
	assert_eq(engine.step_history, expected_steps, "Engine steps must execute in the canonical 14-step order")
	
	var expected_unit_log: Array[String] = [
		"pre_tick",
		"solve_tick",
		"post_tick"
	]
	assert_eq(stub.lifecycle_log, expected_unit_log, "Unit lifecycle steps must be called in order")
