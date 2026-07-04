class_name SetLevelSetpointCommand
extends SimulationCommand

var controller_id: StringName
var setpoint: float

func _init(p_controller_id: StringName = &"", p_setpoint: float = 0.0, p_apply_tick: int = 0) -> void:
	controller_id = p_controller_id
	setpoint = p_setpoint
	apply_tick = p_apply_tick

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if not context.controllers_dict.has(controller_id):
		errors.append("SetLevelSetpointCommand: unknown controller_id '%s'" % controller_id)
	return errors

func execute(context: RefCounted) -> void:
	var controller: SimController = context.controllers_dict.get(controller_id)
	if controller != null and controller.has_method("set_setpoint"):
		controller.set_setpoint(setpoint)
	elif controller != null and "setpoint" in controller:
		controller.setpoint = setpoint
