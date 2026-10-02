extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Visual capture requires a graphical renderer")
        quit(1)
        return
    var scene: Node3D = load("res://scenes/plant/headworks_area.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    var host: SimulationHost = scene.get_node("SimulationHost")
    host.set_process(false)
    for _tick in range(120):
        host.engine.advance_frame(1.0)
    await _save("res://docs/images/headworks-visual-preview.png")
    var camera: Camera3D = scene.get_node("HeadworksCameraRig")
    var presenter: HeadworksPresentationAdapter = scene.get_node("HeadworksPresentation")
    var basin: HeadworksUnitVisual = presenter.get_node("BASIN_04Visual")
    # Exercise actual viewport picking, rather than directly setting the inspector.
    var click := InputEventMouseButton.new()
    click.position = camera.unproject_position(basin.global_position + Vector3(0, 2, 0))
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    Input.parse_input_event(click)
    await physics_frame
    await physics_frame
    await process_frame
    click = click.duplicate()
    click.pressed = false
    Input.parse_input_event(click)
    await process_frame
    var inspector: AssetPanel = scene.get_node("CanvasLayer/AssetPanel")
    if inspector.selected_unit_id != &"BASIN_04":
        push_error("Viewport click did not select Basin 4")
        quit(1)
        return
    print("Viewport picking: Basin 4 inspector and highlight verified.")
    host.engine.enqueue(SetBasinServiceCommand.new(&"BASIN_04", false))
    host.engine.enqueue(SetValvePositionCommand.new(&"VALVE_DRAIN_BASIN_04", 100.0))
    for _tick in range(80):
        host.engine.advance_frame(1.0)
    await _save("res://docs/images/headworks-visual-offline.png")
    print("Visual preview captured: running plant and Basin 4 offline, tick %d." % host.engine.context.current_tick)
    scene.queue_free()
    await process_frame
    quit(0)

func _save(path: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png(path)
    if error != OK:
        push_error("Screenshot failed: %s" % path)
        quit(1)
    print("Captured %s" % path)
