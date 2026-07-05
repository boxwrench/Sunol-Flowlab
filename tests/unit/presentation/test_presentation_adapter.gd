extends "res://addons/gut/test.gd"

const ADAPTER_SCRIPT = preload("res://scripts/presentation/headworks/headworks_presentation_adapter.gd")

func test_reference_plane_creation_when_configured() -> void:
	var presenter = ADAPTER_SCRIPT.new()
	add_child_autofree(presenter)

	var engine = SimulationEngine.new()
	var config := ConfigLoader.load_plant_config("phase3_headworks")
	assert_true(config.success, "Config load should succeed")

	# presentation map with reference plane
	var presentation_map = {
		"reference_plane": {
			"image_path": "res://assets/textures/blueprint.jpg",
			"size_m": [100.0, 50.0],
			"center_m": [0.0, 0.0],
			"opacity": 0.5
		},
		"units": []
	}

	presenter.configure(engine, config.topology_data, presentation_map)

	var ref_plane = presenter.get_node_or_null("ReferencePlane")
	assert_not_null(ref_plane, "ReferencePlane should be created when config present")
	assert_true(ref_plane is MeshInstance3D, "ReferencePlane should be a MeshInstance3D")

	var mesh = ref_plane.mesh
	assert_true(mesh is PlaneMesh, "ReferencePlane mesh should be a PlaneMesh")
	assert_eq(mesh.size, Vector2(100.0, 50.0), "ReferencePlane size should match config")
	assert_eq(ref_plane.position, Vector3(0.0, -0.05, 0.0), "ReferencePlane position should match config center")

func test_reference_plane_not_created_when_absent() -> void:
	var presenter = ADAPTER_SCRIPT.new()
	add_child_autofree(presenter)

	var engine = SimulationEngine.new()
	var config := ConfigLoader.load_plant_config("phase3_headworks")
	assert_true(config.success, "Config load should succeed")

	# presentation map without reference plane
	var presentation_map = {
		"units": []
	}

	presenter.configure(engine, config.topology_data, presentation_map)

	var ref_plane = presenter.get_node_or_null("ReferencePlane")
	assert_null(ref_plane, "ReferencePlane should not be created when config is absent")
