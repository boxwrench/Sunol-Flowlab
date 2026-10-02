class_name HeadworksUnitVisual
extends Node3D

signal unit_selected(unit_id: StringName)

const STORAGE_LARGE_SIZE := Vector3(15.0, 2.8, 5.0)
const STORAGE_MEDIUM_SIZE := Vector3(5.0, 2.8, 36.0)
const STORAGE_SMALL_SIZE := Vector3(3.0, 2.8, 3.0)
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
var _walls: Array[MeshInstance3D] = []
var _selection_mesh: MeshInstance3D = null

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
	_last_level_m = float(unit_snap.get("level_m", 0.0))
	_fill_ratio = 0.0

	if _body_mesh != null:
		var body_material: StandardMaterial3D = _body_mesh.get_active_material(0) as StandardMaterial3D
		if body_material != null:
			body_material.albedo_color = _body_color(in_service)
	for wall in _walls:
		wall.material_override.albedo_color = _body_color(in_service)

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
				water_material.albedo_color = (Color("42b9cd") if in_service else Color("7c9297")).srgb_to_linear()

	if _label != null:
		if unit_type == "StorageUnit":
			_label.text = "%s\n%s%s" % [display_name.replace("Flocculation/Sedimentation ", ""), DisplayUnits.format_level(_last_level_m), " | Offline" if not in_service else ""]
		else:
			var boundary_flow: float = float(unit_snap.get("current_flow_m3s", 0.0))
			_label.text = "%s\n%s" % [display_name, DisplayUnits.format_flow(boundary_flow)]

func set_selected(selected: bool) -> void:
	if _selection_mesh != null:
		_selection_mesh.visible = selected

func get_fill_ratio() -> float:
	return _fill_ratio

func get_last_level_m() -> float:
	return _last_level_m

func _build_visual() -> void:
	_walls.clear()
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
		if unit_type == "StorageUnit":
			var floor_mesh := BoxMesh.new()
			floor_mesh.size = Vector3(_size.x, 0.16, _size.z)
			_body_mesh.mesh = floor_mesh
			_body_mesh.position.y = 0.08
			_build_walls()
		else:
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
	_label.modulate = Color("203d43")
	_label.font_size = 34
	_label.pixel_size = 0.035
	_label.outline_modulate = Color("edf2e9")
	_label.outline_size = 3
	var label_height := _size.y + 0.75
	if mesh_path != "":
		label_height = max(mesh_scale_m.y * 3.0, 3.0)
	_label.position = Vector3(0.0, label_height, 0.0)
	_label.text = display_name
	add_child(_label)
	_build_selection()

func _build_walls() -> void:
	for z in [-1.0, 1.0]:
		_add_wall(Vector3(_size.x, _size.y, 0.25), Vector3(0, _size.y / 2, z * (_size.z / 2 - 0.125)))
	for x in [-1.0, 1.0]:
		_add_wall(Vector3(0.25, _size.y, _size.z), Vector3(x * (_size.x / 2 - 0.125), _size.y / 2, 0))
	if maximum_volume_m3 >= 500 and maximum_volume_m3 < 1000:
		# Static access bridge; it does not imply mixing or settling simulation.
		_add_wall(Vector3(0.65, 0.16, _size.z), Vector3(-_size.x * 0.22, _size.y + 0.15, 0))
		for z in [-1.0, 1.0]:
			_add_wall(Vector3(_size.x, 0.08, 0.08), Vector3(0, _size.y + 0.65, z * (_size.z / 2 - 0.12)))
			for x in range(-6, 7, 3):
				_add_wall(Vector3(0.08, 0.65, 0.08), Vector3(x, _size.y + 0.325, z * (_size.z / 2 - 0.12)))

func _add_wall(size: Vector3, at: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _make_body_material()
	add_child(node)
	_walls.append(node)

func _build_selection() -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _size
	collider.shape = shape
	collider.position.y = _size.y / 2
	body.add_child(collider)
	body.input_event.connect(_on_input_event)
	add_child(body)
	_selection_mesh = MeshInstance3D.new()
	var pad := BoxMesh.new()
	pad.size = Vector3(_size.x + 0.8, 0.06, _size.z + 0.8)
	_selection_mesh.mesh = pad
	_selection_mesh.position.y = 0.035
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ecc46c")
	_selection_mesh.material_override = material
	_selection_mesh.visible = false
	add_child(_selection_mesh)

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		unit_selected.emit(unit_id)

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
	if maximum_volume_m3 >= 1000.0:
		return Vector3(11, 4, 11)
	if maximum_volume_m3 >= 500.0:
		return STORAGE_LARGE_SIZE
	if maximum_volume_m3 >= 100.0:
		return STORAGE_MEDIUM_SIZE
	return STORAGE_SMALL_SIZE

func _make_body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _body_color(true)
	material.roughness = 0.9
	return material

func _make_water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("42b9cd").srgb_to_linear()
	material.roughness = 0.35
	return material

func _body_color(in_service: bool) -> Color:
	if unit_type != "StorageUnit":
		if boundary_type == "SOURCE_INFLOW":
			return Color(0.28, 0.52, 0.40, 0.92) if in_service else Color(0.20, 0.24, 0.22, 0.72)
		if boundary_type == "TREATED_DEMAND":
			return Color(0.58, 0.48, 0.26, 0.92) if in_service else Color(0.24, 0.22, 0.18, 0.72)
		return Color(0.42, 0.32, 0.24, 0.90) if in_service else Color(0.20, 0.18, 0.16, 0.72)
	return (Color("dce0d4") if in_service else Color("9b9e98")).srgb_to_linear()
