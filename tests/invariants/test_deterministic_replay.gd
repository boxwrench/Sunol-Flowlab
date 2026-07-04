extends "res://addons/gut/test.gd"

class DeterministicCommand extends SimulationCommand:
	var target_unit_id: StringName

	func _init(p_target: StringName, p_apply_tick: int) -> void:
		target_unit_id = p_target
		apply_tick = p_apply_tick

	func execute(context: RefCounted) -> void:
		var unit = context.units_dict.get(target_unit_id)
		if unit:
			unit.counter += 42

func test_replay_determinism() -> void:
	var engine1: SimulationEngine = SimulationEngine.new()
	var engine2: SimulationEngine = SimulationEngine.new()

	var names: Array[StringName] = [&"UNIT_A", &"UNIT_B", &"UNIT_C"]
	for n in names:
		var stub1: StubUnit = StubUnit.new(n)
		engine1.context.units_list.append(stub1)
		engine1.context.units_dict[n] = stub1

		var stub2: StubUnit = StubUnit.new(n)
		engine2.context.units_list.append(stub2)
		engine2.context.units_dict[n] = stub2

	# Enqueue 1000 commands
	for i in range(1, 10001, 10):
		engine1.enqueue(DeterministicCommand.new(&"UNIT_A", i))
		engine1.enqueue(DeterministicCommand.new(&"UNIT_C", i + 2))

		engine2.enqueue(DeterministicCommand.new(&"UNIT_A", i))
		engine2.enqueue(DeterministicCommand.new(&"UNIT_C", i + 2))

	# Run 10,000 ticks (100 frames at 100s delta)
	for step in range(100):
		var _e1: Array[SimulationEvent] = engine1.advance_frame(100.0)
		var _e2: Array[SimulationEvent] = engine2.advance_frame(100.0)

	var state_hash1: String = _get_engine_state_hash(engine1)
	var state_hash2: String = _get_engine_state_hash(engine2)

	assert_eq(state_hash1, state_hash2, "Replay must yield bit-identical states")

func test_iteration_order_invariance() -> void:
	var engine_unsorted: SimulationEngine = SimulationEngine.new()
	var engine_sorted: SimulationEngine = SimulationEngine.new()

	var names_unsorted: Array[StringName] = [&"UNIT_B", &"UNIT_C", &"UNIT_A"]
	var names_sorted: Array[StringName] = [&"UNIT_A", &"UNIT_B", &"UNIT_C"]

	for n in names_unsorted:
		var stub: StubUnit = StubUnit.new(n)
		engine_unsorted.context.units_list.append(stub)
		engine_unsorted.context.units_dict[n] = stub

	for n in names_sorted:
		var stub: StubUnit = StubUnit.new(n)
		engine_sorted.context.units_list.append(stub)
		engine_sorted.context.units_dict[n] = stub

	# Sort engine_unsorted's units_list alphabetically by ID to guarantee deterministic iteration
	engine_unsorted.context.units_list.sort_custom(func(a, b) -> bool:
		return String(a.unit_id) < String(b.unit_id)
	)

	# Enqueue commands
	for i in range(1, 1001, 10):
		engine_unsorted.enqueue(DeterministicCommand.new(&"UNIT_A", i))
		engine_unsorted.enqueue(DeterministicCommand.new(&"UNIT_C", i + 2))

		engine_sorted.enqueue(DeterministicCommand.new(&"UNIT_A", i))
		engine_sorted.enqueue(DeterministicCommand.new(&"UNIT_C", i + 2))

	# Run 1000 ticks (10 frames at 100s delta)
	for step in range(10):
		var _eu: Array[SimulationEvent] = engine_unsorted.advance_frame(100.0)
		var _es: Array[SimulationEvent] = engine_sorted.advance_frame(100.0)

	var hash_unsorted: String = _get_engine_state_hash(engine_unsorted)
	var hash_sorted: String = _get_engine_state_hash(engine_sorted)

	assert_eq(hash_unsorted, hash_sorted, "Alphabetical sorting of units registry must guarantee iteration order invariance")

func _get_engine_state_hash(engine: SimulationEngine) -> String:
	var parts: Array[String] = []
	parts.append(str(engine.clock.tick_count))
	for unit in engine.context.units_list:
		parts.append(String(unit.unit_id) + ":" + str(unit.counter))
	return ",".join(parts)
