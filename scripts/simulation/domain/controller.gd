class_name SimController
extends RefCounted

var controller_id: StringName
var display_name: String = ""
var type: String = ""
var target_actuator_id: StringName
var pv_unit_id: StringName
var pv_property: String = "level_m"
var control_mode: StringName = &"MANUAL" # MANUAL, AUTO

var gain: float = 1.0
var bias: float = 0.0
var deadband_m: float = 0.0
var min_output: float = 0.0
var max_output: float = 100.0
var previous_output: float = 0.0

func initialize(config: Dictionary) -> void:
	controller_id = StringName(config.get("controller_id", ""))
	display_name = config.get("display_name", "")
	type = config.get("type", "")
	target_actuator_id = StringName(config.get("target_actuator_id", ""))
	pv_unit_id = StringName(config.get("pv_unit_id", ""))
	pv_property = config.get("pv_property", "level_m")
	control_mode = StringName(config.get("control_mode", "MANUAL"))
	
	gain = float(config.get("gain", 1.0))
	bias = float(config.get("bias", 0.0))
	deadband_m = float(config.get("deadband_m", 0.0))
	min_output = float(config.get("min_output", 0.0))
	max_output = float(config.get("max_output", 100.0))
	previous_output = 0.0

func evaluate(_context: RefCounted) -> void:
	pass

func get_snapshot() -> Dictionary:
	return {
		"controller_id": controller_id,
		"display_name": display_name,
		"type": type,
		"target_actuator_id": target_actuator_id,
		"pv_unit_id": pv_unit_id,
		"pv_property": pv_property,
		"control_mode": control_mode,
		"gain": gain,
		"bias": bias,
		"deadband_m": deadband_m,
		"min_output": min_output,
		"max_output": max_output,
		"previous_output": previous_output
	}
