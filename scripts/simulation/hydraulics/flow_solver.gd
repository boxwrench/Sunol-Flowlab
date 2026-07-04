class_name FlowSolver
extends RefCounted

# ---------------------------------------------------------------------------
# G5 Two-Pass DAG Flow Solver
# SIMULATION_RULES §Flow Resolution and Proration, Edge Rules 1-6.
#
# Pass 1 (reverse topological): compute requested_flow_m3s on every link.
# Pass 2 (forward topological): compute granted_flow_m3s on every link,
#   honouring supply limits and prorating over-committed sources.
# Final sweep: write actual_flow_m3s = granted_flow_m3s for ALL links so
#   boundary-sourced links are updated identically to storage-sourced ones.
# ---------------------------------------------------------------------------

const EPSILON: float = 1e-9

static func solve_flows(context: SimulationContext) -> void:
	# -----------------------------------------------------------------------
	# PASS 1 — Downstream-to-Upstream: set requested_flow_m3s on each link.
	# Iterate topological_units_list in REVERSE (sinks → sources).
	# -----------------------------------------------------------------------
	var topo: Array = context.topological_units_list
	for i: int in range(topo.size() - 1, -1, -1):
		var unit: ProcessUnit = topo[i]
		# For each port on this unit that is an INLET (flow comes in FROM upstream)
		# we compute the request on the connected link.
		var ports: Dictionary = unit.ports
		var incoming_links: Array[FlowLink] = []
		for port_id in ports:
			var port: FlowPort = ports[port_id]
			if port.port_type != &"INLET":
				continue
			var link: FlowLink = port.connected_link
			if link == null or not link.is_enabled:
				continue
			# COMMANDED mode: warn and treat as RESTRICTED at full opening (Edge Rule 6)
			if link.flow_mode == &"COMMANDED":
				push_warning(
					"FlowSolver: link '%s' is COMMANDED — unimplemented. Treating as RESTRICTED at opening=1.0." \
					% link.link_id
				)
				link.requested_flow_m3s = link.max_flow_m3s
			else:
				link.calculate_requested_flow()
			incoming_links.append(link)
			
		# Enforce flow_limit_m3s on ExternalBoundary sink units (sink-side proration)
		if unit is ExternalBoundary and unit.flow_limit_m3s >= 0.0:
			var total_inflow_request: float = 0.0
			for link in incoming_links:
				total_inflow_request += link.requested_flow_m3s
			if total_inflow_request > unit.flow_limit_m3s + EPSILON:
				var factor: float = unit.flow_limit_m3s / total_inflow_request
				for link in incoming_links:
					link.requested_flow_m3s *= factor

	# -----------------------------------------------------------------------
	# PASS 2 — Upstream-to-Downstream: compute granted_flow_m3s.
	# Iterate topological_units_list in FORWARD order (sources → sinks).
	# -----------------------------------------------------------------------
	for unit: ProcessUnit in topo:
		# Collect all outgoing links (OUTLET and DRAIN port types)
		var outlet_links: Array[FlowLink] = []
		var drain_links: Array[FlowLink] = []
		var ports: Dictionary = unit.ports
		for port_id in ports:
			var port: FlowPort = ports[port_id]
			var link: FlowLink = port.connected_link
			if link == null or not link.is_enabled:
				continue
			if port.port_type == &"OUTLET":
				outlet_links.append(link)
			elif port.port_type == &"DRAIN":
				drain_links.append(link)

		if outlet_links.is_empty() and drain_links.is_empty():
			continue

		if unit is ExternalBoundary:
			# Edge Rule 4: ExternalBoundary source with a positive flow_limit_m3s
			# prorates its outgoing links to fit the total limit.
			_grant_boundary_source(unit, outlet_links + drain_links)
		elif unit is StorageUnit:
			# Edge Rule 3: OUTLET draws only above min_operating_level_m;
			# DRAIN draws to zero. Two-tier grant with inter-tier proration.
			_grant_storage_source(unit, outlet_links, drain_links, context.dt)
		else:
			# Generic unit: grant all requests in full (no supply constraint).
			for link: FlowLink in outlet_links + drain_links:
				link.granted_flow_m3s = link.requested_flow_m3s

	# -----------------------------------------------------------------------
	# FINAL SWEEP — Write actual_flow_m3s = granted_flow_m3s for every link.
	# This covers boundary-sourced links which have no StorageBalance to write
	# them (SIMULATION_RULES §Final actual-flow sweep).
	# -----------------------------------------------------------------------
	for link: FlowLink in context.links_list:
		link.actual_flow_m3s = link.granted_flow_m3s


# ---------------------------------------------------------------------------
# _grant_storage_source
# Two-tier proration: OUTLET links draw from outlet_supply (above min_vol);
# DRAIN links draw from total_supply (down to zero).  If the combined ask
# exceeds total_supply, all outgoing links are prorated together (INV-1).
# ---------------------------------------------------------------------------
static func _grant_storage_source(
	unit: StorageUnit,
	outlet_links: Array[FlowLink],
	drain_links: Array[FlowLink],
	dt: float
) -> void:
	var min_vol: float = unit.min_operating_level_m * unit.surface_area_m2
	# Sum inflows already granted on INLET ports this tick
	var granted_inflow_m3s: float = 0.0
	for port_id in unit.ports:
		var port: FlowPort = unit.ports[port_id]
		if port.port_type == &"INLET" and port.connected_link != null:
			granted_inflow_m3s += port.connected_link.granted_flow_m3s

	# Tier 1: supply available to OUTLET ports (above low-low cutoff, Edge Rule 3)
	var outlet_supply_m3s: float = max(0.0, unit.volume_m3 - min_vol) / dt + granted_inflow_m3s
	# Tier 2: total supply including the low-low reserve (available to DRAIN)
	var total_supply_m3s: float = max(0.0, unit.volume_m3) / dt + granted_inflow_m3s

	# --- Compute OUTLET grants ---
	var total_outlet_request: float = 0.0
	for link: FlowLink in outlet_links:
		total_outlet_request += link.requested_flow_m3s

	var outlet_granted_total: float = 0.0
	if total_outlet_request <= outlet_supply_m3s + EPSILON:
		for link: FlowLink in outlet_links:
			link.granted_flow_m3s = link.requested_flow_m3s
		outlet_granted_total = total_outlet_request
	else:
		var factor: float = outlet_supply_m3s / total_outlet_request if total_outlet_request > 0.0 else 0.0
		for link: FlowLink in outlet_links:
			link.granted_flow_m3s = link.requested_flow_m3s * factor
			outlet_granted_total += link.granted_flow_m3s

	# --- Compute DRAIN grants against remaining total supply ---
	var drain_supply_m3s: float = max(0.0, total_supply_m3s - outlet_granted_total)
	var total_drain_request: float = 0.0
	for link: FlowLink in drain_links:
		total_drain_request += link.requested_flow_m3s

	if total_drain_request <= drain_supply_m3s + EPSILON:
		for link: FlowLink in drain_links:
			link.granted_flow_m3s = link.requested_flow_m3s
	else:
		var factor: float = drain_supply_m3s / total_drain_request if total_drain_request > 0.0 else 0.0
		for link: FlowLink in drain_links:
			link.granted_flow_m3s = link.requested_flow_m3s * factor

	# --- Final combined check: never grant more than total_supply (INV-1) ---
	var combined_total: float = 0.0
	for link: FlowLink in outlet_links + drain_links:
		combined_total += link.granted_flow_m3s

	if combined_total > total_supply_m3s + EPSILON:
		var rescale: float = total_supply_m3s / combined_total
		for link: FlowLink in outlet_links + drain_links:
			link.granted_flow_m3s *= rescale


# ---------------------------------------------------------------------------
# _grant_boundary_source
# Edge Rule 4: ExternalBoundary source.  If flow_limit_m3s >= 0 the total
# granted flow across all outgoing links is capped at that limit; excess is
# prorated proportionally.
# ---------------------------------------------------------------------------
static func _grant_boundary_source(
	unit: ExternalBoundary,
	all_links: Array[FlowLink]
) -> void:
	# First pass: grant requests in full
	var total_request: float = 0.0
	for link: FlowLink in all_links:
		link.granted_flow_m3s = link.requested_flow_m3s
		total_request += link.requested_flow_m3s

	# Apply flow_limit_m3s cap (negative means unlimited)
	if unit.flow_limit_m3s >= 0.0 and total_request > unit.flow_limit_m3s + EPSILON:
		var factor: float = unit.flow_limit_m3s / total_request
		for link: FlowLink in all_links:
			link.granted_flow_m3s = link.requested_flow_m3s * factor
