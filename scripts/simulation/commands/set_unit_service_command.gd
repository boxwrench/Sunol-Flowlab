class_name SetUnitServiceCommand
extends SetBasinServiceCommand

# Legacy alias retained for compatibility. SetBasinServiceCommand is the single
# service-command implementation and the documented operator-facing command.
var unit_id: StringName:
	get:
		return target_unit_id
	set(value):
		target_unit_id = value

var in_service: bool:
	get:
		return put_in_service
	set(value):
		put_in_service = value

func _init(p_unit_id: StringName = &"", p_in_service: bool = true, p_apply_tick: int = 0) -> void:
	super(p_unit_id, p_in_service, p_apply_tick)
