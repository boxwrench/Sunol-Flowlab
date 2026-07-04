class_name StorageUnit
extends ProcessUnit

# Geometry / Configuration
var maximum_volume_m3: float = 0.0
var surface_area_m2: float = 0.0
var bottom_elevation_m: float = 0.0
var high_level_m: float = 0.0
var spill_level_m: float = 0.0
var min_operating_level_m: float = 0.0

# Spill routing — must be set from config; validator errors if unresolvable (Edge Rule 5)
var spill_destination_id: StringName = &""

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
	spill_destination_id = StringName(config.get("spill_destination_id", ""))
	volume_m3 = float(config.get("initial_volume_m3", 0.0))
	update_level()

func set_in_service(p_in_service: bool) -> void:
	super.set_in_service(p_in_service)
	for port in ports.values():
		if port.connected_link != null:
			var port_type: StringName = port.port_type
			if port_type == &"INLET" or port_type == &"OUTLET":
				port.connected_link.is_enabled = p_in_service

func update_level() -> void:
	if surface_area_m2 > 0.0:
		level_m = volume_m3 / surface_area_m2
	else:
		level_m = 0.0

# Volume available to DRAIN ports (down to zero, Edge Rule 3)
func available_withdrawal_m3(_dt: float) -> float:
	return max(0.0, volume_m3)

# F2.2-4 canonical min-vol computation — the ONE production location for
# min_operating_level_m * surface_area_m2. Both the accessor and solve_tick
# call this; the FlowSolver calls available_outlet_withdrawal_m3 which delegates here.
func get_min_outlet_volume_m3() -> float:
	return min_operating_level_m * surface_area_m2

# Volume available to OUTLET ports only (above low-low cutoff, Edge Rule 3)
func available_outlet_withdrawal_m3(_dt: float) -> float:
	return max(0.0, volume_m3 - get_min_outlet_volume_m3())

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
		"spill_flow_m3s": spill_flow_m3s,
		"spill_destination_id": spill_destination_id
	})
	return snap

func solve_tick(context: RefCounted) -> void:
	var dt: float = context.dt

	var inflows_arr: Array[float] = []
	# F2.2-1: sum per-type using += so every outlet/drain link contributes.
	# Iterate in sorted port_id order for determinism (SIMULATION_RULES §Determinism Mechanics rule 3).
	var requested_outflow: float = 0.0
	var requested_drain: float = 0.0

	var sorted_port_ids: Array = ports.keys()
	sorted_port_ids.sort()

	for port_id in sorted_port_ids:
		var port: FlowPort = ports[port_id]
		var link: FlowLink = port.connected_link
		if link == null:
			continue

		# Edge Rule 2 debug assert: FlowSolver's final sweep must have written
		# actual_flow_m3s = granted_flow_m3s before solve_tick() is called.
		assert(
			abs(link.actual_flow_m3s - link.granted_flow_m3s) < 1e-9,
			"StorageUnit '%s': link '%s' actual_flow_m3s (%f) != granted_flow_m3s (%f) — FlowSolver final sweep did not run." \
			% [unit_id, link.link_id, link.actual_flow_m3s, link.granted_flow_m3s]
		)

		if port.port_type == &"INLET":
			inflows_arr.append(link.actual_flow_m3s)
		elif port.port_type == &"OUTLET":
			# F2.2-1: += so multiple OUTLET links are all summed (not overwritten)
			requested_outflow += link.actual_flow_m3s
		elif port.port_type == &"DRAIN":
			# F2.2-1: += so multiple DRAIN links are all summed (not overwritten)
			requested_drain += link.actual_flow_m3s

	# F2.2-4: min_vol uses get_min_outlet_volume_m3() — the canonical single production
	# location for min_operating_level_m * surface_area_m2 (guardrail 5, Edge Rule 3).
	var spill_vol: float = spill_level_m * surface_area_m2
	var min_vol: float = get_min_outlet_volume_m3()

	var balance: Dictionary = StorageBalance.solve(
		volume_m3,
		inflows_arr,
		requested_outflow,
		requested_drain,
		maximum_volume_m3,
		spill_vol,
		min_vol,
		dt
	)

	volume_m3 = balance.new_volume_m3
	update_level()

	inflow_m3s = balance.actual_inflow_m3s
	outflow_m3s = balance.actual_outflow_m3s
	drain_flow_m3s = balance.actual_drain_flow_m3s
	spill_flow_m3s = balance.actual_spill_flow_m3s

	# actual_flow_m3s on outlet/drain links is already set by FlowSolver's final
	# sweep; no further write is needed here.


func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = super.validate(context)
	if maximum_volume_m3 <= 0.0:
		errors.append("StorageUnit: maximum_volume_m3 must be positive")
	if surface_area_m2 <= 0.0:
		errors.append("StorageUnit: surface_area_m2 must be positive")
	if spill_level_m < 0.0:
		errors.append("StorageUnit: spill_level_m must be non-negative")
	return errors
