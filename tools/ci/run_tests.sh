#!/bin/bash
GODOT_PATH=${1:-godot}
echo "Running GUT tests with: $GODOT_PATH"
$GODOT_PATH --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
exit $?
