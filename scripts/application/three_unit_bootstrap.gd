extends Node3D

func _ready() -> void:
	print("Sunol FlowLab Bootstrapping - Three-Unit Train")
	var host: SimulationHost = get_node_or_null("SimulationHost")
	if host != null:
		var config: Dictionary = ConfigLoader.load_plant_config("phase2_three_unit")
		if config.success:
			var build_ok: bool = PlantFactory.build_plant(
				host.engine.context,
				config.topology_data,
				config.initial_conditions_data,
				config.controllers_data
			)
			if build_ok:
				print("Plant Factory built phase2_three_unit successfully")
			else:
				push_error("Failed to build phase2_three_unit plant")
		else:
			push_error("Failed to load phase2_three_unit configuration")
	else:
		push_error("SimulationHost not found in ThreeUnitTrain scene")
