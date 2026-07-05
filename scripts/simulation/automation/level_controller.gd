class_name LevelController
extends SimController

var setpoint: float = 0.0
var _unknown_mode_warned: bool = false
var kp: float = 0.0
var kd: float = 0.0
var previous_error: float = 0.0
var previous_error2: float = 0.0
var bumpless_transfer: bool = false
var _was_controlling: bool = false

func initialize(config: Dictionary) -> void:
	super.initialize(config)
	setpoint = float(config.get("setpoint", 0.0))
	kp = float(config.get("kp", 0.0))
	kd = float(config.get("kd", 0.0))
	bumpless_transfer = bool(config.get("bumpless_transfer", false))
	previous_error = 0.0
	previous_error2 = 0.0
	_was_controlling = false

func evaluate(context: RefCounted) -> void:
	var actuator: SimValve = context.actuators_dict.get(target_actuator_id)
	var pv_unit = context.units_dict.get(pv_unit_id)
	if actuator == null or pv_unit == null:
		return
		
	var pv_value: float = float(pv_unit.get(pv_property))
	var error: float = setpoint - pv_value

	if control_mode != &"AUTO" or not pv_unit.in_service:
		if control_mode != &"MANUAL" and control_mode != &"AUTO":
			if not _unknown_mode_warned:
				push_warning("LevelController '%s': unknown control_mode '%s' — fallback to MANUAL." % [controller_id, control_mode])
				_unknown_mode_warned = true
		actuator.is_manual = true
		previous_output = actuator.commanded_position
		_was_controlling = false
		if bumpless_transfer:
			previous_error = error
			previous_error2 = error
		return
		
	actuator.is_manual = false
	
	if not _was_controlling:
		if bumpless_transfer:
			previous_output = actuator.commanded_position
			previous_error = error
			previous_error2 = error
		_was_controlling = true
		
	var output: float = previous_output
	if abs(error) > deadband_m:
		var d_out: float = gain * error \
						 + kp * (error - previous_error) \
						 + kd * (error - 2.0 * previous_error + previous_error2)
		output = previous_output + d_out
		
	output = clamp(output, min_output, max_output)
	actuator.set_commanded_position(output)

	previous_error2 = previous_error
	previous_error = error
	previous_output = output

func get_snapshot() -> Dictionary:
	var snap: Dictionary = super.get_snapshot()
	snap["setpoint"] = setpoint
	snap["kp"] = kp
	snap["kd"] = kd
	snap["bumpless_transfer"] = bumpless_transfer
	snap["previous_error"] = previous_error
	snap["previous_error2"] = previous_error2
	return snap


