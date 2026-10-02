extends SceneTree

# Run with a graphical Godot build. Captures the actual main scene at startup,
# during a high-level alarm, and after clearing with all five basins unavailable.
# Hydraulic calculations and alarm evaluation remain in the production engine.
func _initialize() -> void:
    call_deferred("_capture_main_scene")

func _capture_main_scene() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("capture_wp45.gd requires a graphical renderer")
        quit(1)
        return
    var scene: Node3D = load("res://scenes/plant/headworks_area.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    var host: SimulationHost = scene.get_node("SimulationHost")
    host.set_process(false)
    var panel: AlarmPanel = scene.get_node("CanvasLayer/AlarmPanel")
    if host.engine.latest_snapshot.alarms.size() != 2:
        push_error("Startup must expose both configured alarms")
        quit(1)
        return
    if not await _save_frame("res://docs/images/wp45-startup.png"):
        quit(1)
        return

    var outlet: FlowLink = host.engine.context.links_dict[&"LINK_OUT_AC_01"]
    outlet.is_enabled = false
    for _tick in range(100):
        host.engine.advance_frame(1.0)
    panel.refresh_from_snapshot()
    if not host.engine.latest_snapshot.alarms[&"APPLIED_CHANNEL_HIGH_LEVEL"].is_active:
        push_error("Closing demand must raise the configured high-level alarm")
        quit(1)
        return
    if not await _save_frame("res://docs/images/wp45-high-alarm.png"):
        quit(1)
        return

    outlet.is_enabled = true
    for i in range(1, 6):
        host.engine.enqueue(SetBasinServiceCommand.new(StringName("BASIN_0%d" % i), false))
    for _tick in range(100):
        host.engine.advance_frame(1.0)
    panel.refresh_from_snapshot()
    if host.engine.latest_snapshot.alarms[&"APPLIED_CHANNEL_HIGH_LEVEL"].is_active:
        push_error("Restored demand with basins isolated must clear the high alarm")
        quit(1)
        return
    if not await _save_frame("res://docs/images/wp45-cleared-outage.png"):
        quit(1)
        return
    print("WP4.5 rendered main scene: startup, high alarm, clearing, five-basin outage verified.")
    scene.queue_free()
    await process_frame
    quit(0)

func _save_frame(path: String) -> bool:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png(path)
    if error != OK:
        push_error("Could not save %s (error %d)" % [path, error])
        return false
    print("Captured %s" % path)
    return true
