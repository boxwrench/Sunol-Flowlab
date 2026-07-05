@tool
class_name PresentationMapEditor
extends Node3D

const PresentationMapHandler = preload("res://scripts/tools/presentation_map_handler.gd")

@export_file("*.json") var presentation_map_path: String = "res://config/plants/phase3_headworks/presentation_map.json"

@export var load_and_rebuild: bool = false:
	set(val):
		if val:
			rebuild_markers()

@export var export_now: bool = false:
	set(val):
		if val:
			export_map()

func rebuild_markers() -> void:
	if not Engine.is_editor_hint():
		return
		
	# Clear existing children
	for child in get_children():
		child.queue_free()

	var map_data := PresentationMapHandler.load_map(presentation_map_path)
	if map_data.is_empty():
		push_error("PresentationMapEditor: Failed to load presentation map at %s" % presentation_map_path)
		return

	var edited_root = get_tree().edited_scene_root
	if edited_root == null:
		push_warning("PresentationMapEditor: edited_scene_root is null, markers might not be selectable in editor tree")

	var units: Array = map_data.get("units", [])
	for unit in units:
		if not unit is Dictionary:
			continue
		var unit_id: String = unit.get("unit_id", "")
		if unit_id == "":
			continue
		var pos_arr: Array = unit.get("position_m", [0.0, 0.0, 0.0])
		var rot_arr: Array = unit.get("rotation_deg", [0.0, 0.0, 0.0])

		# Create a visual marker
		var marker := MeshInstance3D.new()
		marker.name = unit_id
		add_child(marker)
		
		if edited_root != null:
			marker.owner = edited_root

		# Add visual representation
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		marker.mesh = sphere

		# Add visual material to make it distinct
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.8, 0.4, 0.8) # Distinct green color
		mat.roughness = 0.5
		marker.set_surface_override_material(0, mat)

		var label := Label3D.new()
		label.text = unit_id
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 1.5, 0.0)
		marker.add_child(label)
		
		if edited_root != null:
			label.owner = edited_root

		# Set position and rotation
		marker.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		marker.rotation_degrees = Vector3(float(rot_arr[0]), float(rot_arr[1]), float(rot_arr[2]))
		
	print("PresentationMapEditor: Rebuilt markers for %d units." % units.size())

func export_map() -> void:
	if not Engine.is_editor_hint():
		return

	var map_data := PresentationMapHandler.load_map(presentation_map_path)
	if map_data.is_empty():
		push_error("PresentationMapEditor: Failed to load map data to export from %s" % presentation_map_path)
		return

	var placements := {}
	for child in get_children():
		if child is Node3D:
			var unit_id = child.name
			placements[unit_id] = {
				"position_m": [child.position.x, child.position.y, child.position.z],
				"rotation_deg": [child.rotation_degrees.x, child.rotation_degrees.y, child.rotation_degrees.z]
			}

	# Merge and save
	map_data = PresentationMapHandler.update_units(map_data, placements)
	var success := PresentationMapHandler.save_map(presentation_map_path, map_data)
	if success:
		print("PresentationMapEditor: Exported updated placements to %s" % presentation_map_path)
	else:
		push_error("PresentationMapEditor: Failed to save updated placements to %s" % presentation_map_path)
