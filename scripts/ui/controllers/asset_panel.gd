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

@onready var inlet_label: Label = get_node_or_null("PanelContainer/VBoxContainer/InletLabel")
@onready var inlet_slider: HSlider = get_node_or_null("PanelContainer/VBoxContainer/InletSlider")
@onready var inlet_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/InletValueLabel")

@onready var outlet_label: Label = get_node_or_null("PanelContainer/VBoxContainer/OutletLabel")
@onready var outlet_slider: HSlider = get_node_or_null("PanelContainer/VBoxContainer/OutletSlider")
@onready var outlet_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/OutletValueLabel")

@onready var drain_label: Label = get_node_or_null("PanelContainer/VBoxContainer/DrainLabel")
@onready var drain_slider: HSlider = get_node_or_null("PanelContainer/VBoxContainer/DrainSlider")
@onready var drain_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/DrainValueLabel")

# Controller Section Nodes
@onready var controller_separator: HSeparator = get_node_or_null("PanelContainer/VBoxContainer/ControllerSeparator")
@onready var controller_label: Label = get_node_or_null("PanelContainer/VBoxContainer/ControllerLabel")
@onready var controller_mode_container: HBoxContainer = get_node_or_null("PanelContainer/VBoxContainer/ControllerModeContainer")
@onready var mode_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/ControllerModeContainer/ModeValueLabel")
@onready var toggle_mode_button: Button = get_node_or_null("PanelContainer/VBoxContainer/ControllerModeContainer/ToggleModeButton")
@onready var setpoint_container: HBoxContainer = get_node_or_null("PanelContainer/VBoxContainer/SetpointContainer")
@onready var setpoint_value_label: Label = get_node_or_null("PanelContainer/VBoxContainer/SetpointContainer/SetpointValueLabel")
@onready var increase_setpoint_button: Button = get_node_or_null("PanelContainer/VBoxContainer/SetpointContainer/IncreaseSetpointButton")
@onready var decrease_setpoint_button: Button = get_node_or_null("PanelContainer/VBoxContainer/SetpointContainer/DecreaseSetpointButton")
@onready var controller_params_label: Label = get_node_or_null("PanelContainer/VBoxContainer/ControllerParamsLabel")

var _updating_sliders: bool = false
var _current_inlet_actuator: SimValve = null
var _current_outlet_actuator: SimValve = null
var _current_drain_actuator: SimValve = null

func _ready() -> void:
	if inlet_slider != null:
		inlet_slider.value_changed.connect(_on_inlet_slider_changed)
	if outlet_slider != null:
		outlet_slider.value_changed.connect(_on_outlet_slider_changed)
	if drain_slider != null:
		drain_slider.value_changed.connect(_on_drain_slider_changed)
		
	if toggle_mode_button != null:
		toggle_mode_button.pressed.connect(_on_toggle_mode_pressed)
	if increase_setpoint_button != null:
		increase_setpoint_button.pressed.connect(_on_increase_setpoint_pressed)
	if decrease_setpoint_button != null:
		decrease_setpoint_button.pressed.connect(_on_decrease_setpoint_pressed)

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
		
	# Find actuators connected to the selected unit dynamically
	_current_inlet_actuator = null
	_current_outlet_actuator = null
	_current_drain_actuator = null
	
	for link in host.engine.context.links_list:
		if link.destination_port != null and link.destination_port.parent_unit.unit_id == selected_unit_id:
			if link.actuator != null:
				_current_inlet_actuator = link.actuator
		if link.source_port != null and link.source_port.parent_unit.unit_id == selected_unit_id:
			if link.source_port.port_type == &"OUTLET":
				if link.actuator != null:
					_current_outlet_actuator = link.actuator
			elif link.source_port.port_type == &"DRAIN":
				if link.actuator != null:
					_current_drain_actuator = link.actuator

	_updating_sliders = true
	
	# Inlet Section
	var has_inlet: bool = (_current_inlet_actuator != null)
	if inlet_label != null:
		inlet_label.visible = has_inlet
	if inlet_slider != null:
		inlet_slider.visible = has_inlet
		if has_inlet:
			var act_in = snap.actuators.get(_current_inlet_actuator.actuator_id)
			if act_in != null:
				inlet_slider.value = float(act_in.get("position", 0.0))
				if inlet_value_label != null:
					inlet_value_label.text = "%.0f%%" % inlet_slider.value
	if inlet_value_label != null:
		inlet_value_label.visible = has_inlet

	# Outlet Section
	var has_outlet: bool = (_current_outlet_actuator != null)
	if outlet_label != null:
		outlet_label.visible = has_outlet
	if outlet_slider != null:
		outlet_slider.visible = has_outlet
		if has_outlet:
			var act_out = snap.actuators.get(_current_outlet_actuator.actuator_id)
			if act_out != null:
				outlet_slider.value = float(act_out.get("position", 0.0))
				if outlet_value_label != null:
					outlet_value_label.text = "%.0f%%" % outlet_slider.value
	if outlet_value_label != null:
		outlet_value_label.visible = has_outlet

	# Drain Section
	var has_drain: bool = (_current_drain_actuator != null)
	if drain_label != null:
		drain_label.visible = has_drain
	if drain_slider != null:
		drain_slider.visible = has_drain
		if has_drain:
			var act_drain = snap.actuators.get(_current_drain_actuator.actuator_id)
			if act_drain != null:
				drain_slider.value = float(act_drain.get("position", 0.0))
				if drain_value_label != null:
					drain_value_label.text = "%.0f%%" % drain_slider.value
	if drain_value_label != null:
		drain_value_label.visible = has_drain
		
	_updating_sliders = false

	# Controller Section
	var unit_controller: SimController = _find_selected_controller(host)
	var has_controller: bool = (unit_controller != null)
	
	if controller_separator != null:
		controller_separator.visible = has_controller
	if controller_label != null:
		controller_label.visible = has_controller
	if controller_mode_container != null:
		controller_mode_container.visible = has_controller
	if setpoint_container != null:
		setpoint_container.visible = has_controller
	if controller_params_label != null:
		controller_params_label.visible = has_controller
		
	if has_controller and unit_controller != null:
		var ctrl_snap = snap.controllers.get(unit_controller.controller_id, {})
		if not ctrl_snap.is_empty():
			var mode_str = String(ctrl_snap.get("control_mode", "MANUAL"))
			var sp_val = float(ctrl_snap.get("setpoint", 0.0))
			var gain_val = float(ctrl_snap.get("gain", 1.0))
			var db_val = float(ctrl_snap.get("deadband_m", 0.0))
			
			if mode_value_label != null:
				mode_value_label.text = mode_str
			if setpoint_value_label != null:
				setpoint_value_label.text = DisplayUnits.format_level(sp_val)
			if controller_params_label != null:
				controller_params_label.text = "Gain: %.1f  Deadband: %.2fm" % [gain_val, db_val]

func _on_inlet_slider_changed(val: float) -> void:
	if _updating_sliders or _current_inlet_actuator == null:
		return
	CommandBus.submit(SetValvePositionCommand.new(_current_inlet_actuator.actuator_id, val))

func _on_outlet_slider_changed(val: float) -> void:
	if _updating_sliders or _current_outlet_actuator == null:
		return
	CommandBus.submit(SetValvePositionCommand.new(_current_outlet_actuator.actuator_id, val))

func _on_drain_slider_changed(val: float) -> void:
	if _updating_sliders or _current_drain_actuator == null:
		return
	CommandBus.submit(SetValvePositionCommand.new(_current_drain_actuator.actuator_id, val))

func _on_toggle_mode_pressed() -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
	var unit_controller = _find_selected_controller(host)
	if unit_controller != null:
		var current_mode = unit_controller.control_mode
		var new_mode = &"AUTO" if current_mode == &"MANUAL" else &"MANUAL"
		CommandBus.submit(SetControllerModeCommand.new(unit_controller.controller_id, new_mode))

func _on_increase_setpoint_pressed() -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
	var unit_controller = _find_selected_controller(host)
	if unit_controller != null and "setpoint" in unit_controller:
		var new_sp = unit_controller.setpoint + 0.25
		CommandBus.submit(SetLevelSetpointCommand.new(unit_controller.controller_id, new_sp))

func _on_decrease_setpoint_pressed() -> void:
	var host: SimulationHost = get_tree().current_scene.find_child("SimulationHost", true, false) as SimulationHost
	if host == null or host.engine == null:
		return
	var unit_controller = _find_selected_controller(host)
	if unit_controller != null and "setpoint" in unit_controller:
		var new_sp = max(0.0, unit_controller.setpoint - 0.25)
		CommandBus.submit(SetLevelSetpointCommand.new(unit_controller.controller_id, new_sp))

func _find_selected_controller(host: SimulationHost) -> SimController:
	for ctrl in host.engine.context.controllers_list:
		if ctrl.pv_unit_id == selected_unit_id:
			return ctrl
	return null
