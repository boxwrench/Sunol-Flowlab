class_name SimulationEvent
extends RefCounted

var event_type: StringName
var tick: int = 0
var payload: Dictionary = {}

func _init(p_event_type: StringName = &"", p_tick: int = 0, p_payload: Dictionary = {}) -> void:
	event_type = p_event_type
	tick = p_tick
	payload = p_payload
