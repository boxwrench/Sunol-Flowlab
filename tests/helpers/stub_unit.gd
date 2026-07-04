class_name StubUnit
extends ProcessUnit

var counter: int = 0
var lifecycle_log: Array[String] = []

func _init(p_id: StringName) -> void:
	unit_id = p_id

func pre_tick(_context: RefCounted) -> void:
	lifecycle_log.append("pre_tick")
	counter += 1

func solve_tick(_context: RefCounted) -> void:
	lifecycle_log.append("solve_tick")
	counter += 4

func post_tick(_context: RefCounted) -> void:
	lifecycle_log.append("post_tick")
	counter += 5
