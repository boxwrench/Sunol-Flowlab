extends "res://addons/gut/test.gd"

func test_assert_true() -> void:
	assert_true(true, "Sanity check should pass")

func test_load_all_scripts() -> void:
	var dir := DirAccess.open("res://scripts")
	if dir:
		_load_scripts_recursive(dir, "res://scripts")
	else:
		# If scripts doesn't exist yet, that's fine for now, we pass.
		assert_true(true, "No scripts directory yet")

func _load_scripts_recursive(dir: DirAccess, path: String) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub_path := path.path_join(file_name)
				var sub_dir := DirAccess.open(sub_path)
				if sub_dir:
					_load_scripts_recursive(sub_dir, sub_path)
		else:
			if file_name.ends_with(".gd"):
				var script_path := path.path_join(file_name)
				var script = load(script_path)
				assert_not_null(script, "Script should load and parse: " + script_path)
		file_name = dir.get_next()
