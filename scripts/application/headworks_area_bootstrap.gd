extends Node3D

const PLANT_ID := "phase3_headworks"
const PRESENTATION_MAP_PATH := "res://config/plants/phase3_headworks/presentation_map.json"

func _ready() -> void:
	print("Sunol FlowLab Bootstrapping - Phase 3 Headworks")
	var host: SimulationHost = get_node_or_null("SimulationHost")
	var presenter: HeadworksPresentationAdapter = get_node_or_null("HeadworksPresentation")
	var alarm_panel: AlarmPanel = get_node_or_null("CanvasLayer/AlarmPanel")
	if host == null:
		push_error("SimulationHost not found in HeadworksArea scene")
		return
	if presenter == null:
		push_error("HeadworksPresentation not found in HeadworksArea scene")
		return
	if alarm_panel == null:
		push_error("AlarmPanel not found in HeadworksArea scene")
		return

	host.engine.snapshot_mode = SimulationEngine.SNAPSHOT_MODE_PUBLISH_LIGHT

	var config: Dictionary = ConfigLoader.load_plant_config(PLANT_ID)
	if not config.success:
		push_error("Failed to load %s configuration" % PLANT_ID)
		return

	var build_ok: bool = PlantFactory.build_plant(
		host.engine.context,
		config.topology_data,
		config.initial_conditions_data,
		config.controllers_data
	)
	if not build_ok:
		push_error("Failed to build %s plant" % PLANT_ID)
		return

	for alarm_config in config.alarms_data.get("alarms", []):
		var alarm := ThresholdAlarm.new()
		alarm.initialize(alarm_config)
		host.engine.alarm_engine.register_alarm(alarm)

	var presentation_map: Dictionary = PresentationMapHandler.load_map(PRESENTATION_MAP_PATH)
	if presentation_map.is_empty():
		push_error("Failed to load presentation map at %s" % PRESENTATION_MAP_PATH)
		return

	presenter.configure(host.engine, config.topology_data, presentation_map)
	alarm_panel.configure(host.engine)

	# Seed the first frame so the scene is populated before the first tick advances.
	host.engine.latest_snapshot = SnapshotService.take_snapshot(
		host.engine.context,
		host.engine,
		false
	)
	presenter.refresh_from_snapshot()
	alarm_panel.refresh_from_snapshot()

	# Check for command line argument to capture a screenshot and exit
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--screenshot="):
			var path := arg.split("=")[1]
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var image := get_viewport().get_texture().get_image()
			var err := image.save_png(path)
			if err == OK:
				print("Screenshot saved successfully to: %s" % path)
			else:
				push_error("Failed to save screenshot to %s, error: %d" % [path, err])
			get_tree().quit()
