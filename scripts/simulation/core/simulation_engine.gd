class_name SimulationEngine
extends RefCounted

var clock: SimulationClock
var context: SimulationContext
var command_queue: Array[SimulationCommand] = []
var mass_balance_tracker: MassBalanceTracker = null
var alarm_engine: AlarmEngine = null

func _init() -> void:
	clock = SimulationClock.new()
	context = SimulationContext.new()
	context.dt = clock.dt_s
	mass_balance_tracker = MassBalanceTracker.new()
	alarm_engine = AlarmEngine.new()

func enqueue(cmd: SimulationCommand) -> void:
	if cmd.apply_tick <= context.current_tick:
		cmd.apply_tick = context.current_tick + 1
	command_queue.append(cmd)
	command_queue.sort_custom(func(a: SimulationCommand, b: SimulationCommand) -> bool:
		return a.apply_tick < b.apply_tick
	)

func advance_frame(frame_delta_s: float) -> Array[SimulationEvent]:
	var all_events: Array[SimulationEvent] = []
	var _ticks: int = clock.advance(frame_delta_s, func(dt: float) -> void:
		context.dt = dt
		context.current_tick = clock.tick_count
		run_tick(dt)
		all_events.append_array(flush_events())
	)
	return all_events

func run_tick(dt: float) -> void:
	_step_receive_commands()
	_step_apply_changes()
	_step_update_actuators()
	_step_evaluate_controllers()
	_step_resolve_requested_flows()
	_step_apply_constraints()
	_step_transfer_water()
	_step_update_volumes()
	_step_calculate_levels_spills()
	_step_update_state_machines()
	_step_evaluate_alarms()
	_step_record_telemetry()
	_step_validate_invariants()
	_step_publish_snapshot()

func flush_events() -> Array[SimulationEvent]:
	var events: Array[SimulationEvent] = []
	events.append_array(context.pending_events)
	context.pending_events.clear()
	return events

func _step_receive_commands() -> void:
	var current_tick: int = context.current_tick
	var remaining_commands: Array[SimulationCommand] = []
	for cmd in command_queue:
		if cmd.apply_tick == current_tick:
			var validation_errors: Array[String] = cmd.validate(context)
			if validation_errors.is_empty():
				cmd.execute(context)
			else:
				push_warning("Command failed validation: " + str(validation_errors))
		elif cmd.apply_tick > current_tick:
			remaining_commands.append(cmd)
	command_queue = remaining_commands

func _step_apply_changes() -> void:
	# Unit loops must iterate alphabetically by ID
	for unit in context.units_list:
		if unit.has_method("apply_changes"):
			unit.apply_changes(context)

func _step_update_actuators() -> void:
	# Update position of valves / actuators
	for unit in context.units_list:
		if unit.has_method("update_actuators"):
			unit.update_actuators(context)

func _step_evaluate_controllers() -> void:
	for unit in context.units_list:
		if unit.has_method("evaluate_controllers"):
			unit.evaluate_controllers(context)

func _step_resolve_requested_flows() -> void:
	for link in context.links_list:
		link.calculate_requested_flow()

func _step_apply_constraints() -> void:
	for link in context.links_list:
		link.granted_flow_m3s = link.requested_flow_m3s
		link.actual_flow_m3s = link.granted_flow_m3s

func _step_transfer_water() -> void:
	pass

func _step_update_volumes() -> void:
	# Domain classes loop over explicitly ordered units
	for unit in context.units_list:
		if unit.has_method("solve_tick"):
			unit.solve_tick(context)

func _step_calculate_levels_spills() -> void:
	pass

func _step_update_state_machines() -> void:
	for unit in context.units_list:
		if unit.has_method("post_tick"):
			unit.post_tick(context)

func _step_evaluate_alarms() -> void:
	if alarm_engine != null:
		alarm_engine.evaluate_alarms(context)

func _step_record_telemetry() -> void:
	pass

func _step_validate_invariants() -> void:
	if mass_balance_tracker != null:
		mass_balance_tracker.validate(context)

func _step_publish_snapshot() -> void:
	pass
