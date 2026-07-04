class_name WaterSurfaceAdapter
extends MeshInstance3D

@export var unit_id: StringName = &""

func _process(_delta: float) -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
		
	var snap: Dictionary = host.engine.latest_snapshot
	if snap.is_empty() or not snap.units.has(unit_id):
		return
		
	var unit_snap: Dictionary = snap.units[unit_id]
	var level: float = float(unit_snap.get("level_m", 0.0))
	position.y = level
