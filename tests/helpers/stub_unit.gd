class_name StubUnit
extends RefCounted

var unit_id: StringName
var counter: int = 0
var lifecycle_log: Array[String] = []

func _init(p_id: StringName) -> void:
	unit_id = p_id

func apply_changes(_context: RefCounted) -> void:
	lifecycle_log.append("apply_changes")
	counter += 1

func update_actuators(_context: RefCounted) -> void:
	lifecycle_log.append("update_actuators")
	counter += 2

func evaluate_controllers(_context: RefCounted) -> void:
	lifecycle_log.append("evaluate_controllers")
	counter += 3

func solve_tick(_context: RefCounted) -> void:
	lifecycle_log.append("solve_tick")
	counter += 4

func post_tick(_context: RefCounted) -> void:
	lifecycle_log.append("post_tick")
	counter += 5
