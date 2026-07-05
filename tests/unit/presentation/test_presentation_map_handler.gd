extends "res://addons/gut/test.gd"

const HANDLER_SCRIPT = preload("res://scripts/tools/presentation_map_handler.gd")
const TEMP_TEST_PATH = "user://temp_test_presentation_map.json"

func before_each() -> void:
	if FileAccess.file_exists(TEMP_TEST_PATH):
		DirAccess.remove_absolute(TEMP_TEST_PATH)

func after_each() -> void:
	if FileAccess.file_exists(TEMP_TEST_PATH):
		DirAccess.remove_absolute(TEMP_TEST_PATH)

func test_round_trip_preserves_structure_and_values() -> void:
	var original_data := {
		"$schema": "../../schema/presentation_map.schema.json",
		"reference_plane": {
			"image_path": "res://assets/textures/blueprint.jpg",
			"size_m": [120.0, 60.0],
			"center_m": [5.0, -2.0],
			"opacity": 0.9
		},
		"units": [
			{
				"unit_id": "RESERVOIR_01",
				"position_m": [-45.0, 1.2, -10.0],
				"rotation_deg": [0.0, 45.0, 0.0]
			},
			{
				"unit_id": "FLASH_MIX_01",
				"position_m": [-15.0, 0.0, 5.0],
				"rotation_deg": [10.0, 0.0, 90.0]
			}
		]
	}
	
	var save_ok := HANDLER_SCRIPT.save_map(TEMP_TEST_PATH, original_data)
	assert_true(save_ok, "Saving map should succeed")
	
	var loaded_data := HANDLER_SCRIPT.load_map(TEMP_TEST_PATH)
	assert_false(loaded_data.is_empty(), "Loading map should succeed")
	
	assert_eq(loaded_data.get("$schema"), original_data.get("$schema"), "Schema path should match")
	
	var original_ref = original_data["reference_plane"]
	var loaded_ref = loaded_data.get("reference_plane", {})
	assert_eq(loaded_ref.get("image_path"), original_ref.get("image_path"), "Ref plane image path should match")
	assert_eq(loaded_ref.get("size_m"), original_ref.get("size_m"), "Ref plane size should match")
	assert_eq(loaded_ref.get("center_m"), original_ref.get("center_m"), "Ref plane center should match")
	assert_eq(loaded_ref.get("opacity"), original_ref.get("opacity"), "Ref plane opacity should match")
	
	var loaded_units = loaded_data.get("units", [])
	assert_eq(loaded_units.size(), original_data["units"].size(), "Units count should match")
	
	for i in range(loaded_units.size()):
		var original_unit = original_data["units"][i]
		var loaded_unit = loaded_units[i]
		assert_eq(loaded_unit.get("unit_id"), original_unit.get("unit_id"), "Unit ID should match")
		assert_eq(loaded_unit.get("position_m"), original_unit.get("position_m"), "Unit position should match")
		assert_eq(loaded_unit.get("rotation_deg"), original_unit.get("rotation_deg"), "Unit rotation should match")

func test_update_units_preserves_other_properties() -> void:
	var original_data := {
		"$schema": "../../schema/presentation_map.schema.json",
		"reference_plane": {
			"image_path": "res://assets/textures/blueprint.jpg",
			"size_m": [120.0, 60.0],
			"center_m": [5.0, -2.0],
			"opacity": 0.9
		},
		"units": [
			{
				"unit_id": "RESERVOIR_01",
				"position_m": [-45.0, 1.2, -10.0],
				"rotation_deg": [0.0, 45.0, 0.0]
			}
		]
	}
	
	var new_placements := {
		"RESERVOIR_01": {
			"position_m": [10.0, 20.0, 30.0],
			"rotation_deg": [5.0, 15.0, 25.0]
		},
		"NEW_UNIT_01": {
			"position_m": [-5.0, -5.0, -5.0],
			"rotation_deg": [0.0, 0.0, 0.0]
		}
	}
	
	var updated_data = HANDLER_SCRIPT.update_units(original_data, new_placements)
	
	assert_eq(updated_data.get("$schema"), original_data.get("$schema"), "Schema preserved")
	assert_eq(updated_data.get("reference_plane"), original_data.get("reference_plane"), "Reference plane preserved")
	
	var units = updated_data.get("units", [])
	assert_eq(units.size(), 2, "Units count should be 2 after update")
	
	var res01 = null
	var new_unit = null
	for u in units:
		if u.get("unit_id") == "RESERVOIR_01":
			res01 = u
		elif u.get("unit_id") == "NEW_UNIT_01":
			new_unit = u
			
	assert_not_null(res01, "RESERVOIR_01 should be in the updated list")
	assert_eq(res01.get("position_m"), [10.0, 20.0, 30.0], "RESERVOIR_01 position should be updated")
	assert_eq(res01.get("rotation_deg"), [5.0, 15.0, 25.0], "RESERVOIR_01 rotation should be updated")
	
	assert_not_null(new_unit, "NEW_UNIT_01 should be appended to the list")
	assert_eq(new_unit.get("position_m"), [-5.0, -5.0, -5.0], "NEW_UNIT_01 position should be set")
	assert_eq(new_unit.get("rotation_deg"), [0.0, 0.0, 0.0], "NEW_UNIT_01 rotation should be set")
