class_name HeadworksPresentationAdapter
extends Node3D

const UNIT_VISUAL_SCRIPT = preload("res://scripts/presentation/headworks/headworks_unit_visual.gd")
const LINK_VISUAL_SCRIPT = preload("res://scripts/presentation/headworks/headworks_link_visual.gd")

var _engine: SimulationEngine = null
var _unit_visuals: Dictionary = {}
var _link_visuals: Dictionary = {}
var _unit_definitions: Dictionary = {}
var _presentation_positions: Dictionary = {}

func configure(engine: SimulationEngine, topology_data: Dictionary, presentation_map: Dictionary) -> void:
	_engine = engine
	_clear_visuals()
	_unit_definitions.clear()
	_presentation_positions.clear()

	if presentation_map.has("reference_plane"):
		_build_reference_plane(presentation_map["reference_plane"])

	for entry in presentation_map.get("units", []):
		var unit_id: StringName = StringName(entry.get("unit_id", ""))
		if unit_id == &"":
			continue
		_presentation_positions[unit_id] = {
			"position": _array_to_vector3(entry.get("position_m", [])),
			"rotation": _array_to_vector3(entry.get("rotation_deg", [])),
			"mesh_path": String(entry.get("mesh_path", "")),
			"mesh_scale_m": entry.get("mesh_scale_m", [1.0, 1.0, 1.0])
		}

	var port_to_unit: Dictionary = {}
	for unit_config in topology_data.get("units", []):
		var unit_id: StringName = StringName(unit_config.get("unit_id", ""))
		if unit_id == &"":
			continue
		var max_level_m: float = 0.0
		if unit_config.get("type", "") == "StorageUnit":
			var surface_area_m2: float = float(unit_config.get("surface_area_m2", 0.0))
			if surface_area_m2 > 0.0:
				max_level_m = float(unit_config.get("maximum_volume_m3", 0.0)) / surface_area_m2
		_unit_definitions[unit_id] = {
			"unit_id": unit_id,
			"display_name": unit_config.get("display_name", String(unit_id)),
			"type": unit_config.get("type", ""),
			"boundary_type": unit_config.get("boundary_type", ""),
			"maximum_volume_m3": float(unit_config.get("maximum_volume_m3", 0.0)),
			"max_level_m": max_level_m
		}
		for port_config in unit_config.get("ports", []):
			port_to_unit[StringName(port_config.get("port_id", ""))] = unit_id

	for unit_id in _presentation_positions.keys():
		if not _unit_definitions.has(unit_id):
			continue
		var placement: Dictionary = _presentation_positions[unit_id]
		var unit_visual = UNIT_VISUAL_SCRIPT.new()
		unit_visual.name = "%sVisual" % String(unit_id)
		add_child(unit_visual)
		unit_visual.configure(_unit_definitions[unit_id], placement)
		_unit_visuals[unit_id] = unit_visual

	var link_presentation_settings := {}
	for entry in presentation_map.get("links", []):
		var link_id := StringName(entry.get("link_id", ""))
		if link_id != &"":
			link_presentation_settings[link_id] = entry

	for link_config in topology_data.get("links", []):
		var source_port_id: StringName = StringName(link_config.get("source_port_id", ""))
		var destination_port_id: StringName = StringName(link_config.get("destination_port_id", ""))
		var source_unit_id: StringName = port_to_unit.get(source_port_id, &"")
		var destination_unit_id: StringName = port_to_unit.get(destination_port_id, &"")
		if source_unit_id == &"" or destination_unit_id == &"":
			continue
		if not _presentation_positions.has(source_unit_id) or not _presentation_positions.has(destination_unit_id):
			continue

		var link_visual = LINK_VISUAL_SCRIPT.new()
		var link_id: StringName = StringName(link_config.get("link_id", ""))
		link_visual.name = "%sVisual" % String(link_id)
		add_child(link_visual)
		
		var setting: Dictionary = link_presentation_settings.get(link_id, {})
		link_visual.configure({
			"link_id": link_id,
			"display_name": link_config.get("display_name", String(link_id)),
			"max_flow_m3s": float(link_config.get("max_flow_m3s", 0.0)),
			"mesh_path": String(setting.get("mesh_path", "")),
			"mesh_scale_m": setting.get("mesh_scale_m", [1.0, 1.0, 1.0])
		}, _presentation_positions[source_unit_id]["position"], _presentation_positions[destination_unit_id]["position"])
		_link_visuals[link_id] = link_visual

func refresh_from_snapshot() -> void:
	if _engine == null:
		return
	var snap: Dictionary = _engine.latest_snapshot
	if snap.is_empty():
		return

	var unit_snaps: Dictionary = snap.get("units", {})
	for unit_id in _unit_visuals.keys():
		if unit_snaps.has(unit_id):
			_unit_visuals[unit_id].apply_snapshot(unit_snaps[unit_id])

	var link_snaps: Dictionary = snap.get("links", {})
	for link_id in _link_visuals.keys():
		if link_snaps.has(link_id):
			_link_visuals[link_id].apply_snapshot(link_snaps[link_id])

func get_unit_fill_ratio(unit_id: StringName) -> float:
	var visual = _unit_visuals.get(unit_id)
	if visual == null:
		return 0.0
	return visual.get_fill_ratio()

func get_unit_level_m(unit_id: StringName) -> float:
	var visual = _unit_visuals.get(unit_id)
	if visual == null:
		return 0.0
	return visual.get_last_level_m()

func get_unit_max_level_m(unit_id: StringName) -> float:
	if not _unit_definitions.has(unit_id):
		return 0.0
	return float(_unit_definitions[unit_id].get("max_level_m", 0.0))

func get_link_flow_ratio(link_id: StringName) -> float:
	var visual = _link_visuals.get(link_id)
	if visual == null:
		return 0.0
	return visual.get_flow_ratio()

func _process(_delta: float) -> void:
	refresh_from_snapshot()

func _clear_visuals() -> void:
	_unit_visuals.clear()
	_link_visuals.clear()
	for child in get_children():
		child.queue_free()

func _build_reference_plane(ref_config: Dictionary) -> void:
	var image_path: String = ref_config.get("image_path", "")
	var size_arr = ref_config.get("size_m", [10.0, 10.0])
	var center_arr = ref_config.get("center_m", [0.0, 0.0])
	var opacity: float = float(ref_config.get("opacity", 1.0))

	if image_path == "" or not ResourceLoader.exists(image_path):
		push_warning("Reference plane image path does not exist: %s" % image_path)
		return

	var texture = load(image_path)
	if texture == null:
		push_warning("Failed to load reference plane texture: %s" % image_path)
		return

	var plane_instance := MeshInstance3D.new()
	plane_instance.name = "ReferencePlane"

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(float(size_arr[0]), float(size_arr[1]))
	plane_instance.mesh = plane_mesh

	var x_pos := float(center_arr[0])
	var z_pos := float(center_arr[1])
	plane_instance.position = Vector3(x_pos, -0.05, z_pos)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if opacity < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, opacity)

	plane_instance.set_surface_override_material(0, mat)
	add_child(plane_instance)

func _array_to_vector3(values: Variant) -> Vector3:
	if values is Array and values.size() >= 3:
		return Vector3(float(values[0]), float(values[1]), float(values[2]))
	return Vector3.ZERO
