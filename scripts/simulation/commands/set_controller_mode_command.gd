class_name SetControllerModeCommand
extends SimulationCommand

var controller_id: StringName
var mode: StringName

func _init(p_controller_id: StringName = &"", p_mode: StringName = &"MANUAL", p_apply_tick: int = 0) -> void:
	controller_id = p_controller_id
	mode = p_mode
	apply_tick = p_apply_tick

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if not context.controllers_dict.has(controller_id):
		errors.append("SetControllerModeCommand: unknown controller_id '%s'" % controller_id)
	if mode != &"MANUAL" and mode != &"AUTO":
		errors.append("SetControllerModeCommand: mode must be 'MANUAL' or 'AUTO', but was '%s'" % mode)
	return errors

func execute(context: RefCounted) -> void:
	var controller: SimController = context.controllers_dict.get(controller_id)
	if controller != null:
		if controller.control_mode == &"MANUAL" and mode == &"AUTO":
			var actuator: SimValve = context.actuators_dict.get(controller.target_actuator_id)
			if actuator != null:
				controller.previous_output = actuator.commanded_position
		controller.control_mode = mode
