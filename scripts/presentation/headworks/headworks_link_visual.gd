class_name HeadworksLinkVisual
extends Node3D

var link_id: StringName = &""
var max_flow_m3s: float = 0.0
var _length: float = 1.0
var _bar_mesh: MeshInstance3D = null
var _flow_ratio: float = 0.0

func configure(definition: Dictionary, start_position: Vector3, end_position: Vector3) -> void:
	link_id = StringName(definition.get("link_id", ""))
	max_flow_m3s = float(definition.get("max_flow_m3s", 0.0))
	_build_mesh()

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

func _build_mesh() -> void:
	for child in get_children():
		child.queue_free()

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
	_bar_mesh.scale = Vector3(thickness, max(thickness * 0.55, 0.08), _length)
	var material: StandardMaterial3D = _bar_mesh.get_active_material(0) as StandardMaterial3D
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
