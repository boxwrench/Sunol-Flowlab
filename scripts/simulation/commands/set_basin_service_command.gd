class_name SetBasinServiceCommand
extends SimulationCommand

var target_unit_id: StringName
var put_in_service: bool

func _init(p_target_unit_id: StringName = &"", p_put_in_service: bool = true, p_apply_tick: int = 0) -> void:
	target_unit_id = p_target_unit_id
	put_in_service = p_put_in_service
	apply_tick = p_apply_tick

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	if not context.units_dict.has(target_unit_id):
		errors.append("SetBasinServiceCommand: target_unit_id '%s' not found" % target_unit_id)
	else:
		var unit = context.units_dict[target_unit_id]
		if not unit is StorageUnit:
			errors.append("SetBasinServiceCommand: target_unit_id '%s' must resolve to a StorageUnit" % target_unit_id)
	return errors

func execute(context: RefCounted) -> void:
	var unit: StorageUnit = context.units_dict.get(target_unit_id) as StorageUnit
	assert(unit != null, "SetBasinServiceCommand: resolved unit cannot be null")
	
	unit.set_in_service(put_in_service)
