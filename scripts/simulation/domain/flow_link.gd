class_name FlowLink
extends RefCounted

var link_id: StringName
var display_name: String = ""

var source_port: FlowPort = null
var destination_port: FlowPort = null

var max_flow_m3s: float = 0.0
var flow_mode: StringName = &"RESTRICTED" # RESTRICTED, GRAVITY
var design_head_m: float = 0.0

# Actuator controlling this link
var actuator: SimValve = null

# Flow states
var requested_flow_m3s: float = 0.0
var granted_flow_m3s: float = 0.0
var actual_flow_m3s: float = 0.0

var is_enabled: bool = true
var constraint_reason: String = ""

# F2.2-5: warn-once flag prevents log flooding at 100k-tick soaks.
var _gravity_warned: bool = false

func initialize(config: Dictionary, port_resolver: Callable) -> void:
	link_id = StringName(config.get("link_id", ""))
	display_name = config.get("display_name", "")
	max_flow_m3s = float(config.get("max_flow_m3s", 0.0))
	flow_mode = StringName(config.get("flow_mode", "RESTRICTED"))
	design_head_m = float(config.get("design_head_m", 0.0))
	is_enabled = bool(config.get("is_enabled", true))
	
	var src_port_id: StringName = StringName(config.get("source_port_id", ""))
	var dest_port_id: StringName = StringName(config.get("destination_port_id", ""))
	
	source_port = port_resolver.call(src_port_id)
	destination_port = port_resolver.call(dest_port_id)
	
	if source_port != null:
		source_port.connected_link = self
	if destination_port != null:
		destination_port.connected_link = self

func _get_port_elevation(port: FlowPort) -> float:
	if port == null or port.owner_unit == null:
		return 0.0
	var unit = port.owner_unit
	if unit.has_method("water_surface_elevation_m"):
		return unit.water_surface_elevation_m()
	elif "reference_head_m" in unit:
		return unit.reference_head_m
	return 0.0

func calculate_requested_flow() -> float:
	constraint_reason = ""
	
	if not is_enabled:
		constraint_reason = "Link Disabled"
		requested_flow_m3s = 0.0
		return 0.0
		
	if flow_mode == &"RESTRICTED":
		if actuator != null:
			var opening: float = actuator.get_effective_opening()
			requested_flow_m3s = max_flow_m3s * opening
			if opening == 0.0:
				constraint_reason = "Valve Closed"
			elif opening < 1.0:
				constraint_reason = "Valve Restricted"
		else:
			requested_flow_m3s = max_flow_m3s
	elif flow_mode == &"GRAVITY":
		var opening: float = 1.0
		if actuator != null:
			opening = actuator.get_effective_opening()
			if opening == 0.0:
				constraint_reason = "Valve Closed"
				requested_flow_m3s = 0.0
				return 0.0

		var upstream_elev: float = _get_port_elevation(source_port)
		var downstream_elev: float = _get_port_elevation(destination_port)
		var dh: float = upstream_elev - downstream_elev
		
		# Q calculation. The topology is a DAG: negative head (downstream higher
		# than upstream) yields zero forward flow — reverse flow is not supported.
		var base: float = max_flow_m3s * opening
		var Q: float = 0.0
		if dh >= 0.0 and design_head_m > 0.0:
			Q = base * sqrt(dh / design_head_m)

		# Clamping and constraint reason setting (Q is always >= 0)
		if Q > max_flow_m3s + 1e-9:
			Q = max_flow_m3s
			constraint_reason = "GRAVITY clamped@max"
		elif abs(dh) < 1e-9:
			constraint_reason = "GRAVITY equalized"
		elif dh < 0.0:
			constraint_reason = "GRAVITY reverse blocked"
		else:
			constraint_reason = "GRAVITY self-regulating"

		requested_flow_m3s = Q
	else:
		# Unknown mode — warn once, fall back to RESTRICTED
		if not _gravity_warned:
			push_warning(
				"FlowLink '%s': flow_mode '%s' is unknown. Treating as RESTRICTED at current opening." \
				% [link_id, flow_mode]
			)
			_gravity_warned = true
		constraint_reason = "Unknown mode (unimplemented, treated as RESTRICTED)"
		if actuator != null:
			requested_flow_m3s = max_flow_m3s * actuator.get_effective_opening()
		else:
			requested_flow_m3s = max_flow_m3s
		
	return requested_flow_m3s

func get_snapshot() -> Dictionary:
	return {
		"link_id": link_id,
		"display_name": display_name,
		"source_port_id": source_port.port_id if source_port != null else &"",
		"destination_port_id": destination_port.port_id if destination_port != null else &"",
		"max_flow_m3s": max_flow_m3s,
		"flow_mode": flow_mode,
		"design_head_m": design_head_m,
		"requested_flow_m3s": requested_flow_m3s,
		"granted_flow_m3s": granted_flow_m3s,
		"actual_flow_m3s": actual_flow_m3s,
		"is_enabled": is_enabled,
		"constraint_reason": constraint_reason,
		"actuator_id": actuator.actuator_id if actuator != null else &""
	}
