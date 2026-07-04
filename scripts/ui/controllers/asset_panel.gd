class_name AssetPanel
extends Control

@export var selected_unit_id: StringName = &"BASIN_01"

@onready var title_label: Label = get_node_or_null("PanelContainer/VBoxContainer/TitleLabel")
@onready var state_label: Label = get_node_or_null("PanelContainer/VBoxContainer/StateValue")
@onready var level_label: Label = get_node_or_null("PanelContainer/VBoxContainer/LevelValue")
@onready var volume_label: Label = get_node_or_null("PanelContainer/VBoxContainer/VolumeValue")
@onready var inflow_label: Label = get_node_or_null("PanelContainer/VBoxContainer/InflowValue")
@onready var outflow_label: Label = get_node_or_null("PanelContainer/VBoxContainer/OutflowValue")
@onready var spill_label: Label = get_node_or_null("PanelContainer/VBoxContainer/SpillValue")

@onready var inlet_slider: HSlider = get_node_or_null("PanelContainer/VBoxContainer/InletSlider")
@onready var outlet_slider: HSlider = get_node_or_null("PanelContainer/VBoxContainer/OutletSlider")
@onready var drain_slider: HSlider = get_node_or_null("PanelContainer/VBoxContainer/DrainSlider")

@onready var inlet_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/InletValueLabel")
@onready var outlet_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/OutletValueLabel")
@onready var drain_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/DrainValueLabel")

var _updating_sliders: bool = false

func _ready() -> void:
	if inlet_slider != null:
		inlet_slider.value_changed.connect(_on_inlet_slider_changed)
	if outlet_slider != null:
		outlet_slider.value_changed.connect(_on_outlet_slider_changed)
	if drain_slider != null:
		drain_slider.value_changed.connect(_on_drain_slider_changed)

func _process(_delta: float) -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
		
	var snap: Dictionary = host.engine.latest_snapshot
	if snap.is_empty() or not snap.units.has(selected_unit_id):
		return
		
	var unit_snap: Dictionary = snap.units[selected_unit_id]
	
	if title_label != null:
		title_label.text = String(unit_snap.get("display_name", selected_unit_id))
	if state_label != null:
		state_label.text = String(unit_snap.get("operating_state", "IN_SERVICE"))
	
	var lvl: float = float(unit_snap.get("level_m", 0.0))
	var vol: float = float(unit_snap.get("volume_m3", 0.0))
	var inflow: float = float(unit_snap.get("inflow_m3s", 0.0))
	var outflow: float = float(unit_snap.get("outflow_m3s", 0.0))
	var spill: float = float(unit_snap.get("spill_flow_m3s", 0.0))
	
	if level_label != null:
		level_label.text = DisplayUnits.format_level(lvl)
	if volume_label != null:
		volume_label.text = DisplayUnits.format_volume(vol)
	if inflow_label != null:
		inflow_label.text = DisplayUnits.format_flow(inflow)
	if outflow_label != null:
		outflow_label.text = DisplayUnits.format_flow(outflow)
	if spill_label != null:
		spill_label.text = DisplayUnits.format_flow(spill)
		
	_updating_sliders = true
	var act_in = snap.actuators.get(&"VALVE_IN")
	if act_in != null and inlet_slider != null:
		inlet_slider.value = float(act_in.get("position", 0.0))
		if inlet_value_label != null:
			inlet_value_label.text = "%.0f%%" % inlet_slider.value
		
	var act_out = snap.actuators.get(&"VALVE_OUT")
	if act_out != null and outlet_slider != null:
		outlet_slider.value = float(act_out.get("position", 0.0))
		if outlet_value_label != null:
			outlet_value_label.text = "%.0f%%" % outlet_slider.value
		
	var act_drain = snap.actuators.get(&"VALVE_DRAIN")
	if act_drain != null and drain_slider != null:
		drain_slider.value = float(act_drain.get("position", 0.0))
		if drain_value_label != null:
			drain_value_label.text = "%.0f%%" % drain_slider.value
	_updating_sliders = false

func _on_inlet_slider_changed(val: float) -> void:
	if _updating_sliders:
		return
	CommandBus.submit(SetValvePositionCommand.new(&"VALVE_IN", val))

func _on_outlet_slider_changed(val: float) -> void:
	if _updating_sliders:
		return
	CommandBus.submit(SetValvePositionCommand.new(&"VALVE_OUT", val))

func _on_drain_slider_changed(val: float) -> void:
	if _updating_sliders:
		return
	CommandBus.submit(SetValvePositionCommand.new(&"VALVE_DRAIN", val))
