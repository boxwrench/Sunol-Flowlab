class_name TimeControlsController
extends Control

@onready var pause_button: Button = $HBoxContainer/PauseButton
@onready var play_button: Button = $HBoxContainer/PlayButton
@onready var step_button: Button = $HBoxContainer/StepButton
@onready var speed_selector: OptionButton = $HBoxContainer/SpeedSelector
@onready var tick_label: Label = $HBoxContainer/TickLabel

var _host: Node = null

func _ready() -> void:
	# Find SimulationHost in the tree starting from root
	_host = _find_simulation_host(get_tree().root)
	if _host == null:
		push_warning("TimeControlsController: SimulationHost not found in scene tree.")
		
	# Setup speed selector options
	speed_selector.clear()
	speed_selector.add_item("1x", 0)
	speed_selector.set_item_metadata(0, 1.0)
	speed_selector.add_item("5x", 1)
	speed_selector.set_item_metadata(1, 5.0)
	speed_selector.add_item("10x", 2)
	speed_selector.set_item_metadata(2, 10.0)
	speed_selector.add_item("30x", 3)
	speed_selector.set_item_metadata(3, 30.0)
	speed_selector.add_item("60x", 4)
	speed_selector.set_item_metadata(4, 60.0)
	speed_selector.select(0)
	
	# Connect signals
	pause_button.pressed.connect(_on_pause_pressed)
	play_button.pressed.connect(_on_play_pressed)
	step_button.pressed.connect(_on_step_pressed)
	speed_selector.item_selected.connect(_on_speed_selected)

func _process(_delta: float) -> void:
	if _host != null:
		var current_tick: int = _host.get_current_tick()
		var speed: float = _host.get_speed_multiplier()
		tick_label.text = "Tick: %d" % current_tick
		
		if speed == 0.0:
			pause_button.disabled = true
			play_button.disabled = false
			step_button.disabled = false
		else:
			pause_button.disabled = false
			play_button.disabled = true
			step_button.disabled = true

func _find_simulation_host(node: Node) -> Node:
	# Check class_name or name
	if node.get_class() == "SimulationHost" or node.name == "SimulationHost":
		return node
	for child in node.get_children():
		var found: Node = _find_simulation_host(child)
		if found != null:
			return found
	return null

func _on_pause_pressed() -> void:
	if _host != null:
		_host.pause()

func _on_play_pressed() -> void:
	if _host != null:
		var speed = speed_selector.get_item_metadata(speed_selector.selected)
		_host.resume(speed)

func _on_step_pressed() -> void:
	if _host != null:
		_host.step()

func _on_speed_selected(index: int) -> void:
	var speed = speed_selector.get_item_metadata(index)
	if _host != null and _host.get_speed_multiplier() > 0.0:
		_host.set_speed(speed)
