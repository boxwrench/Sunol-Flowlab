extends Node3D

# Static scenery only. River, buildings and terrain are context, not process units.
func _ready() -> void:
    var grass := _material(Color("789653"))
    var concrete := _material(Color("d4d7c7"))
    var asphalt := _material(Color("606b65"))
    var pine := _material(Color("365c45"))
    var trunk := _material(Color("76614b"))
    _box("SiteLand", Vector3(100, 2, 78), Vector3(0, -1.4, 0), grass)
    _box("PlantApron", Vector3(78, 0.3, 49), Vector3(-1, -0.15, 0), concrete)
    _box("ServiceRoad", Vector3(82, 0.12, 5), Vector3(-1, 0.02, 28), asphalt)
    for x in range(-38, 39, 8):
        _box("RoadMark", Vector3(3, 0.03, 0.15), Vector3(x, 0.09, 28), concrete)
    _building(Vector3(-15, 0, -19), Vector3(13, 6, 7), concrete)
    _building(Vector3(-12, 0, 18), Vector3(9, 3.5, 5), concrete)
    var river := _material(Color("459ab1"))
    _box("ScenicRiver", Vector3(180, 0.1, 12), Vector3(0, -0.4, -45), river)
    var rng := RandomNumberGenerator.new()
    rng.seed = 2718
    for i in range(65):
        var x := rng.randf_range(-66, 66)
        var z := rng.randf_range(-67, 47)
        if absf(x) < 47 and z > -51 and z < 35:
            continue
        if z > -52 and z < -37:
            continue
        var height := rng.randf_range(4, 8)
        _tree(Vector3(x, -0.4, z), height, pine, trunk)
    for i in range(28):
        var x := rng.randf_range(-44, 40)
        var z := -32.0 if i < 18 else 36.0
        _tree(Vector3(x, -0.4, z + rng.randf_range(-2, 2)), rng.randf_range(4, 6.5), pine, trunk)
    for i in range(15):
        var hill := SphereMesh.new()
        hill.radial_segments = 7
        hill.rings = 3
        hill.radius = 1
        hill.height = 2
        var node := _mesh("Hill", hill, Vector3(-85 + i * 12, -3, -85 - (i % 3) * 8), grass)
        node.scale = Vector3(20, 10 + i % 4 * 3, 18)

func _tree(at: Vector3, height: float, pine: StandardMaterial3D, trunk: StandardMaterial3D) -> void:
    _box("TreeTrunk", Vector3(0.35, height * 0.5, 0.35), at + Vector3(0, height * 0.25, 0), trunk)
    for tier in range(3):
        var cone := CylinderMesh.new()
        cone.top_radius = 0
        cone.bottom_radius = height * (0.25 - tier * 0.05)
        cone.height = height * 0.5
        cone.radial_segments = 7
        _mesh("Pine", cone, at + Vector3(0, height * (0.4 + tier * 0.19), 0), pine)

func _building(at: Vector3, size: Vector3, concrete: StandardMaterial3D) -> void:
    _box("OperationsBuilding", size, at + Vector3(0, size.y / 2, 0), concrete)
    _box("Roof", Vector3(size.x + 0.6, 0.35, size.z + 0.6), at + Vector3(0, size.y, 0), _material(Color("536b71")))
    var glass := _material(Color("487b89"))
    for x in range(-4, 5, 3):
        _box("Window", Vector3(1.6, 1.8, 0.08), at + Vector3(x, size.y * 0.55, size.z / 2 + 0.05), glass)
    _box("Door", Vector3(1.3, 2.4, 0.1), at + Vector3(size.x * 0.3, 1.2, size.z / 2 + 0.06), glass)
    for x in [-3.0, 0.0, 3.0]:
        _box("RoofEquipment", Vector3(1.7, 0.6, 1.7), at + Vector3(x, size.y + 0.5, 0), _material(Color("9daca9")))

func _box(label: String, size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var box := BoxMesh.new()
    box.size = size
    return _mesh(label, box, at, material)

func _mesh(label: String, mesh: Mesh, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.position = at
    node.material_override = material
    add_child(node)
    return node

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color.srgb_to_linear()
    material.roughness = 0.9
    return material
