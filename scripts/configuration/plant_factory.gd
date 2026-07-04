class_name PlantFactory
extends RefCounted

static func build_plant(
	context: SimulationContext,
	topology_data: Dictionary,
	initial_conditions_data: Dictionary
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

	# 4. Apply initial conditions
	var unit_states: Array = initial_conditions_data.get("unit_states", [])
	for ustate in unit_states:
		var uid: StringName = StringName(ustate.get("unit_id", ""))
		if units_map.has(uid):
			var unit = units_map[uid]
			unit.in_service = bool(ustate.get("in_service", true))
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
		
	return true
