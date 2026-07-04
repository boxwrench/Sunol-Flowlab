extends "res://addons/gut/test.gd"

class DummyCommand extends SimulationCommand:
	var id: String
	var execution_order_log: Array

	func _init(p_id: String, p_log: Array) -> void:
		id = p_id
		execution_order_log = p_log

	func execute(_context: RefCounted) -> void:
		execution_order_log.append(id)

func test_command_enqueue_latencies_and_ordering() -> void:
	var engine: SimulationEngine = SimulationEngine.new()
	var execution_log: Array = []

	var cmd1: DummyCommand = DummyCommand.new("cmd1", execution_log)
	engine.enqueue(cmd1)

	assert_eq(cmd1.apply_tick, 1, "Command enqueued at tick 0 should default to execute at tick 1")

	var _events: Array[SimulationEvent] = engine.advance_frame(1.0)
	assert_eq(execution_log, ["cmd1"], "cmd1 should execute on tick 1")

	execution_log.clear()
	var cmd2: DummyCommand = DummyCommand.new("cmd2", execution_log)
	var cmd3: DummyCommand = DummyCommand.new("cmd3", execution_log)

	engine.enqueue(cmd2)
	engine.enqueue(cmd3)

	assert_eq(cmd2.apply_tick, 2, "cmd2 should be scheduled for tick 2")
	assert_eq(cmd3.apply_tick, 2, "cmd3 should be scheduled for tick 2")

	var _events2: Array[SimulationEvent] = engine.advance_frame(1.0)
	assert_eq(execution_log, ["cmd2", "cmd3"], "Same-tick commands must preserve FIFO order")
