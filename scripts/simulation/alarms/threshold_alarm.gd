class_name ThresholdAlarm
extends RefCounted

var alarm_id: StringName
var display_name: String = ""
var target_unit_id: StringName
var target_property: String = "level_m"
var alarm_type: StringName = &"HIGH" # HIGH, LOW

var threshold_value: float = 0.0
var delay_s: float = 0.0
var deadband: float = 0.0
var message: String = ""

# State
var is_active: bool = false
var violation_timer_s: float = 0.0

func initialize(config: Dictionary) -> void:
	alarm_id = StringName(config.get("alarm_id", ""))
	display_name = config.get("display_name", "")
	target_unit_id = StringName(config.get("target_unit_id", ""))
	target_property = config.get("target_property", "level_m")
	alarm_type = StringName(config.get("alarm_type", "HIGH"))
	threshold_value = float(config.get("threshold_value", 0.0))
	delay_s = float(config.get("delay_s", 0.0))
	deadband = float(config.get("deadband", 0.0))
	message = config.get("message", "")
	is_active = false
	violation_timer_s = 0.0

func evaluate(current_value: float, dt: float, context: RefCounted) -> void:
	var is_violating: bool = false
	
	if is_active:
		if alarm_type == &"HIGH":
			is_violating = (current_value > (threshold_value - deadband))
		elif alarm_type == &"LOW":
			is_violating = (current_value < (threshold_value + deadband))
	else:
		if alarm_type == &"HIGH":
			is_violating = (current_value > threshold_value)
		elif alarm_type == &"LOW":
			is_violating = (current_value < threshold_value)
			
	if is_violating:
		if not is_active:
			violation_timer_s += dt
			if violation_timer_s >= delay_s:
				is_active = true
				violation_timer_s = 0.0
				var event := SimulationEvent.new(&"AlarmActivated", context.current_tick, {
					"alarm_id": alarm_id,
					"message": message,
					"value": current_value
				})
				context.pending_events.append(event)
	else:
		violation_timer_s = 0.0
		if is_active:
			is_active = false
			var event := SimulationEvent.new(&"AlarmCleared", context.current_tick, {
				"alarm_id": alarm_id,
				"value": current_value
			})
			context.pending_events.append(event)

func get_snapshot() -> Dictionary:
	return {
		"alarm_id": alarm_id,
		"display_name": display_name,
		"target_unit_id": target_unit_id,
		"is_active": is_active,
		"message": message
	}
