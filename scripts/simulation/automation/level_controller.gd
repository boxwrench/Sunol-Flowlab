class_name LevelController
extends SimController

var setpoint: float = 0.0

func initialize(config: Dictionary) -> void:
	super.initialize(config)
	setpoint = float(config.get("setpoint", 0.0))

func evaluate(context: RefCounted) -> void:
	var actuator: SimValve = context.actuators_dict.get(target_actuator_id)
	var pv_unit = context.units_dict.get(pv_unit_id)
	if actuator == null or pv_unit == null:
		return
		
	if control_mode == &"MANUAL":
		actuator.is_manual = true
		previous_output = actuator.commanded_position
		return
		
	actuator.is_manual = false
	
	var pv_value: float = float(pv_unit.get(pv_property))
	var error: float = setpoint - pv_value
	
	var output: float = previous_output
	if abs(error) > deadband_m:
		output = previous_output + gain * error
		
	output = clamp(output, min_output, max_output)
	actuator.set_commanded_position(output)
	previous_output = output

func get_snapshot() -> Dictionary:
	var snap: Dictionary = super.get_snapshot()
	snap["setpoint"] = setpoint
	return snap
