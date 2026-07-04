class_name SetUnitServiceCommand
extends SimulationCommand

var unit_id: StringName
var in_service: bool

func _init(p_unit_id: StringName = &"", p_in_service: bool = true, p_apply_tick: int = 0) -> void:
	unit_id = p_unit_id
	in_service = p_in_service
	apply_tick = p_apply_tick

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if not context.units_dict.has(unit_id):
		errors.append("SetUnitServiceCommand: unknown unit_id '%s'" % unit_id)
	return errors

func execute(context: RefCounted) -> void:
	var unit: ProcessUnit = context.units_dict.get(unit_id)
	if unit != null:
		unit.in_service = in_service
