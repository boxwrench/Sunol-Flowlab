class_name SimValve
extends RefCounted

var actuator_id: StringName
var display_name: String = ""

# State
var is_manual: bool = true
var commanded_position: float = 0.0 # 0% - 100%
var position: float = 0.0            # 0% - 100%

# Configuration
var opening_rate_percent_per_s: float = 10.0
var closing_rate_percent_per_s: float = 10.0
var fail_state: StringName = &"LAST_POSITION" # OPEN, CLOSED, LAST_POSITION

# Debug mode for instant changes
var instant_mode: bool = false

func _init(p_id: StringName = &"") -> void:
	actuator_id = p_id

func initialize(config: Dictionary) -> void:
	actuator_id = StringName(config.get("actuator_id", actuator_id))
	display_name = config.get("display_name", display_name)
	is_manual = config.get("is_manual", is_manual)
	position = float(config.get("initial_position", position))
	commanded_position = float(config.get("commanded_position", position))
	
	opening_rate_percent_per_s = float(config.get("opening_rate_percent_per_s", 10.0))
	closing_rate_percent_per_s = float(config.get("closing_rate_percent_per_s", 10.0))
	fail_state = StringName(config.get("fail_state", "LAST_POSITION"))
	instant_mode = bool(config.get("instant_mode", false))
	
	if instant_mode:
		position = commanded_position

func set_manual(p_manual: bool) -> void:
	is_manual = p_manual

func set_commanded_position(pos: float) -> void:
	commanded_position = clamp(pos, 0.0, 100.0)
	if instant_mode:
		position = commanded_position

func update(dt: float) -> void:
	if instant_mode:
		position = commanded_position
		return
		
	if position < commanded_position:
		var step: float = opening_rate_percent_per_s * dt
		position = min(commanded_position, position + step)
	elif position > commanded_position:
		var step: float = closing_rate_percent_per_s * dt
		position = max(commanded_position, position - step)

func get_effective_opening() -> float:
	return position / 100.0

func get_snapshot() -> Dictionary:
	return {
		"actuator_id": actuator_id,
		"display_name": display_name,
		"is_manual": is_manual,
		"commanded_position": commanded_position,
		"position": position,
		"effective_opening": get_effective_opening()
	}
