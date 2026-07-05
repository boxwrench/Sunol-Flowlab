class_name PresentationMapHandler
extends RefCounted

# Loads a presentation map from a JSON file path.
static func load_map(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

# Saves a presentation map to a JSON file path, pretty-printing with 2 spaces.
static func save_map(file_path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	var json_str := JSON.stringify(data, "  ")
	file.store_string(json_str)
	file.close()
	return true

# Merges new position and rotation placements into the map_data Dictionary.
# Preserves other keys like $schema, reference_plane, and non-spatial unit fields.
static func update_units(map_data: Dictionary, new_placements: Dictionary) -> Dictionary:
	var units_array: Array = map_data.get("units", [])
	
	# Map existing unit entries by unit_id
	var existing_units_dict := {}
	for i in range(units_array.size()):
		var unit = units_array[i]
		if unit is Dictionary and unit.has("unit_id"):
			existing_units_dict[StringName(unit["unit_id"])] = i

	for unit_id in new_placements.keys():
		var placement: Dictionary = new_placements[unit_id]
		var pos: Array = placement.get("position_m", [0.0, 0.0, 0.0])
		var rot: Array = placement.get("rotation_deg", [0.0, 0.0, 0.0])
		
		var pos_arr := [float(pos[0]), float(pos[1]), float(pos[2])]
		var rot_arr := [float(rot[0]), float(rot[1]), float(rot[2])]
		
		var s_unit_id = StringName(unit_id)
		if existing_units_dict.has(s_unit_id):
			var idx: int = existing_units_dict[s_unit_id]
			var unit_entry: Dictionary = units_array[idx]
			unit_entry["position_m"] = pos_arr
			unit_entry["rotation_deg"] = rot_arr
		else:
			var new_entry := {
				"unit_id": String(unit_id),
				"position_m": pos_arr,
				"rotation_deg": rot_arr
			}
			units_array.append(new_entry)
			
	map_data["units"] = units_array
	return map_data
