class_name FlowPort
extends RefCounted

var port_id: StringName
var parent_unit: RefCounted # ProcessUnit
var port_type: StringName # INLET, OUTLET, DRAIN
var connected_link: RefCounted = null # FlowLink

func _init(p_id: StringName, p_parent: RefCounted, p_type: StringName) -> void:
	port_id = p_id
	parent_unit = p_parent
	port_type = p_type

func get_snapshot() -> Dictionary:
	return {
		"port_id": port_id,
		"port_type": port_type,
		"connected_link_id": connected_link.link_id if connected_link != null else &""
	}
