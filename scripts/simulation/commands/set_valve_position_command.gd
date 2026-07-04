class_name SetValvePositionCommand
extends SimulationCommand

var actuator_id: StringName
var target_position: float

func _init(p_actuator_id: StringName = &"", p_pos: float = 0.0, p_apply_tick: int = 0) -> void:
	actuator_id = p_actuator_id
	target_position = p_pos
	apply_tick = p_apply_tick

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if not context.actuators_dict.has(actuator_id):
		errors.append("SetValvePositionCommand: unknown actuator_id '%s'" % actuator_id)
	if target_position < 0.0 or target_position > 100.0:
		errors.append("SetValvePositionCommand: position must be in [0, 100], but was %f" % target_position)
	return errors

func execute(context: RefCounted) -> void:
	var valve: SimValve = context.actuators_dict.get(actuator_id)
	if valve != null:
		valve.set_commanded_position(target_position)
