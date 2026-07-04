class_name StorageVisualAdapter
extends Node3D

@export var unit_id: StringName = &""

@onready var water_surface: Node3D = get_node_or_null("WaterSurface")
@onready var alarm_indicator: Light3D = get_node_or_null("AlarmIndicator")

func _process(_delta: float) -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
		
	var snap: Dictionary = host.engine.latest_snapshot
	if snap.is_empty() or not snap.units.has(unit_id):
		return
		
	var unit_snap: Dictionary = snap.units[unit_id]
	
	if water_surface != null:
		var level: float = float(unit_snap.get("level_m", 0.0))
		water_surface.position.y = level
		
	if alarm_indicator != null:
		var is_alarm_active: bool = false
		for alarm_id in snap.alarms:
			var alarm_snap: Dictionary = snap.alarms[alarm_id]
			if alarm_snap.get("target_unit_id") == unit_id and alarm_snap.get("is_active", false):
				is_alarm_active = true
				break
		alarm_indicator.visible = is_alarm_active
