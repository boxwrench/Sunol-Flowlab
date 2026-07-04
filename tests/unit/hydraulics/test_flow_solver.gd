extends "res://addons/gut/test.gd"

func _create_storage_unit(unit_id: StringName, vol: float, area: float, min_level: float) -> StorageUnit:
	var unit := StorageUnit.new()
	unit.initialize({
		"unit_id": unit_id,
		"display_name": "Test Basin",
		"type": "StorageUnit",
		"maximum_volume_m3": 1000.0,
		"surface_area_m2": area,
		"bottom_elevation_m": 0.0,
		"high_level_m": 10.0,
		"spill_level_m": 10.0,
		"min_operating_level_m": min_level,
		"initial_volume_m3": vol,
		"spill_destination_id": "SPILL_SINK"
	})
	return unit

func _create_boundary(unit_id: StringName, type: StringName, limit: float = -1.0) -> ExternalBoundary:
	var boundary := ExternalBoundary.new()
	boundary.initialize({
		"unit_id": unit_id,
		"display_name": "Test Boundary",
		"type": "ExternalBoundary",
		"boundary_type": type,
		"flow_limit_m3s": limit
	})
	return boundary

func _connect_units(source: ProcessUnit, dest: ProcessUnit, src_port_id: StringName, dest_port_id: StringName, port_type: StringName, max_flow: float, link_id: StringName) -> FlowLink:
	var src_port := FlowPort.new(src_port_id, source, port_type)
	var dest_port := FlowPort.new(dest_port_id, dest, &"INLET")
	source.ports[src_port_id] = src_port
	dest.ports[dest_port_id] = dest_port
	
	var resolver := func(port_id: StringName) -> FlowPort:
		if port_id == src_port_id:
			return src_port
		if port_id == dest_port_id:
			return dest_port
		return null
		
	var link := FlowLink.new()
	link.initialize({
		"link_id": link_id,
		"max_flow_m3s": max_flow,
		"flow_mode": "RESTRICTED",
		"source_port_id": src_port_id,
		"destination_port_id": dest_port_id
	}, resolver)
	return link

func test_flow_solver_proration() -> void:
	var context := SimulationContext.new()
	context.dt = 1.0
	
	var source := _create_storage_unit(&"BASIN_01", 10.0, 1.0, 0.0)
	var sink_a := _create_boundary(&"SINK_A", &"TREATED_DEMAND")
	var sink_b := _create_boundary(&"SINK_B", &"TREATED_DEMAND")
	
	var link_a := _connect_units(source, sink_a, &"PORT_OUT_A", &"PORT_IN_A", &"OUTLET", 8.0, &"LINK_A")
	var link_b := _connect_units(source, sink_b, &"PORT_OUT_B", &"PORT_IN_B", &"OUTLET", 12.0, &"LINK_B")
	
	context.topological_units_list = [source, sink_a, sink_b]
	context.links_list = [link_a, link_b]
	
	FlowSolver.solve_flows(context)
	
	assert_eq(link_a.granted_flow_m3s, 4.0)
	assert_eq(link_b.granted_flow_m3s, 6.0)
	assert_eq(link_a.actual_flow_m3s, 4.0)
	assert_eq(link_b.actual_flow_m3s, 6.0)

func test_flow_solver_boundary_limits() -> void:
	var context := SimulationContext.new()
	context.dt = 1.0
	
	var source := _create_boundary(&"SOURCE", &"SOURCE_INFLOW", 5.0)
	var sink_a := _create_boundary(&"SINK_A", &"TREATED_DEMAND")
	var sink_b := _create_boundary(&"SINK_B", &"TREATED_DEMAND")
	
	var link_a := _connect_units(source, sink_a, &"PORT_OUT_A", &"PORT_IN_A", &"OUTLET", 4.0, &"LINK_A")
	var link_b := _connect_units(source, sink_b, &"PORT_OUT_B", &"PORT_IN_B", &"OUTLET", 6.0, &"LINK_B")
	
	context.topological_units_list = [source, sink_a, sink_b]
	context.links_list = [link_a, link_b]
	
	FlowSolver.solve_flows(context)
	
	assert_eq(link_a.granted_flow_m3s, 2.0)
	assert_eq(link_b.granted_flow_m3s, 3.0)
	assert_eq(link_a.actual_flow_m3s, 2.0)
	assert_eq(link_b.actual_flow_m3s, 3.0)

func test_flow_solver_outlet_vs_drain() -> void:
	var context := SimulationContext.new()
	context.dt = 1.0
	
	var source := _create_storage_unit(&"BASIN_01", 10.0, 10.0, 0.5)
	var sink_a := _create_boundary(&"SINK_A", &"TREATED_DEMAND")
	var sink_b := _create_boundary(&"SINK_B", &"DRAIN")
	
	var link_outlet := _connect_units(source, sink_a, &"PORT_OUTLET", &"PORT_IN_A", &"OUTLET", 8.0, &"LINK_OUTLET")
	var link_drain := _connect_units(source, sink_b, &"PORT_DRAIN", &"PORT_IN_B", &"DRAIN", 8.0, &"LINK_DRAIN")
	
	context.topological_units_list = [source, sink_a, sink_b]
	context.links_list = [link_outlet, link_drain]
	
	FlowSolver.solve_flows(context)
	
	assert_eq(link_outlet.granted_flow_m3s, 5.0)
	assert_eq(link_drain.granted_flow_m3s, 5.0)
	
	source.volume_m3 = 3.0
	FlowSolver.solve_flows(context)
	assert_eq(link_outlet.granted_flow_m3s, 0.0)
	assert_eq(link_drain.granted_flow_m3s, 3.0)

func test_flow_solver_defensive_assert() -> void:
	var context := SimulationContext.new()
	context.dt = 1.0
	
	var source := _create_storage_unit(&"BASIN_01", 10.0, 10.0, 0.5)
	var sink_a := _create_boundary(&"SINK_A", &"TREATED_DEMAND")
	var sink_b := _create_boundary(&"SINK_B", &"DRAIN")
	
	var link_outlet := _connect_units(source, sink_a, &"PORT_OUTLET", &"PORT_IN_A", &"OUTLET", 8.0, &"LINK_OUTLET")
	var link_drain := _connect_units(source, sink_b, &"PORT_DRAIN", &"PORT_IN_B", &"DRAIN", 8.0, &"LINK_DRAIN")
	
	context.topological_units_list = [source, sink_a, sink_b]
	context.links_list = [link_outlet, link_drain]
	
	FlowSolver.solve_flows(context)
	
	var inflows: Array[float] = []
	var min_vol: float = source.min_operating_level_m * source.surface_area_m2
	var max_vol: float = source.maximum_volume_m3
	var spill_vol: float = source.spill_level_m * source.surface_area_m2
	
	var res := StorageBalance.solve(
		source.volume_m3,
		inflows,
		link_outlet.granted_flow_m3s,
		link_drain.granted_flow_m3s,
		max_vol,
		spill_vol,
		min_vol,
		context.dt
	)
	
	assert_eq(res.new_volume_m3, 0.0)

func test_flow_solver_sink_limits() -> void:
	var context := SimulationContext.new()
	context.dt = 1.0
	
	var source_a := _create_boundary(&"SOURCE_A", &"SOURCE_INFLOW")
	var source_b := _create_boundary(&"SOURCE_B", &"SOURCE_INFLOW")
	var sink := _create_boundary(&"SINK", &"TREATED_DEMAND", 5.0)
	
	var link_a := _connect_units(source_a, sink, &"PORT_OUT_A", &"PORT_IN_A", &"OUTLET", 4.0, &"LINK_A")
	var link_b := _connect_units(source_b, sink, &"PORT_OUT_B", &"PORT_IN_B", &"OUTLET", 6.0, &"LINK_B")
	
	context.topological_units_list = [source_a, source_b, sink]
	context.links_list = [link_a, link_b]
	
	FlowSolver.solve_flows(context)
	
	assert_eq(link_a.granted_flow_m3s, 2.0)
	assert_eq(link_b.granted_flow_m3s, 3.0)
	assert_eq(link_a.actual_flow_m3s, 2.0)
	assert_eq(link_b.actual_flow_m3s, 3.0)

# ---------------------------------------------------------------------------
# WP2.2-R NEW TEST — F2.2-1
# Reproduce SIMULATION_RULES Worked Example 1 end-to-end:
#   Basin A volume 3.0 m³, two outlet links (max 4.0 and 2.0, both open),
#   run FlowSolver.solve_flows AND then StorageUnit.solve_tick.
#   Asserts:
#     * granted flows are prorated 2.0 / 1.0 (factor 0.5)
#     * new_volume == 0.0 (all water withdrawn)
#     * no water created: sum of granted outflows == basin's volume change
# A solver-only test hid this bug (Phase 2 review finding F2.2-1).
# ---------------------------------------------------------------------------
func test_multi_outlet_worked_example_1() -> void:
	var context := SimulationContext.new()
	context.dt = 1.0

	# Basin A: 3.0 m³, surface_area=1.0 m², no min_operating_level
	var basin := _create_storage_unit(&"BASIN_A", 3.0, 1.0, 0.0)

	var sink_1 := _create_boundary(&"SINK_1", &"TREATED_DEMAND")
	var sink_2 := _create_boundary(&"SINK_2", &"TREATED_DEMAND")

	# LINK_OUT_1: max 4.0 m³/s — requested = 4.0
	var link_out_1 := _connect_units(basin, sink_1, &"PORT_OUTLET_1", &"PORT_IN_1", &"OUTLET", 4.0, &"LINK_OUT_1")
	# LINK_OUT_2: max 2.0 m³/s — requested = 2.0
	var link_out_2 := _connect_units(basin, sink_2, &"PORT_OUTLET_2", &"PORT_IN_2", &"OUTLET", 2.0, &"LINK_OUT_2")

	context.topological_units_list = [basin, sink_1, sink_2]
	context.links_list = [link_out_1, link_out_2]

	# --- Pass 1 + 2 + final sweep ---
	FlowSolver.solve_flows(context)

	# Proration factor = 3.0 / 6.0 = 0.5
	assert_almost_eq(link_out_1.granted_flow_m3s, 2.0, 1e-9, "LINK_OUT_1 granted should be 2.0 m³/s")
	assert_almost_eq(link_out_2.granted_flow_m3s, 1.0, 1e-9, "LINK_OUT_2 granted should be 1.0 m³/s")
	assert_almost_eq(link_out_1.actual_flow_m3s,  2.0, 1e-9, "LINK_OUT_1 actual must equal granted")
	assert_almost_eq(link_out_2.actual_flow_m3s,  1.0, 1e-9, "LINK_OUT_2 actual must equal granted")

	# --- Integration: StorageUnit.solve_tick must account for BOTH outlets ---
	var volume_before: float = basin.volume_m3
	basin.solve_tick(context)

	# New volume must be exactly 0 (3.0 - 2.0 - 1.0 = 0.0)
	assert_almost_eq(basin.volume_m3, 0.0, 1e-9, "Basin volume after tick must be 0.0 m³")

	# No water created: volume withdrawn = volume change
	var volume_change: float = volume_before - basin.volume_m3
	var total_granted: float = link_out_1.granted_flow_m3s + link_out_2.granted_flow_m3s
	assert_almost_eq(
		total_granted * context.dt,
		volume_change,
		1e-9,
		"Sum of granted outflows * dt must equal basin volume change (mass conservation)"
	)

# ---------------------------------------------------------------------------
# WP2.2-R NEW TEST — F2.2-2
# A link that was flowing must carry zero on all three flow fields
# (requested, granted, actual) in the very next solve after is_enabled = false.
# The three-field check is required because only asserting actual_flow_m3s
# could miss a stale requested or granted value that a future path might read.
# ---------------------------------------------------------------------------
func test_disabled_link_zeroes_flows() -> void:
	var context := SimulationContext.new()
	context.dt = 1.0

	var source := _create_storage_unit(&"BASIN_01", 10.0, 1.0, 0.0)
	var sink := _create_boundary(&"SINK", &"TREATED_DEMAND")

	var link := _connect_units(source, sink, &"PORT_OUT", &"PORT_IN", &"OUTLET", 5.0, &"LINK_MAIN")
	context.topological_units_list = [source, sink]
	context.links_list = [link]

	# --- First solve: link enabled, expect nonzero flow ---
	FlowSolver.solve_flows(context)
	assert_gt(link.actual_flow_m3s, 0.0, "Link should carry nonzero flow when enabled")

	# --- Disable the link, solve again ---
	link.is_enabled = false
	FlowSolver.solve_flows(context)

	assert_eq(link.requested_flow_m3s, 0.0, "requested_flow_m3s must be 0 after disable")
	assert_eq(link.granted_flow_m3s,   0.0, "granted_flow_m3s must be 0 after disable")
	assert_eq(link.actual_flow_m3s,    0.0, "actual_flow_m3s must be 0 after disable")
