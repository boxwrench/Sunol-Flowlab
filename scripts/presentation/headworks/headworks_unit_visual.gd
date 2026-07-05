class_name HeadworksUnitVisual
extends Node3D

const STORAGE_LARGE_SIZE := Vector3(5.0, 4.0, 5.0)
const STORAGE_MEDIUM_SIZE := Vector3(4.0, 2.5, 3.0)
const STORAGE_SMALL_SIZE := Vector3(2.6, 2.2, 2.6)
const BOUNDARY_SIZE := Vector3(2.2, 1.6, 2.2)

var unit_id: StringName = &""
var display_name: String = ""
var unit_type: String = ""
var boundary_type: String = ""
var max_level_m: float = 0.0
var maximum_volume_m3: float = 0.0

var mesh_path: String = ""
var mesh_scale_m: Vector3 = Vector3.ONE

var _body_mesh: MeshInstance3D = null
var _water_mesh: MeshInstance3D = null
var _label: Label3D = null
var _size: Vector3 = STORAGE_SMALL_SIZE
var _fill_ratio: float = 0.0
var _last_level_m: float = 0.0

func configure(definition: Dictionary, placement: Dictionary) -> void:
	unit_id = StringName(definition.get("unit_id", ""))
	display_name = String(definition.get("display_name", String(unit_id)))
	unit_type = String(definition.get("type", ""))
	boundary_type = String(definition.get("boundary_type", ""))
	max_level_m = float(definition.get("max_level_m", 0.0))
	maximum_volume_m3 = float(definition.get("maximum_volume_m3", 0.0))
	position = placement.get("position", Vector3.ZERO)
	rotation_degrees = placement.get("rotation", Vector3.ZERO)
	_size = _pick_size()
	mesh_path = String(placement.get("mesh_path", ""))
	mesh_scale_m = _array_to_vector3(placement.get("mesh_scale_m", [1.0, 1.0, 1.0]))
	_build_visual()

func apply_snapshot(unit_snap: Dictionary) -> void:
	var in_service: bool = bool(unit_snap.get("in_service", true))
	var operating_state: String = "IN_SERVICE" if in_service else "OUT_OF_SERVICE"
	_last_level_m = float(unit_snap.get("level_m", 0.0))
	_fill_ratio = 0.0

	if _body_mesh != null:
		var body_material: StandardMaterial3D = _body_mesh.get_active_material(0) as StandardMaterial3D
		if body_material != null:
			body_material.albedo_color = _body_color(in_service)

	if _water_mesh != null:
		if max_level_m > 0.0:
			_fill_ratio = clamp(_last_level_m / max_level_m, 0.0, 1.0)
		var water_height: float = max(_size.y * _fill_ratio - 0.15, 0.0)
		_water_mesh.visible = water_height > 0.0
		if _water_mesh.visible:
			var water_mesh: BoxMesh = _water_mesh.mesh as BoxMesh
			if water_mesh != null:
				water_mesh.size = Vector3(_size.x - 0.45, water_height, _size.z - 0.45)
			_water_mesh.position = Vector3(0.0, (water_height * 0.5) + 0.05, 0.0)
			var water_material: StandardMaterial3D = _water_mesh.get_active_material(0) as StandardMaterial3D
			if water_material != null:
				water_material.albedo_color = Color(0.16, 0.56, 0.86, 0.72) if in_service else Color(0.35, 0.40, 0.48, 0.60)

	if _label != null:
		if unit_type == "StorageUnit":
			_label.text = "%s\n%s %.2fm" % [display_name, operating_state, _last_level_m]
		else:
			var boundary_flow: float = float(unit_snap.get("current_flow_m3s", 0.0))
			_label.text = "%s\n%s %.2f m3/s" % [display_name, operating_state, boundary_flow]

func get_fill_ratio() -> float:
	return _fill_ratio

func get_last_level_m() -> float:
	return _last_level_m

func _build_visual() -> void:
	for child in get_children():
		child.queue_free()

	if mesh_path != "" and ResourceLoader.exists(mesh_path):
		var scene = load(mesh_path)
		if scene is PackedScene:
			var instance = scene.instantiate()
			instance.name = "CustomMesh"
			add_child(instance)
			instance.scale = mesh_scale_m
			_body_mesh = _find_first_mesh(instance)
		else:
			_body_mesh = null
	else:
		_body_mesh = MeshInstance3D.new()
		_body_mesh.mesh = _create_body_mesh()
		_body_mesh.position = Vector3(0.0, _size.y * 0.5, 0.0)
		_body_mesh.set_surface_override_material(0, _make_body_material())
		add_child(_body_mesh)

	if unit_type == "StorageUnit":
		_water_mesh = MeshInstance3D.new()
		_water_mesh.mesh = BoxMesh.new()
		_water_mesh.visible = false
		_water_mesh.set_surface_override_material(0, _make_water_material())
		add_child(_water_mesh)
	else:
		_water_mesh = null

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.96, 0.97, 0.99, 1.0)
	_label.font_size = 32
	_label.outline_modulate = Color(0.04, 0.06, 0.08, 1.0)
	_label.outline_size = 6
	var label_height := _size.y + 0.75
	if mesh_path != "":
		label_height = max(mesh_scale_m.y * 3.0, 3.0)
	_label.position = Vector3(0.0, label_height, 0.0)
	_label.text = display_name
	add_child(_label)

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

func _create_body_mesh() -> Mesh:
	if unit_type == "StorageUnit":
		var box := BoxMesh.new()
		box.size = _size
		return box
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = _size.x * 0.35
	cylinder.bottom_radius = _size.x * 0.45
	cylinder.height = _size.y
	return cylinder

func _pick_size() -> Vector3:
	if unit_type != "StorageUnit":
		return BOUNDARY_SIZE
	if maximum_volume_m3 >= 500.0:
		return STORAGE_LARGE_SIZE
	if maximum_volume_m3 >= 100.0:
		return STORAGE_MEDIUM_SIZE
	return STORAGE_SMALL_SIZE

func _make_body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = _body_color(true)
	material.roughness = 0.25
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _make_water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.16, 0.56, 0.86, 0.72)
	material.emission_enabled = true
	material.emission = Color(0.08, 0.26, 0.42, 1.0)
	material.roughness = 0.08
	return material

func _body_color(in_service: bool) -> Color:
	if unit_type != "StorageUnit":
		if boundary_type == "SOURCE_INFLOW":
			return Color(0.28, 0.52, 0.40, 0.92) if in_service else Color(0.20, 0.24, 0.22, 0.72)
		if boundary_type == "TREATED_DEMAND":
			return Color(0.58, 0.48, 0.26, 0.92) if in_service else Color(0.24, 0.22, 0.18, 0.72)
		return Color(0.42, 0.32, 0.24, 0.90) if in_service else Color(0.20, 0.18, 0.16, 0.72)
	return Color(0.92, 0.95, 0.98, 0.22) if in_service else Color(0.55, 0.57, 0.60, 0.12)
