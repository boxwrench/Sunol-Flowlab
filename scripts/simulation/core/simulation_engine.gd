class_name SimulationEngine
extends RefCounted

var clock: SimulationClock
var context: SimulationContext
var command_queue: Array[SimulationCommand] = []
var mass_balance_tracker: MassBalanceTracker = null
var alarm_engine: AlarmEngine = null
var latest_snapshot: Dictionary = {}
var previous_snapshot_hash: int = 0

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
	for unit in context.units_list:
		unit.pre_tick(context)

func _step_update_actuators() -> void:
	var dt: float = context.dt
	for actuator in context.actuators_list:
		actuator.update(dt)

func _step_evaluate_controllers() -> void:
	for controller in context.controllers_list:
		controller.evaluate(context)

func _step_resolve_requested_flows() -> void:
	FlowSolver.solve_flows(context)

func _step_apply_constraints() -> void:
	# Guardrail 4: constraint work (link is_enabled, valve closure) is enforced
	# inside step 5's FlowSolver.solve_flows() call via calculate_requested_flow()
	# and the disabled-link zeroing path. No additional work here in Phase 2.
	# Future phases may add interlock logic here (named WP TBD).
	pass

func _step_transfer_water() -> void:
	# Guardrail 4: water transfer is effected by StorageUnit.solve_tick() in
	# step 8 (_step_update_volumes), which reads actual_flow_m3s written by
	# FlowSolver's final sweep. No separate transfer step is needed in Phase 2.
	# Future phases may move spill routing here (named WP TBD).
	pass

func _step_update_volumes() -> void:
	for unit in context.units_list:
		unit.solve_tick(context)

func _step_calculate_levels_spills() -> void:
	# Reset all boundary flow accumulators to zero before summing (Edge Rule 4)
	for unit in context.units_list:
		if unit is ExternalBoundary:
			unit.current_flow_m3s = 0.0

	# Accumulate actual flows across all links using += so multi-link
	# boundaries sum correctly (Edge Rule 4)
	for link in context.links_list:
		if link.source_port != null and link.source_port.parent_unit is ExternalBoundary:
			link.source_port.parent_unit.current_flow_m3s += link.actual_flow_m3s
		if link.destination_port != null and link.destination_port.parent_unit is ExternalBoundary:
			link.destination_port.parent_unit.current_flow_m3s += link.actual_flow_m3s

	# F2.2-3: replace the silent clamp with a debug assert (guardrail 9).
	# The FlowSolver has already prorated individual links; any residual
	# that exceeds flow_limit_m3s here means the solver had a grant leak.
	# A clamp would mask the error; an assert makes it loud.
	for unit in context.units_list:
		if unit is ExternalBoundary and unit.flow_limit_m3s >= 0.0:
			assert(
				unit.current_flow_m3s <= unit.flow_limit_m3s + 1e-9,
				"_step_calculate_levels_spills: boundary '%s' accumulated flow (%f) exceeds limit (%f) — solver grant leak." \
				% [unit.unit_id, unit.current_flow_m3s, unit.flow_limit_m3s]
			)

	# Route spill from each StorageUnit to its configured spill boundary (Edge Rule 5).
	# spill_destination_id must resolve to a unit in units_dict; if it doesn't
	# (e.g. config missing or validator skipped) we emit a warning and skip.
	for unit in context.units_list:
		if not (unit is StorageUnit):
			continue
		if unit.spill_flow_m3s <= 0.0:
			continue
		var dest_id: StringName = unit.spill_destination_id
		if dest_id == &"":
			push_warning(
				"StorageUnit '%s': spill_destination_id is empty — spill of %f m³/s not routed." \
				% [unit.unit_id, unit.spill_flow_m3s]
			)
			continue
		var dest = context.units_dict.get(dest_id)
		if dest == null or not (dest is ExternalBoundary):
			push_warning(
				"StorageUnit '%s': spill_destination_id '%s' does not resolve to an ExternalBoundary — spill not routed." \
				% [unit.unit_id, dest_id]
			)
			continue
		dest.current_flow_m3s += unit.spill_flow_m3s


func _step_update_state_machines() -> void:
	for unit in context.units_list:
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
	if not latest_snapshot.is_empty():
		assert(str(latest_snapshot).hash() == previous_snapshot_hash, "Mutation Violation: Snapshot was mutated externally!")
	latest_snapshot = SnapshotService.take_snapshot(context, self)
	previous_snapshot_hash = str(latest_snapshot).hash()
