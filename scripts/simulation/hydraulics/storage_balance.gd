class_name StorageBalance
extends RefCounted

const EPSILON: float = 1e-9

# ---------------------------------------------------------------------------
# solve()
#
# Integrates a single StorageUnit over one fixed time-step.
# Parameters:
#   current_volume_m3        — volume at start of tick
#   inflows_m3s              — array of granted inflow rates [m³/s]
#   requested_outflow_m3s    — granted flow on the OUTLET link [m³/s]
#   requested_drain_flow_m3s — granted flow on the DRAIN link [m³/s]
#   max_volume_m3            — physical capacity of the unit
#   spill_volume_m3          — volume at which passive spill begins
#   min_outlet_volume_m3     — volume below which OUTLET flow is zero
#                              (= min_operating_level_m * surface_area_m2)
#   dt                       — tick duration [s]
#
# Edge Rule 2 (defensive backstop): In debug builds this function asserts
# that FlowSolver has already ensured total granted withdrawals ≤ available
# supply. If the assert fires the solver has a grant-leak bug.
# ---------------------------------------------------------------------------
static func solve(
	current_volume_m3: float,
	inflows_m3s: Array[float],
	requested_outflow_m3s: float,
	requested_drain_flow_m3s: float,
	max_volume_m3: float,
	spill_volume_m3: float,
	min_outlet_volume_m3: float,
	dt: float
) -> Dictionary:
	# a) Sum granted inflows
	var total_inflow_m3s: float = 0.0
	for flow in inflows_m3s:
		total_inflow_m3s += flow

	var inflow_volume: float = total_inflow_m3s * dt

	# b) Compute tier-specific available volumes (matching FlowSolver definitions,
	#    Edge Rule 3): OUTLET draws only above min_outlet_volume_m3; DRAIN draws
	#    from total volume.
	var outlet_available_volume: float = max(0.0, current_volume_m3 - min_outlet_volume_m3) + inflow_volume
	var total_available_volume: float = max(0.0, current_volume_m3) + inflow_volume

	# c) Edge Rule 2 defensive assert: FlowSolver should have already prorated so
	#    granted withdrawals never exceed the available supply. If this triggers it
	#    is a solver bug, not a balance error.
	var requested_outflow_vol: float = requested_outflow_m3s * dt
	var requested_drain_vol: float = requested_drain_flow_m3s * dt
	assert(
		requested_outflow_vol <= outlet_available_volume + EPSILON,
		"StorageBalance: OUTLET grant (%f m³) exceeds outlet supply (%f m³) — solver grant leak." \
		% [requested_outflow_vol, outlet_available_volume]
	)
	assert(
		requested_outflow_vol + requested_drain_vol <= total_available_volume + EPSILON,
		"StorageBalance: total withdrawal grant (%f m³) exceeds total supply (%f m³) — solver grant leak." \
		% [requested_outflow_vol + requested_drain_vol, total_available_volume]
	)

	# d) Accept grants as actuals (FlowSolver guarantees they fit)
	var actual_outflow_m3s: float = requested_outflow_m3s
	var actual_drain_flow_m3s: float = requested_drain_flow_m3s

	# e) Integrate
	var actual_outflow_volume: float = actual_outflow_m3s * dt
	var actual_drain_volume: float = actual_drain_flow_m3s * dt
	var new_volume_m3: float = current_volume_m3 + inflow_volume \
		- actual_outflow_volume - actual_drain_volume

	# f) Passive spill
	var actual_spill_flow_m3s: float = 0.0
	if new_volume_m3 > spill_volume_m3:
		var excess_volume: float = new_volume_m3 - spill_volume_m3
		actual_spill_flow_m3s = excess_volume / dt
		new_volume_m3 = spill_volume_m3

	# g) Clamp sub-epsilon residuals to exactly zero (guardrail 9: ledgered clamp)
	if new_volume_m3 < EPSILON:
		new_volume_m3 = 0.0

	assert(new_volume_m3 <= max_volume_m3 + EPSILON, "StorageBalance: volume exceeded maximum volume")

	return {
		"new_volume_m3": new_volume_m3,
		"actual_inflow_m3s": total_inflow_m3s,
		"actual_outflow_m3s": actual_outflow_m3s,
		"actual_drain_flow_m3s": actual_drain_flow_m3s,
		"actual_spill_flow_m3s": actual_spill_flow_m3s
	}
