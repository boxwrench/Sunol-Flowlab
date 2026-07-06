class_name PlantFactory
extends RefCounted

# Note: SimulationCommands like SetBasinServiceCommand do not require explicit factory 
# registration because Godot automatically registers all class_name declarations globally.

static func build_plant(
	context: SimulationContext,
	topology_data: Dictionary,
	initial_conditions_data: Dictionary,
	controllers_data: Dictionary = {}
) -> bool:
	# 1. Instantiate Units
	var units_array: Array = topology_data.get("units", [])
	var units_map: Dictionary = {}
	
	for unit_config in units_array:
		var type: String = unit_config.get("type", "")
		var unit_id: StringName = StringName(unit_config.get("unit_id", ""))
		
		var unit: ProcessUnit = null
		if type == "StorageUnit":
			unit = StorageUnit.new()
		elif type == "ExternalBoundary":
			unit = ExternalBoundary.new()
		else:
			unit = ProcessUnit.new()
			
		unit.initialize(unit_config)
		units_map[unit_id] = unit
		
		if unit_config.has("ports"):
			var ports_arr: Array = unit_config["ports"]
			for port_config in ports_arr:
				var port_id: StringName = StringName(port_config.get("port_id", ""))
				var port_type: StringName = StringName(port_config.get("port_type", ""))
				var port := FlowPort.new(port_id, unit, port_type)
				port.owner_unit = unit
				
				if unit is StorageUnit:
					unit.ports[port_id] = port
				elif unit is ExternalBoundary:
					unit.ports[port_id] = port
					
	# 2. Instantiate Actuators
	var actuators_array: Array = topology_data.get("actuators", [])
	var actuators_map: Dictionary = {}
	
	for act_config in actuators_array:
		var act_id: StringName = StringName(act_config.get("actuator_id", ""))
		var valve := SimValve.new(act_id)
		valve.initialize(act_config)
		actuators_map[act_id] = valve
		
	# 3. Instantiate Links
	var links_array: Array = topology_data.get("links", [])
	var links_map: Dictionary = {}
	
	var port_resolver: Callable = func(port_id: StringName) -> FlowPort:
		for u in units_map.values():
			if u.ports.has(port_id):
				return u.ports[port_id]
		return null
		
	for link_config in links_array:
		var link_id: StringName = StringName(link_config.get("link_id", ""))
		var link := FlowLink.new()
		link.initialize(link_config, port_resolver)
		
		if link_config.has("actuator_id"):
			var act_id: StringName = StringName(link_config["actuator_id"])
			if actuators_map.has(act_id):
				link.actuator = actuators_map[act_id]
				
		links_map[link_id] = link

	# 3a. Enforce initial topology in_service on connected links
	for unit in units_map.values():
		if not unit.in_service:
			unit.set_in_service(false)

	# 3b. Instantiate Controllers
	var controllers_array: Array = controllers_data.get("controllers", [])
	var controllers_map: Dictionary = {}
	
	for ctrl_config in controllers_array:
		var ctrl_id: StringName = StringName(ctrl_config.get("controller_id", ""))
		var type: String = ctrl_config.get("type", "")
		var ctrl: SimController = null
		if type == "LevelController":
			ctrl = LevelController.new()
		else:
			ctrl = SimController.new()
			
		ctrl.initialize(ctrl_config)
		controllers_map[ctrl_id] = ctrl

	# 4. Apply initial conditions
	var unit_states: Array = initial_conditions_data.get("unit_states", [])
	for ustate in unit_states:
		var uid: StringName = StringName(ustate.get("unit_id", ""))
		if units_map.has(uid):
			var unit = units_map[uid]
			unit.set_in_service(bool(ustate.get("in_service", unit.in_service)))
			if unit is StorageUnit and ustate.has("volume_m3"):
				unit.volume_m3 = float(ustate["volume_m3"])
				unit.update_level()
				
	var actuator_states: Array = initial_conditions_data.get("actuator_states", [])
	for astate in actuator_states:
		var act_id: StringName = StringName(astate.get("actuator_id", ""))
		var valve: SimValve = actuators_map.get(act_id)
		if valve != null:
			valve.is_manual = bool(astate.get("is_manual", true))
			valve.commanded_position = float(astate.get("commanded_position", 0.0))
			valve.position = float(astate.get("position", 0.0))

	var controller_states: Array = initial_conditions_data.get("controller_states", [])
	for cstate in controller_states:
		var ctrl_id: StringName = StringName(cstate.get("controller_id", ""))
		var ctrl = controllers_map.get(ctrl_id)
		if ctrl != null:
			if cstate.has("control_mode"):
				ctrl.control_mode = StringName(cstate["control_mode"])
			if cstate.has("setpoint") and "setpoint" in ctrl:
				ctrl.setpoint = float(cstate["setpoint"])

	# 5. Sort alphabetically by ID to ensure determinism
	var sorted_unit_ids: Array = units_map.keys()
	sorted_unit_ids.sort_custom(func(a, b) -> bool:
		return String(a) < String(b)
	)
	
	context.units_list.clear()
	context.units_dict.clear()
	for uid in sorted_unit_ids:
		context.units_list.append(units_map[uid])
		context.units_dict[uid] = units_map[uid]
		
	var sorted_link_ids: Array = links_map.keys()
	sorted_link_ids.sort_custom(func(a, b) -> bool:
		return String(a) < String(b)
	)
	
	context.links_list.clear()
	context.links_dict.clear()
	for lid in sorted_link_ids:
		context.links_list.append(links_map[lid])
		context.links_dict[lid] = links_map[lid]
		
	var sorted_act_ids: Array = actuators_map.keys()
	sorted_act_ids.sort_custom(func(a, b) -> bool:
		return String(a) < String(b)
	)
	
	context.actuators_list.clear()
	context.actuators_dict.clear()
	for aid in sorted_act_ids:
		context.actuators_list.append(actuators_map[aid])
		context.actuators_dict[aid] = actuators_map[aid]

	var sorted_ctrl_ids: Array = controllers_map.keys()
	sorted_ctrl_ids.sort_custom(func(a, b) -> bool:
		return String(a) < String(b)
	)
	
	context.controllers_list.clear()
	context.controllers_dict.clear()
	for cid in sorted_ctrl_ids:
		context.controllers_list.append(controllers_map[cid])
		context.controllers_dict[cid] = controllers_map[cid]

	# 6. Topological sort (Kahn's algorithm) — Edge Rule 1
	# in-degree: how many upstream units feed this unit via FlowLink edges.
	var in_degree: Dictionary = {}
	# adjacency: unit_id -> array of downstream unit ids
	var downstream: Dictionary = {}
	for uid in units_map:
		in_degree[uid] = 0
		downstream[uid] = []

	for link in links_map.values():
		var src_unit: RefCounted = link.source_port.parent_unit if link.source_port != null else null
		var dst_unit: RefCounted = link.destination_port.parent_unit if link.destination_port != null else null
		if src_unit == null or dst_unit == null:
			continue
		# src_unit.unit_id is the StringName declared on ProcessUnit
		var src_id: StringName = src_unit.unit_id
		var dst_id: StringName = dst_unit.unit_id
		if src_id == dst_id:
			continue  # self-loop: not a valid edge for DAG purposes
		in_degree[dst_id] = in_degree.get(dst_id, 0) + 1
		downstream[src_id].append(dst_id)

	# Seed ready queue with every unit whose in-degree is zero, sorted
	# lexicographically so the tie-breaking rule is deterministic (guardrail 7).
	var ready: Array = []
	for uid in in_degree:
		if in_degree[uid] == 0:
			ready.append(uid)
	ready.sort_custom(func(a, b) -> bool: return String(a) < String(b))

	context.topological_units_list.clear()
	while ready.size() > 0:
		var uid: StringName = ready.pop_front()
		context.topological_units_list.append(units_map[uid])
		for next_id in downstream[uid]:
			in_degree[next_id] -= 1
			if in_degree[next_id] == 0:
				ready.append(next_id)
		# Re-sort after each insertion to maintain lex order across new entries
		ready.sort_custom(func(a, b) -> bool: return String(a) < String(b))

	# Cycle detection: if any unit was never emitted, the graph contains a cycle.
	if context.topological_units_list.size() != units_map.size():
		push_error("PlantFactory: topology graph contains a cycle — build_plant() failed.")
		return false

	return true
