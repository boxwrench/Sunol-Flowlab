class_name BasinServicePanel
extends Control

@export var basin_ids: Array[StringName] = [
	&"BASIN_01",
	&"BASIN_02",
	&"BASIN_03",
	&"BASIN_04",
	&"BASIN_05"
]

@onready var button_container: VBoxContainer = get_node_or_null("PanelContainer/VBoxContainer/ButtonList")

var _buttons: Dictionary = {}

func _ready() -> void:
	if button_container == null:
		push_error("BasinServicePanel: ButtonList container not found")
		return
	for basin_id in basin_ids:
		var button := Button.new()
		button.name = "%sButton" % String(basin_id)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 32.0)
		button.pressed.connect(_on_basin_button_pressed.bind(basin_id))
		button_container.add_child(button)
		_buttons[basin_id] = button

func _process(_delta: float) -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
	var snap: Dictionary = host.engine.latest_snapshot
	if snap.is_empty():
		return
	var unit_snaps: Dictionary = snap.get("units", {})
	for basin_id in basin_ids:
		var button: Button = _buttons.get(basin_id)
		if button == null or not unit_snaps.has(basin_id):
			continue
		var unit_snap: Dictionary = unit_snaps[basin_id]
		var in_service: bool = bool(unit_snap.get("in_service", true))
		var display_name: String = String(unit_snap.get("display_name", String(basin_id)))
		button.text = "%s: %s" % [display_name, "IN SERVICE" if in_service else "OUT OF SERVICE"]
		button.modulate = Color(0.90, 0.97, 0.92, 1.0) if in_service else Color(0.98, 0.84, 0.84, 1.0)

func _on_basin_button_pressed(basin_id: StringName) -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
	var snap: Dictionary = host.engine.latest_snapshot
	if snap.is_empty():
		return
	var unit_snap: Dictionary = snap.get("units", {}).get(basin_id, {})
	if unit_snap.is_empty():
		return
	var in_service: bool = bool(unit_snap.get("in_service", true))
	CommandBus.submit(SetBasinServiceCommand.new(basin_id, not in_service))
