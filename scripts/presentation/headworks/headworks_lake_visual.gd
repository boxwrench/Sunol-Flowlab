class_name HeadworksLakeVisual
extends Node3D

# Native, static shoreline geometry. The parent unit adapter alone applies levels.
const VISUAL_SIZE := Vector3(26, 1.6, 22)
var water_mesh: MeshInstance3D

func _ready() -> void:
    var bed := SurfaceTool.new()
    var banks := SurfaceTool.new()
    var water := SurfaceTool.new()
    bed.begin(Mesh.PRIMITIVE_TRIANGLES)
    banks.begin(Mesh.PRIMITIVE_TRIANGLES)
    water.begin(Mesh.PRIMITIVE_TRIANGLES)
    var shoreline: Array[Vector3] = []
    for i in range(14):
        var angle := TAU * float(i) / 14.0
        var radius := 1.0 + 0.08 * sin(i * 2.1) + 0.06 * cos(i * 3.7)
        shoreline.append(Vector3(cos(angle) * 11.0 * radius, 0, sin(angle) * 8.8 * radius))
    for i in range(shoreline.size()):
        var a := shoreline[i]
        var b := shoreline[(i + 1) % shoreline.size()]
        var inner_a := a * 0.6
        var inner_b := b * 0.6
        var crest_a := a * 0.95 + Vector3(0, 1.9 + 0.14 * sin(i), 0)
        var crest_b := b * 0.95 + Vector3(0, 1.9 + 0.14 * sin(i + 1), 0)
        var outer_a := a * 1.18 + Vector3(0, -0.35, 0)
        var outer_b := b * 1.18 + Vector3(0, -0.35, 0)
        _triangle(bed, Vector3.ZERO, inner_b, inner_a)
        _triangle(bed, inner_a, inner_b, crest_b)
        _triangle(bed, inner_a, crest_b, crest_a)
        _triangle(banks, crest_a, crest_b, outer_b)
        _triangle(banks, crest_a, outer_b, outer_a)
        # Broad plane extends beneath banks. Their sloping geometry reveals the
        # shoreline as the snapshot-driven surface rises or falls.
        _triangle(water, Vector3.ZERO, b * 0.95, a * 0.95)
    _add_mesh("LakeBed", bed.commit(), _material(Color("877b59")))
    _add_mesh("NaturalBanks", banks.commit(), _material(Color("789653")))
    water_mesh = _add_mesh("LakeWater", water.commit(), _material(Color("42b9cd")))
    water_mesh.visible = false
    var rock_material := _material(Color("a4a594"))
    for i in [1, 4, 8, 11]:
        var rock := SphereMesh.new()
        rock.radius = 0.8
        rock.height = 1.3
        rock.radial_segments = 6
        rock.rings = 3
        var node := _add_mesh("ShoreRock", rock, rock_material)
        node.position = shoreline[i] * 1.02 + Vector3(0, 1.5, 0)
        node.scale = Vector3(1.4, 0.8, 1.0)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    var normal := (b - a).cross(c - a).normalized()
    # Upward normals and Godot's clockwise front-face winding.
    if normal.y < 0:
        var swap := b
        b = c
        c = swap
        normal = -normal
    for vertex in [a, c, b]:
        surface.set_normal(normal)
        surface.add_vertex(vertex)

func _add_mesh(label: String, mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.material_override = material
    add_child(node)
    return node

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color.srgb_to_linear()
    material.roughness = 0.9
    return material
