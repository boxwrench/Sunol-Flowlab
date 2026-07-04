class_name ConfigLoader
extends RefCounted

static func load_plant_config(plant_id: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	var base_path: String = "res://config/plants/".path_join(plant_id)
	
	var load_file: Callable = func(file_name: String, is_optional: bool = false) -> Dictionary:
		var file_path: String = base_path.path_join(file_name)
		if not FileAccess.file_exists(file_path):
			if not is_optional:
				errors.append("ConfigLoader: File not found: '%s'" % file_path)
			return {}
			
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			errors.append("ConfigLoader: Could not open file: '%s'" % file_path)
			return {}
			
		var text: String = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(text)
		if data == null:
			errors.append("ConfigLoader: Failed to parse JSON in '%s'" % file_path)
			return {}
			
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("ConfigLoader: Root of JSON in '%s' must be an object" % file_path)
			return {}
			
		return data
		
	var plant_data: Dictionary = load_file.call("plant.json")
	var topology_data: Dictionary = load_file.call("topology.json")
	var initial_conditions_data: Dictionary = load_file.call("initial_conditions.json")
	var controllers_data: Dictionary = load_file.call("controllers.json", true)
	var alarms_data: Dictionary = load_file.call("alarms.json", true)
	
	if not errors.is_empty():
		return {
			"success": false,
			"errors": errors,
			"warnings": warnings,
			"plant_data": {},
			"topology_data": {},
			"initial_conditions_data": {},
			"controllers_data": {},
			"alarms_data": {}
		}
		
	var dt: float = 1.0
	if plant_data.has("simulation_settings") and plant_data["simulation_settings"].has("default_dt_s"):
		dt = float(plant_data["simulation_settings"]["default_dt_s"])
		
	var validation: Dictionary = PlantValidator.validate_config(
		plant_data, 
		topology_data, 
		initial_conditions_data, 
		dt,
		controllers_data,
		alarms_data
	)
	errors.append_array(validation["errors"])
	warnings.append_array(validation["warnings"])
	
	var success: bool = errors.is_empty()
	
	return {
		"success": success,
		"errors": errors,
		"warnings": warnings,
		"plant_data": plant_data,
		"topology_data": topology_data,
		"initial_conditions_data": initial_conditions_data,
		"controllers_data": controllers_data,
		"alarms_data": alarms_data
	}
