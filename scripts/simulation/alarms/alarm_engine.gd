class_name AlarmEngine
extends RefCounted

var alarms_list: Array = []
var alarms_dict: Dictionary = {}

func register_alarm(alarm: RefCounted) -> void:
	alarms_list.append(alarm)
	alarms_dict[alarm.alarm_id] = alarm
	alarms_list.sort_custom(func(a, b) -> bool:
		return String(a.alarm_id) < String(b.alarm_id)
	)

func evaluate_alarms(context: RefCounted) -> void:
	var dt: float = context.dt
	for alarm in alarms_list:
		var target_unit = context.units_dict.get(alarm.target_unit_id)
		if target_unit != null:
			var val = target_unit.get(alarm.target_property)
			if val != null:
				alarm.evaluate(float(val), dt, context)
