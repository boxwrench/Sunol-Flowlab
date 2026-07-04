class_name ProcessUnit
extends RefCounted

var unit_id: StringName
var display_name: String = ""
var type: String = ""
var in_service: bool = true
var operating_state: StringName = &"IN_SERVICE"

func initialize(config: Dictionary) -> void:
	unit_id = StringName(config.get("unit_id", ""))
	display_name = config.get("display_name", "")
	type = config.get("type", "")
	in_service = config.get("in_service", true)
	operating_state = StringName(config.get("operating_state", "IN_SERVICE"))

func pre_tick(_context: RefCounted) -> void:
	pass

func solve_tick(_context: RefCounted) -> void:
	pass

func post_tick(_context: RefCounted) -> void:
	pass

func get_snapshot() -> Dictionary:
	return {
		"unit_id": unit_id,
		"display_name": display_name,
		"type": type,
		"in_service": in_service,
		"operating_state": operating_state
	}

func validate(_context: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if unit_id == &"":
		errors.append("ProcessUnit: unit_id cannot be empty")
	return errors
