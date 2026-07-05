class_name HeadworksLinkVisual
extends Node3D

var link_id: StringName = &""
var max_flow_m3s: float = 0.0
var _length: float = 1.0
var _bar_mesh: Node3D = null
var _flow_ratio: float = 0.0
var _custom_scale: Vector3 = Vector3.ONE

func configure(definition: Dictionary, start_position: Vector3, end_position: Vector3) -> void:
	link_id = StringName(definition.get("link_id", ""))
	max_flow_m3s = float(definition.get("max_flow_m3s", 0.0))
	var mesh_path = String(definition.get("mesh_path", ""))
	_custom_scale = _array_to_vector3(definition.get("mesh_scale_m", [1.0, 1.0, 1.0]))
	
	_build_mesh(mesh_path, _custom_scale)

	var lifted_start := start_position + Vector3(0.0, 2.25, 0.0)
	var lifted_end := end_position + Vector3(0.0, 2.25, 0.0)
	_length = max(lifted_start.distance_to(lifted_end), 0.1)
	position = lifted_start.lerp(lifted_end, 0.5)
	look_at(lifted_end, Vector3.UP)
	_update_bar_visual(0.0, true)

func apply_snapshot(link_snap: Dictionary) -> void:
	var actual_flow_m3s: float = float(link_snap.get("actual_flow_m3s", 0.0))
	_flow_ratio = 0.0
	if max_flow_m3s > 0.0:
		_flow_ratio = clamp(actual_flow_m3s / max_flow_m3s, 0.0, 1.0)
	_update_bar_visual(_flow_ratio, bool(link_snap.get("is_enabled", true)))

func get_flow_ratio() -> float:
	return _flow_ratio

func _build_mesh(mesh_path: String, mesh_scale_m: Vector3) -> void:
	for child in get_children():
		child.queue_free()

	if mesh_path != "" and ResourceLoader.exists(mesh_path):
		var scene = load(mesh_path)
		if scene is PackedScene:
			_bar_mesh = scene.instantiate()
			_bar_mesh.name = "CustomPipe"
			add_child(_bar_mesh)
			_bar_mesh.scale = mesh_scale_m
			var actual_mesh = _find_first_mesh(_bar_mesh)
			if actual_mesh != null:
				var mat = actual_mesh.get_active_material(0)
				if mat == null:
					actual_mesh.set_surface_override_material(0, _make_material())
		else:
			_bar_mesh = null
	else:
		_bar_mesh = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.0, 1.0, 1.0)
		_bar_mesh.mesh = mesh
		_bar_mesh.set_surface_override_material(0, _make_material())
		add_child(_bar_mesh)

func _update_bar_visual(flow_ratio: float, is_enabled: bool) -> void:
	if _bar_mesh == null:
		return
	var thickness: float = lerp(0.10, 0.45, flow_ratio)
	
	if _bar_mesh.name == "CustomPipe":
		_bar_mesh.scale = Vector3(thickness * _custom_scale.x, thickness * _custom_scale.y, _length * _custom_scale.z)
	else:
		_bar_mesh.scale = Vector3(thickness, max(thickness * 0.55, 0.08), _length)
		
	var actual_mesh = _find_first_mesh(_bar_mesh) if _bar_mesh != null else null
	var tint_target: MeshInstance3D = actual_mesh if actual_mesh != null else (_bar_mesh as MeshInstance3D)
	
	if tint_target != null:
		var material: StandardMaterial3D = tint_target.get_active_material(0) as StandardMaterial3D
		if material != null:
			if not is_enabled:
				material.albedo_color = Color(0.22, 0.22, 0.24, 0.70)
				material.emission = Color(0.06, 0.06, 0.07, 1.0)
			else:
				material.albedo_color = Color(0.18 + (0.72 * flow_ratio), 0.32 + (0.30 * flow_ratio), 0.78 - (0.36 * flow_ratio), 0.88)
				material.emission = Color(0.06 + (0.32 * flow_ratio), 0.10 + (0.18 * flow_ratio), 0.20 + (0.04 * flow_ratio), 1.0)

func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.18, 0.32, 0.78, 0.88)
	material.emission_enabled = true
	material.emission = Color(0.06, 0.10, 0.20, 1.0)
	material.roughness = 0.12
	return material

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_first_mesh(child)
		if found != null:
			return found
	return null

func _array_to_vector3(values: Variant, default_val := Vector3.ONE) -> Vector3:
	if values is Array and values.size() >= 3:
		return Vector3(float(values[0]), float(values[1]), float(values[2]))
	return default_val
