extends Node

# Autoload: Thin forwarder only. Exists outside simulation domain.
var _engine: RefCounted = null

func register_engine(engine: RefCounted) -> void:
	_engine = engine

func submit(cmd: SimulationCommand) -> void:
	if _engine != null:
		_engine.enqueue(cmd)
	else:
		push_error("CommandBus: No engine registered to handle command.")
