class_name ExternalBoundary
extends ProcessUnit

# Mutually exclusive ledger category from INV-1
# SOURCE_INFLOW, TREATED_DEMAND, PROCESS_WASTE, DRAIN, SPILL
var boundary_type: StringName

# Capacity limit (negative means infinite)
var flow_limit_m3s: float = -1.0

# Current flow rate through this boundary
var current_flow_m3s: float = 0.0

# Ports dictionary (port_id -> FlowPort)
var ports: Dictionary = {}

func initialize(config: Dictionary) -> void:
	super.initialize(config)
	boundary_type = StringName(config.get("boundary_type", ""))
	flow_limit_m3s = float(config.get("flow_limit_m3s", -1.0))
	current_flow_m3s = 0.0

func get_snapshot() -> Dictionary:
	var snap: Dictionary = super.get_snapshot()
	snap.merge({
		"boundary_type": boundary_type,
		"flow_limit_m3s": flow_limit_m3s,
		"current_flow_m3s": current_flow_m3s
	})
	return snap

func solve_tick(context: RefCounted) -> void:
	if boundary_type == &"SPILL":
		return
		
	current_flow_m3s = 0.0
	for port_id in ports:
		var port: FlowPort = ports[port_id]
		var link: FlowLink = port.connected_link
		if link != null:
			current_flow_m3s = link.actual_flow_m3s
			break

func validate(context: RefCounted) -> Array[String]:
	var errors: Array[String] = super.validate(context)
	var valid_types: Array[StringName] = [&"SOURCE_INFLOW", &"TREATED_DEMAND", &"PROCESS_WASTE", &"DRAIN", &"SPILL"]
	if not boundary_type in valid_types:
		errors.append("ExternalBoundary: invalid boundary_type '%s'" % boundary_type)
	return errors
