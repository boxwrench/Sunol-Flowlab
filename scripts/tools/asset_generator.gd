extends SceneTree

func _init() -> void:
	print("Generating visual assets...")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("res://assets/models"):
		dir.make_dir_recursive("res://assets/models")
	
	_generate_basin()
	_generate_pipe()
	_generate_boundary()
	
	print("Visual assets generation completed.")
	quit()

func _generate_basin() -> void:
	var root := Node3D.new()
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.36, 0.38)
	mat.roughness = 0.8
	mat.metallic = 0.1
	
	var floor_mesh := MeshInstance3D.new()
	var f_box := BoxMesh.new()
	f_box.size = Vector3(5.0, 0.4, 5.0)
	floor_mesh.mesh = f_box
	floor_mesh.position = Vector3(0.0, 0.2, 0.0)
	floor_mesh.set_surface_override_material(0, mat)
	root.add_child(floor_mesh)
	
	var wall_left := MeshInstance3D.new()
	var wl_box := BoxMesh.new()
	wl_box.size = Vector3(0.4, 4.0, 5.0)
	wall_left.mesh = wl_box
	wall_left.position = Vector3(-2.3, 2.0, 0.0)
	wall_left.set_surface_override_material(0, mat)
	root.add_child(wall_left)
	
	var wall_right := MeshInstance3D.new()
	var wr_box := BoxMesh.new()
	wr_box.size = Vector3(0.4, 4.0, 5.0)
	wall_right.mesh = wr_box
	wall_right.position = Vector3(2.3, 2.0, 0.0)
	wall_right.set_surface_override_material(0, mat)
	root.add_child(wall_right)

	var wall_front := MeshInstance3D.new()
	var wf_box := BoxMesh.new()
	wf_box.size = Vector3(5.0, 4.0, 0.4)
	wall_front.mesh = wf_box
	wall_front.position = Vector3(0.0, 2.0, 2.3)
	wall_front.set_surface_override_material(0, mat)
	root.add_child(wall_front)
	
	var wall_back := MeshInstance3D.new()
	var wb_box := BoxMesh.new()
	wb_box.size = Vector3(5.0, 4.0, 0.4)
	wall_back.mesh = wb_box
	wall_back.position = Vector3(0.0, 2.0, -2.3)
	wall_back.set_surface_override_material(0, mat)
	root.add_child(wall_back)
	
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(root, state)
	doc.write_to_filesystem(state, "res://assets/models/basin.glb")
	root.free()

func _generate_pipe() -> void:
	var root := Node3D.new()
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.5, 0.55)
	mat.roughness = 0.3
	mat.metallic = 0.8
	
	var pipe_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	pipe_mesh.mesh = cyl
	pipe_mesh.rotation_degrees = Vector3(90, 0, 0)
	pipe_mesh.set_surface_override_material(0, mat)
	root.add_child(pipe_mesh)
	
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(root, state)
	doc.write_to_filesystem(state, "res://assets/models/pipe.glb")
	root.free()

func _generate_boundary() -> void:
	var root := Node3D.new()
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.45, 0.25)
	mat.roughness = 0.4
	mat.metallic = 0.5
	
	var base_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.5, 2.0)
	base_mesh.mesh = box
	base_mesh.position = Vector3(0.0, 0.75, 0.0)
	base_mesh.set_surface_override_material(0, mat)
	root.add_child(base_mesh)
	
	var act_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 0.8
	act_mesh.mesh = cyl
	act_mesh.position = Vector3(0.0, 1.9, 0.0)
	
	var act_mat := StandardMaterial3D.new()
	act_mat.albedo_color = Color(0.8, 0.2, 0.2)
	act_mat.roughness = 0.3
	act_mat.metallic = 0.6
	act_mesh.set_surface_override_material(0, act_mat)
	root.add_child(act_mesh)
	
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(root, state)
	doc.write_to_filesystem(state, "res://assets/models/boundary.glb")
	root.free()
