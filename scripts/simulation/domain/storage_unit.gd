class_name StorageUnit
extends ProcessUnit

# Geometry / Configuration
var maximum_volume_m3: float = 0.0
var surface_area_m2: float = 0.0
var bottom_elevation_m: float = 0.0
var high_level_m: float = 0.0
var spill_level_m: float = 0.0
var min_operating_level_m: float = 0.0

# Stored state
var volume_m3: float = 0.0
var level_m: float = 0.0 # Height of water from bottom_elevation_m

# Current flows (for presentation/tracking)
var inflow_m3s: float = 0.0
var outflow_m3s: float = 0.0
var drain_flow_m3s: float = 0.0
var spill_flow_m3s: float = 0.0

# Ports dictionary (port_id -> FlowPort)
var ports: Dictionary = {}

func initialize(config: Dictionary) -> void:
	super.initialize(config)
	maximum_volume_m3 = float(config.get("maximum_volume_m3", 0.0))
	surface_area_m2 = float(config.get("surface_area_m2", 0.0))
	bottom_elevation_m = float(config.get("bottom_elevation_m", 0.0))
	high_level_m = float(config.get("high_level_m", 0.0))
	spill_level_m = float(config.get("spill_level_m", 0.0))
	min_operating_level_m = float(config.get("min_operating_level_m", 0.0))
	volume_m3 = float(config.get("initial_volume_m3", 0.0))
	update_level()

func update_level() -> void:
	if surface_area_m2 > 0.0:
		level_m = volume_m3 / surface_area_m2
	else:
		level_m = 0.0

func available_withdrawal_m3(_dt: float) -> float:
	return max(0.0, volume_m3)

func available_receiving_m3(_dt: float) -> float:
	return max(0.0, maximum_volume_m3 - volume_m3)

func get_snapshot() -> Dictionary:
	var snap: Dictionary = super.get_snapshot()
	snap.merge({
		"volume_m3": volume_m3,
		"level_m": level_m,
		"elevation_m": level_m + bottom_elevation_m,
		"inflow_m3s": inflow_m3s,
		"outflow_m3s": outflow_m3s,
		"drain_flow_m3s": drain_flow_m3s,
		"spill_flow_m3s": spill_flow_m3s
	})
	return snap

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = super.validate(context)
	if maximum_volume_m3 <= 0.0:
		errors.append("StorageUnit: maximum_volume_m3 must be positive")
	if surface_area_m2 <= 0.0:
		errors.append("StorageUnit: surface_area_m2 must be positive")
	if spill_level_m < 0.0:
		errors.append("StorageUnit: spill_level_m must be non-negative")
	return errors
