class_name SimulationCommand
extends RefCounted

var command_id: StringName
var issued_tick: int = 0
var apply_tick: int = 0

func execute(context: RefCounted) -> void:
	pass

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	return errors
