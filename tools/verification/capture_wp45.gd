extends SceneTree

var _capture_prefix := "wp45"
var _capture_low := false

# Run with a graphical Godot build. Captures the actual main scene at startup,
# during a high-level alarm, and after clearing with all five basins unavailable.
# Hydraulic calculations and alarm evaluation remain in the production engine.
func _initialize() -> void:
    if "--wp47" in OS.get_cmdline_user_args():
        _capture_prefix = "wp47"
    _capture_low = "--wp47-low" in OS.get_cmdline_user_args()
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
    if _capture_low:
        var activations := 0
        for _tick in range(5):
            for event in host.engine.advance_frame(1.0):
                if event.event_type == &"AlarmActivated" and event.payload.alarm_id == &"APPLIED_CHANNEL_LOW_LEVEL":
                    activations += 1
        panel.refresh_from_snapshot()
        if not host.engine.latest_snapshot.alarms[&"APPLIED_CHANNEL_LOW_LEVEL"].is_active or activations != 1:
            push_error("A valid empty-channel startup must raise the low alarm once")
            quit(1)
            return
        if not await _save_frame("res://docs/images/wp47-low-alarm.png"):
            quit(1)
            return
        print("WP4.7 main scene low alarm: one activation, tick 5, level %.3f m, ledger residual %.12f m3." % [
            host.engine.latest_snapshot.units[&"APPLIED_CHANNEL_01"].level_m,
            host.engine.latest_snapshot.plant_totals.mass_balance_error_m3])
        scene.queue_free()
        await process_frame
        quit(0)
        return
    if not await _save_frame("res://docs/images/%s-startup.png" % _capture_prefix):
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
    if not await _save_frame("res://docs/images/%s-high-alarm.png" % _capture_prefix):
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
    if not await _save_frame("res://docs/images/%s-cleared-outage.png" % _capture_prefix):
        quit(1)
        return
    for unit in host.engine.context.units_list:
        if unit is StorageUnit and unit.volume_m3 < 0.0:
            push_error("Rendered main scene contains negative storage")
            quit(1)
            return
    print("%s rendered main scene: startup, high alarm, clearing, five-basin outage verified." % _capture_prefix)
    print("Final tick %d, mass-balance residual %.12f m3, no negative storage." % [
        host.engine.context.current_tick, host.engine.latest_snapshot.plant_totals.mass_balance_error_m3])
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
