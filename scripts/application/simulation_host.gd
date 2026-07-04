class_name SimulationHost
extends Node

var engine: SimulationEngine

func _ready() -> void:
	engine = SimulationEngine.new()
	
	# Register the engine with the CommandBus autoload
	var command_bus = get_node_or_null("/root/CommandBus")
	if command_bus != null:
		command_bus.register_engine(engine)
	else:
		push_error("SimulationHost: CommandBus Autoload not found.")

func _process(delta: float) -> void:
	var events: Array[SimulationEvent] = engine.advance_frame(delta)
	
	# Publish any events occurred during this frame's ticks
	if not events.is_empty():
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.publish_events(events)

func set_speed(speed: float) -> void:
	engine.clock.set_speed(speed)

func pause() -> void:
	engine.clock.pause()

func resume(speed: float = 1.0) -> void:
	engine.clock.resume(speed)

func step() -> void:
	engine.clock.request_single_step()

func get_current_tick() -> int:
	return engine.context.current_tick

func get_speed_multiplier() -> float:
	return engine.clock.speed_multiplier
