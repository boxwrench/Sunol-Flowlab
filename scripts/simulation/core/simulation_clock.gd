class_name SimulationClock
extends RefCounted

const MAX_TICKS_PER_FRAME: int = 240

var dt_s: float = 1.0
var tick_count: int = 0
var speed_multiplier: float = 1.0 # 0.0 = paused

var accumulator_s: float = 0.0
var single_step: bool = false

func set_speed(speed: float) -> void:
	speed_multiplier = max(0.0, speed)

func pause() -> void:
	speed_multiplier = 0.0

func resume(speed: float = 1.0) -> void:
	speed_multiplier = speed

func request_single_step() -> void:
	single_step = true

func advance(frame_delta_s: float, tick_callable: Callable) -> int:
	if single_step:
		single_step = false
		tick_count += 1
		tick_callable.call(dt_s)
		return 1

	if speed_multiplier <= 0.0:
		return 0

	accumulator_s += frame_delta_s * speed_multiplier
	var ticks_run: int = 0
	
	while accumulator_s >= dt_s:
		if ticks_run >= MAX_TICKS_PER_FRAME:
			# Prevent spiral of death by capping ticks per frame
			accumulator_s = 0.0
			break
			
		tick_count += 1
		ticks_run += 1
		tick_callable.call(dt_s)
		accumulator_s -= dt_s
		
	return ticks_run
