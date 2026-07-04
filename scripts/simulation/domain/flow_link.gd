class_name FlowLink
extends RefCounted

var link_id: StringName
var display_name: String = ""

var source_port: FlowPort = null
var destination_port: FlowPort = null

var max_flow_m3s: float = 0.0
var reverse_flow_allowed: bool = false
var flow_mode: StringName = &"RESTRICTED" # COMMANDED, RESTRICTED, GRAVITY

# Actuator controlling this link
var actuator: SimValve = null

# Flow states
var requested_flow_m3s: float = 0.0
var granted_flow_m3s: float = 0.0
var actual_flow_m3s: float = 0.0

var is_enabled: bool = true
var constraint_reason: String = ""

func initialize(config: Dictionary, port_resolver: Callable) -> void:
	link_id = StringName(config.get("link_id", ""))
	display_name = config.get("display_name", "")
	max_flow_m3s = float(config.get("max_flow_m3s", 0.0))
	reverse_flow_allowed = bool(config.get("reverse_flow_allowed", false))
	flow_mode = StringName(config.get("flow_mode", "RESTRICTED"))
	is_enabled = bool(config.get("is_enabled", true))
	
	var src_port_id: StringName = StringName(config.get("source_port_id", ""))
	var dest_port_id: StringName = StringName(config.get("destination_port_id", ""))
	
	source_port = port_resolver.call(src_port_id)
	destination_port = port_resolver.call(dest_port_id)
	
	if source_port != null:
		source_port.connected_link = self
	if destination_port != null:
		destination_port.connected_link = self

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
	elif flow_mode == &"COMMANDED":
		requested_flow_m3s = max_flow_m3s
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
		"reverse_flow_allowed": reverse_flow_allowed,
		"flow_mode": flow_mode,
		"requested_flow_m3s": requested_flow_m3s,
		"granted_flow_m3s": granted_flow_m3s,
		"actual_flow_m3s": actual_flow_m3s,
		"is_enabled": is_enabled,
		"constraint_reason": constraint_reason,
		"actuator_id": actuator.actuator_id if actuator != null else &""
	}
