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

# F2.2-5: warn-once flags prevent log flooding at 100k-tick soaks.
var _commanded_warned: bool = false
var _gravity_warned: bool = false

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
		# F2.2-5 / Edge Rule 6: COMMANDED is unimplemented — warn once per link
		# to avoid log flooding over 100k-tick soaks, then behave as RESTRICTED
		# at full opening. Per guardrail 10: silent placeholder behavior prohibited.
		if not _commanded_warned:
			push_warning(
				"FlowLink '%s': COMMANDED mode is unimplemented. Treating as RESTRICTED at opening=1.0." \
				% link_id
			)
			_commanded_warned = true
		constraint_reason = "COMMANDED (unimplemented, treated as RESTRICTED@1.0)"
		requested_flow_m3s = max_flow_m3s
	else:
		# F2.2-5 / Edge Rule 6: GRAVITY or unknown mode — warn once, fall back to
		# RESTRICTED at current actuator opening (not full open) to avoid silent
		# max-flow placeholder behavior.
		if not _gravity_warned:
			push_warning(
				"FlowLink '%s': flow_mode '%s' is unimplemented. Treating as RESTRICTED at current opening." \
				% [link_id, flow_mode]
			)
			_gravity_warned = true
		constraint_reason = "GRAVITY/unknown mode (unimplemented, treated as RESTRICTED)"
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
		"reverse_flow_allowed": reverse_flow_allowed,
		"flow_mode": flow_mode,
		"requested_flow_m3s": requested_flow_m3s,
		"granted_flow_m3s": granted_flow_m3s,
		"actual_flow_m3s": actual_flow_m3s,
		"is_enabled": is_enabled,
		"constraint_reason": constraint_reason,
		"actuator_id": actuator.actuator_id if actuator != null else &""
	}
