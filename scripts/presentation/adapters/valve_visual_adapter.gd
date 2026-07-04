class_name ValveVisualAdapter
extends Node3D

@export var actuator_id: StringName = &""

func _process(_delta: float) -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
		
	var snap: Dictionary = host.engine.latest_snapshot
	if snap.is_empty() or not snap.actuators.has(actuator_id):
		return
		
	var act_snap: Dictionary = snap.actuators[actuator_id]
	var pos: float = float(act_snap.get("position", 0.0))
	
	# Rotate the valve visual relative to its position (0 to 90 degrees)
	rotation.y = deg_to_rad(pos * 0.9)
