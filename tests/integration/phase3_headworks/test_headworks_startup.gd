extends "res://addons/gut/test.gd"

const MAIN_SCENE = preload("res://scenes/plant/headworks_area.tscn")
const STARTUP_VALVES: Array[StringName] = [
    &"VALVE_OUT_RES_01", &"VALVE_OUT_RES_02", &"VALVE_OUT_MAN_01", &"VALVE_OUT_FM_01"
]

func _build_headless(config: Dictionary) -> SimulationEngine:
    var engine := SimulationEngine.new()
    assert_true(PlantFactory.build_plant(engine.context, config.topology_data,
        config.initial_conditions_data, config.controllers_data))
    for alarm_config in config.alarms_data.get("alarms", []):
        var alarm := ThresholdAlarm.new()
        alarm.initialize(alarm_config)
        engine.alarm_engine.register_alarm(alarm)
    return engine

func _load_scene() -> Node3D:
    var scene: Node3D = MAIN_SCENE.instantiate()
    add_child_autofree(scene)
    # Tests advance the real engines explicitly; rendered frames must not add ticks.
    scene.process_mode = Node.PROCESS_MODE_DISABLED
    return scene

func _assert_snapshot_parity(headless: SimulationEngine, visual: SimulationEngine) -> void:
    assert_eq_deep(SnapshotService.take_snapshot(headless.context, headless),
        visual.latest_snapshot)

func test_configured_startup_matches_main_scene_before_first_tick() -> void:
    var config := ConfigLoader.load_plant_config("phase3_headworks")
    assert_true(config.success)
    var headless := _build_headless(config)
    var scene := _load_scene()
    var host: SimulationHost = scene.get_node("SimulationHost")
    assert_eq(host.engine.context.current_tick, 0)
    assert_eq(host.engine.command_queue.size(), 0, "Startup must not enqueue hidden scene commands")
    for actuator_id in STARTUP_VALVES:
        var valve: SimValve = headless.context.actuators_dict[actuator_id]
        assert_eq(valve.commanded_position, 80.0, "The demonstration target belongs in config")
        assert_eq(valve.position, 0.0, "Keep the configured actuator travel from closed")
    _assert_snapshot_parity(headless, host.engine)
    assert_eq(host.engine.latest_snapshot.alarms.size(), 2, "Both configured alarms must be published")
    assert_true(host.engine.latest_snapshot.alarms.has(&"APPLIED_CHANNEL_HIGH_LEVEL"))
    assert_true(host.engine.latest_snapshot.alarms.has(&"APPLIED_CHANNEL_LOW_LEVEL"))

func test_main_scene_parity_through_each_basin_outage_and_return() -> void:
    var headless := _build_headless(ConfigLoader.load_plant_config("phase3_headworks"))
    var scene := _load_scene()
    var host: SimulationHost = scene.get_node("SimulationHost")
    for _tick in range(30):
        headless.advance_frame(1.0)
        host.engine.advance_frame(1.0)
    _assert_snapshot_parity(headless, host.engine)
    for i in range(1, 6):
        var basin_id := StringName("BASIN_0%d" % i)
        for in_service in [false, true]:
            headless.enqueue(SetBasinServiceCommand.new(basin_id, in_service))
            host.engine.enqueue(SetBasinServiceCommand.new(basin_id, in_service))
            for _tick in range(20):
                headless.advance_frame(1.0)
                host.engine.advance_frame(1.0)
                _assert_snapshot_parity(headless, host.engine)
            var snap: Dictionary = host.engine.latest_snapshot
            assert_eq(snap.units[basin_id].in_service, in_service)
            if not in_service:
                assert_eq(snap.links[StringName("LINK_OUT_DB_0%d" % i)].actual_flow_m3s, 0.0)
                assert_eq(snap.links[StringName("LINK_OUT_BASIN_0%d" % i)].actual_flow_m3s, 0.0)
            for unit in host.engine.context.units_list:
                if unit is StorageUnit:
                    assert_gte(unit.volume_m3, 0.0, "Outages must not produce negative storage")
            assert_almost_eq(snap.plant_totals.mass_balance_error_m3, 0.0, 1e-7)

func test_configured_high_alarm_activates_once_and_clears_in_main_scene() -> void:
    var scene := _load_scene()
    var host: SimulationHost = scene.get_node("SimulationHost")
    var panel: Node = scene.get_node_or_null("CanvasLayer/AlarmPanel")
    assert_not_null(panel, "The main scene must present alarm state")
    if panel == null:
        return
    # Equipment inputs: close the demand link so the real solver fills the channel.
    var outlet: FlowLink = host.engine.context.links_dict[&"LINK_OUT_AC_01"]
    outlet.is_enabled = false
    var activations := 0
    for _tick in range(100):
        for event in host.engine.advance_frame(1.0):
            if event.event_type == &"AlarmActivated" and event.payload.alarm_id == &"APPLIED_CHANNEL_HIGH_LEVEL":
                activations += 1
    panel.refresh_from_snapshot()
    assert_eq(activations, 1, "A sustained violation must emit one activation")
    assert_true(host.engine.latest_snapshot.alarms[&"APPLIED_CHANNEL_HIGH_LEVEL"].is_active)
    assert_string_contains(panel.get_node("VBoxContainer/AlarmList").text,
        "[!] ACTIVE: Applied Channel High Level Alarm")
    assert_eq(panel.displayed_tick, host.engine.latest_snapshot.tick)
    outlet.is_enabled = true
    for i in range(1, 6):
        host.engine.enqueue(SetBasinServiceCommand.new(StringName("BASIN_0%d" % i), false))
    var clearings := 0
    for _tick in range(100):
        for event in host.engine.advance_frame(1.0):
            if event.event_type == &"AlarmCleared" and event.payload.alarm_id == &"APPLIED_CHANNEL_HIGH_LEVEL":
                clearings += 1
    panel.refresh_from_snapshot()
    assert_eq(clearings, 1, "Recovery must emit one clearing")
    assert_false(host.engine.latest_snapshot.alarms[&"APPLIED_CHANNEL_HIGH_LEVEL"].is_active)
    assert_string_contains(panel.get_node("VBoxContainer/AlarmList").text,
        "[OK] CLEAR: Applied Channel High Level Alarm")
    assert_almost_eq(host.engine.latest_snapshot.plant_totals.mass_balance_error_m3, 0.0, 1e-7)

func test_configured_low_alarm_from_empty_initial_channel() -> void:
    var config := ConfigLoader.load_plant_config("phase3_headworks")
    # Below the outlet cutoff is a valid initial condition. Normal demand stops at
    # 0.5 m and cannot itself empty the channel below the configured low threshold.
    for state in config.initial_conditions_data.unit_states:
        if state.unit_id == "APPLIED_CHANNEL_01":
            state.volume_m3 = 0.0
    for state in config.initial_conditions_data.actuator_states:
        if state.actuator_id in ["VALVE_OUT_BASIN_01", "VALVE_OUT_BASIN_02", "VALVE_OUT_BASIN_03", "VALVE_OUT_BASIN_04", "VALVE_OUT_BASIN_05"]:
            state.position = 0.0
            state.commanded_position = 0.0
    var engine := _build_headless(config)
    var activations := 0
    for _tick in range(5):
        for event in engine.advance_frame(1.0):
            if event.event_type == &"AlarmActivated" and event.payload.alarm_id == &"APPLIED_CHANNEL_LOW_LEVEL":
                activations += 1
    assert_eq(activations, 1)
    assert_true(engine.latest_snapshot.alarms[&"APPLIED_CHANNEL_LOW_LEVEL"].is_active)
    assert_eq(engine.latest_snapshot.units[&"APPLIED_CHANNEL_01"].volume_m3, 0.0)
    assert_almost_eq(engine.latest_snapshot.plant_totals.mass_balance_error_m3, 0.0, 1e-7)

func test_alarm_panel_reads_one_snapshot_without_mutation() -> void:
    var scene := _load_scene()
    var host: SimulationHost = scene.get_node("SimulationHost")
    var panel: AlarmPanel = scene.get_node("CanvasLayer/AlarmPanel")
    var snap: Dictionary = host.engine.latest_snapshot.duplicate(true)
    snap.tick = 123
    snap.alarms[&"APPLIED_CHANNEL_LOW_LEVEL"].is_active = true
    var original := snap.duplicate(true)
    panel.apply_snapshot(snap)
    assert_eq(panel.displayed_tick, 123)
    assert_eq(panel.title_label.text, "Alarms: 1 active | Tick: 123")
    assert_string_contains(panel.alarm_list.text, "[!] ACTIVE: Applied Channel Low Level Alarm")
    assert_string_contains(panel.alarm_list.text, "[OK] CLEAR: Applied Channel High Level Alarm")
    assert_eq_deep(snap, original)
    assert_false(host.engine.alarm_engine.alarms_dict[&"APPLIED_CHANNEL_LOW_LEVEL"].is_active,
        "Displaying a snapshot must not modify domain alarms")
    panel.refresh_from_snapshot()
    assert_eq(panel.displayed_tick, 0)
    assert_string_contains(panel.alarm_list.text, "[OK] CLEAR: Applied Channel Low Level Alarm")
