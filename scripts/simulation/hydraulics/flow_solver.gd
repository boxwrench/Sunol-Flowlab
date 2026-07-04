class_name FlowSolver
extends RefCounted

# Two-pass request/grant flow solver (Phase 1 degenerate case)
static func solve_flows(context: SimulationContext) -> void:
	# Pass 1: Propagate/calculate requests (downstream to upstream)
	for link in context.links_list:
		var _req: float = link.calculate_requested_flow()
		
	# Pass 2: Resolve and assign grants (upstream to downstream)
	for link in context.links_list:
		link.granted_flow_m3s = link.requested_flow_m3s
		link.actual_flow_m3s = link.granted_flow_m3s
