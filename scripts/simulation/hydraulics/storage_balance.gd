class_name StorageBalance
extends RefCounted

const EPSILON: float = 1e-9

static func solve(
	current_volume_m3: float,
	inflows_m3s: Array[float],
	requested_outflow_m3s: float,
	requested_drain_flow_m3s: float,
	max_volume_m3: float,
	spill_volume_m3: float,
	dt: float
) -> Dictionary:
	# a) sum granted inflows
	var total_inflow_m3s: float = 0.0
	for flow in inflows_m3s:
		total_inflow_m3s += flow
		
	var inflow_volume: float = total_inflow_m3s * dt
	var available_volume: float = current_volume_m3 + inflow_volume
	
	# b) sum requested withdrawals (outflow + drain)
	var total_requested_withdrawal_m3s: float = requested_outflow_m3s + requested_drain_flow_m3s
	var total_requested_withdrawal_volume: float = total_requested_withdrawal_m3s * dt
	
	var actual_outflow_m3s: float = requested_outflow_m3s
	var actual_drain_flow_m3s: float = requested_drain_flow_m3s
	
	# Prorate proportionally if total > available volume this tick
	if total_requested_withdrawal_volume > available_volume and total_requested_withdrawal_volume > 0.0:
		var proration_factor: float = available_volume / total_requested_withdrawal_volume
		actual_outflow_m3s = requested_outflow_m3s * proration_factor
		actual_drain_flow_m3s = requested_drain_flow_m3s * proration_factor
		
	var actual_outflow_volume: float = actual_outflow_m3s * dt
	var actual_drain_volume: float = actual_drain_flow_m3s * dt
	
	# c) integrate
	var new_volume_m3: float = current_volume_m3 + inflow_volume - actual_outflow_volume - actual_drain_volume
	
	# d) passive spill
	var actual_spill_flow_m3s: float = 0.0
	if new_volume_m3 > spill_volume_m3:
		var excess_volume: float = new_volume_m3 - spill_volume_m3
		actual_spill_flow_m3s = excess_volume / dt
		new_volume_m3 = spill_volume_m3
		
	# e) clamp [0, epsilon) to exactly 0
	if new_volume_m3 < EPSILON:
		new_volume_m3 = 0.0
		
	assert(new_volume_m3 <= max_volume_m3 + EPSILON, "Volume exceeded maximum volume")
	
	return {
		"new_volume_m3": new_volume_m3,
		"actual_inflow_m3s": total_inflow_m3s,
		"actual_outflow_m3s": actual_outflow_m3s,
		"actual_drain_flow_m3s": actual_drain_flow_m3s,
		"actual_spill_flow_m3s": actual_spill_flow_m3s
	}
