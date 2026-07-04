extends Node

# Autoload: Thin relay only. Exists outside simulation domain.
signal event_published(event: SimulationEvent)
signal event_batch_published(events: Array[SimulationEvent])

func publish_events(events: Array[SimulationEvent]) -> void:
	if events.is_empty():
		return
	event_batch_published.emit(events)
	for event in events:
		event_published.emit(event)
