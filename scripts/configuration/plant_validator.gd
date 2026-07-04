class_name PlantValidator
extends RefCounted

static func validate_config(
	plant_data: Dictionary,
	topology_data: Dictionary,
	initial_conditions_data: Dictionary,
	dt: float = 1.0,
	controllers_data: Dictionary = {},
	alarms_data: Dictionary = {}
) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var all_ids: Dictionary = {}
	
	var check_key: Callable = func(dict: Dictionary, key: String, type: int, context_str: String) -> bool:
		if not dict.has(key):
			errors.append("%s: missing required key '%s'" % [context_str, key])
			return false
		var val = dict[key]
		if typeof(val) != type:
			errors.append("%s: key '%s' must be of type %d, but was %d" % [context_str, key, type, typeof(val)])
			return false
		return true
		
	# 1. Validate plant_data
	if not plant_data.is_empty():
		check_key.call(plant_data, "plant_id", TYPE_STRING, "plant.json")
		check_key.call(plant_data, "display_name", TYPE_STRING, "plant.json")
		
	# 2. Validate topology_data
	if not check_key.call(topology_data, "units", TYPE_ARRAY, "topology.json"):
		return {"errors": errors, "warnings": warnings}
		
	var units_array: Array = topology_data.get("units", [])
	var unit_ids: Array[StringName] = []
	var boundary_ids: Array[StringName] = []
	var storage_units: Array[Dictionary] = []
	var storage_unit_prefixes: Array[String] = []
	var ports_map: Dictionary = {}
	
	for i in range(units_array.size()):
		var unit_prefix: String = "topology.json[units][%d]" % i
		var unit_dict = units_array[i]
		if typeof(unit_dict) != TYPE_DICTIONARY:
			errors.append("%s: must be a dictionary" % unit_prefix)
			continue
			
		if not check_key.call(unit_dict, "unit_id", TYPE_STRING, unit_prefix):
			continue
			
		var unit_id: StringName = StringName(unit_dict["unit_id"])
		if all_ids.has(unit_id):
			errors.append("%s: duplicate unit_id '%s'" % [unit_prefix, unit_id])
		all_ids[unit_id] = "Unit"
		unit_ids.append(unit_id)
		
		check_key.call(unit_dict, "type", TYPE_STRING, unit_prefix)
		check_key.call(unit_dict, "display_name", TYPE_STRING, unit_prefix)
		
		var type_str: String = unit_dict.get("type", "")
		if type_str == "StorageUnit":
			check_key.call(unit_dict, "maximum_volume_m3", TYPE_FLOAT, unit_prefix)
			check_key.call(unit_dict, "surface_area_m2", TYPE_FLOAT, unit_prefix)
			check_key.call(unit_dict, "bottom_elevation_m", TYPE_FLOAT, unit_prefix)
			check_key.call(unit_dict, "high_level_m", TYPE_FLOAT, unit_prefix)
			check_key.call(unit_dict, "spill_level_m", TYPE_FLOAT, unit_prefix)
			check_key.call(unit_dict, "min_operating_level_m", TYPE_FLOAT, unit_prefix)
			
			var max_vol: float = float(unit_dict.get("maximum_volume_m3", 0.0))
			var area: float = float(unit_dict.get("surface_area_m2", 0.0))
			var spill_lvl: float = float(unit_dict.get("spill_level_m", 0.0))
			var high_lvl: float = float(unit_dict.get("high_level_m", 0.0))
			
			if max_vol <= 0.0:
				errors.append("%s: maximum_volume_m3 must be > 0" % unit_prefix)
			if area <= 0.0:
				errors.append("%s: surface_area_m2 must be > 0" % unit_prefix)
			if spill_lvl < high_lvl:
				errors.append("%s: spill_level_m (%f) must be >= high_level_m (%f)" % [unit_prefix, spill_lvl, high_lvl])
				
			var spill_volume_calc: float = spill_lvl * area
			if abs(max_vol - spill_volume_calc) > 1e-3 and max_vol < spill_volume_calc:
				errors.append("%s: maximum_volume_m3 (%f) is inconsistent with spill_level_m * surface_area_m2 (%f)" % [unit_prefix, max_vol, spill_volume_calc])
				
			storage_units.append(unit_dict)
			storage_unit_prefixes.append(unit_prefix)
			
		elif type_str == "ExternalBoundary":
			check_key.call(unit_dict, "boundary_type", TYPE_STRING, unit_prefix)
			boundary_ids.append(unit_id)
			
		if unit_dict.has("ports"):
			var ports_arr = unit_dict["ports"]
			if typeof(ports_arr) == TYPE_ARRAY:
				for j in range(ports_arr.size()):
					var port_prefix: String = "%s[ports][%d]" % [unit_prefix, j]
					var port_dict = ports_arr[j]
					if typeof(port_dict) == TYPE_DICTIONARY:
						if check_key.call(port_dict, "port_id", TYPE_STRING, port_prefix):
							var port_id: StringName = StringName(port_dict["port_id"])
							if all_ids.has(port_id):
								errors.append("%s: duplicate port_id '%s'" % [port_prefix, port_id])
							all_ids[port_id] = "Port"
							ports_map[port_id] = unit_id
							
							check_key.call(port_dict, "port_type", TYPE_STRING, port_prefix)
							
	# Validate spill_destination_id for StorageUnits
	for idx in range(storage_units.size()):
		var s_dict = storage_units[idx]
		var s_prefix = storage_unit_prefixes[idx]
		if check_key.call(s_dict, "spill_destination_id", TYPE_STRING, s_prefix):
			var dest_id: StringName = StringName(s_dict["spill_destination_id"])
			if dest_id != &"":
				if not dest_id in boundary_ids:
					errors.append("%s: spill_destination_id '%s' does not resolve to a known ExternalBoundary in the topology" % [s_prefix, dest_id])
			else:
				errors.append("%s: spill_destination_id cannot be empty" % s_prefix)
								
	var actuator_ids: Array[StringName] = []
	if topology_data.has("actuators"):
		var actuators_arr = topology_data["actuators"]
		if typeof(actuators_arr) == TYPE_ARRAY:
			for i in range(actuators_arr.size()):
				var act_prefix: String = "topology.json[actuators][%d]" % i
				var act_dict = actuators_arr[i]
				if typeof(act_dict) == TYPE_DICTIONARY:
					if check_key.call(act_dict, "actuator_id", TYPE_STRING, act_prefix):
						var act_id: StringName = StringName(act_dict["actuator_id"])
						if all_ids.has(act_id):
							errors.append("%s: duplicate actuator_id '%s'" % [act_prefix, act_id])
						all_ids[act_id] = "Actuator"
						actuator_ids.append(act_id)
						
	var adj_list: Dictionary = {}
	for uid in unit_ids:
		adj_list[uid] = []
		
	if topology_data.has("links"):
		var links_arr = topology_data["links"]
		if typeof(links_arr) == TYPE_ARRAY:
			for i in range(links_arr.size()):
				var link_prefix: String = "topology.json[links][%d]" % i
				var link_dict = links_arr[i]
				if typeof(link_dict) == TYPE_DICTIONARY:
					if not check_key.call(link_dict, "link_id", TYPE_STRING, link_prefix):
						continue
					var link_id: StringName = StringName(link_dict["link_id"])
					if all_ids.has(link_id):
						errors.append("%s: duplicate link_id '%s'" % [link_prefix, link_id])
					all_ids[link_id] = "Link"
					
					check_key.call(link_dict, "max_flow_m3s", TYPE_FLOAT, link_prefix)
					check_key.call(link_dict, "source_port_id", TYPE_STRING, link_prefix)
					check_key.call(link_dict, "destination_port_id", TYPE_STRING, link_prefix)
					
					var src_port: StringName = StringName(link_dict.get("source_port_id", ""))
					var dest_port: StringName = StringName(link_dict.get("destination_port_id", ""))
					
					if src_port != &"" and not ports_map.has(src_port):
						errors.append("%s: source_port_id '%s' is dangling (not defined on any unit)" % [link_prefix, src_port])
					if dest_port != &"" and not ports_map.has(dest_port):
						errors.append("%s: destination_port_id '%s' is dangling (not defined on any unit)" % [link_prefix, dest_port])
						
					if ports_map.has(src_port) and ports_map.has(dest_port):
						var src_unit: StringName = ports_map[src_port]
						var dest_unit: StringName = ports_map[dest_port]
						adj_list[src_unit].append(dest_unit)
						
					if link_dict.has("actuator_id"):
						var act_id: StringName = StringName(link_dict["actuator_id"])
						if act_id != &"" and not act_id in actuator_ids:
							errors.append("%s: actuator_id '%s' is dangling (not defined in actuators)" % [link_prefix, act_id])
							
					var max_flow: float = float(link_dict.get("max_flow_m3s", 0.0))
					if ports_map.has(dest_port):
						var dest_unit_id: StringName = ports_map[dest_port]
						var dest_unit_dict = null
						for u in units_array:
							if u.get("unit_id") == dest_unit_id:
								dest_unit_dict = u
								break
						if dest_unit_dict != null and dest_unit_dict.get("type") == "StorageUnit":
							var max_vol: float = float(dest_unit_dict.get("maximum_volume_m3", 0.0))
							if max_flow * dt > 0.2 * max_vol:
								warnings.append("Simulation Resolution Warning for '%s': max_flow (%f) * dt (%f) > 20%% of target storage '%s' capacity (%f)" % [link_id, max_flow, dt, dest_unit_id, max_vol])

	var visited: Dictionary = {}
	for uid in unit_ids:
		visited[uid] = 0
		
	var has_cycle: bool = false
	for uid in unit_ids:
		if visited[uid] == 0:
			if _dfs_check_cycle(uid, adj_list, visited):
				has_cycle = true
				break
				
	if has_cycle:
		errors.append("Topology validation failed: cyclic flow path detected. Hydraulic topology must be a Directed Acyclic Graph (DAG).")

	if not initial_conditions_data.is_empty():
		var unit_states = initial_conditions_data.get("unit_states", [])
		if typeof(unit_states) == TYPE_ARRAY:
			for i in range(unit_states.size()):
				var ustate_prefix: String = "initial_conditions.json[unit_states][%d]" % i
				var ustate = unit_states[i]
				if typeof(ustate) == TYPE_DICTIONARY:
					if check_key.call(ustate, "unit_id", TYPE_STRING, ustate_prefix):
						var unit_id: StringName = StringName(ustate["unit_id"])
						if not unit_id in unit_ids:
							errors.append("%s: references unknown unit_id '%s'" % [ustate_prefix, unit_id])
						else:
							var init_vol = ustate.get("volume_m3")
							if init_vol != null:
								for u in units_array:
									if u.get("unit_id") == unit_id:
										var max_vol: float = float(u.get("maximum_volume_m3", 0.0))
										if float(init_vol) > max_vol:
											errors.append("%s: initial volume_m3 (%f) exceeds maximum_volume_m3 (%f)" % [ustate_prefix, float(init_vol), max_vol])
											
		var actuator_states = initial_conditions_data.get("actuator_states", [])
		if typeof(actuator_states) == TYPE_ARRAY:
			for i in range(actuator_states.size()):
				var astate_prefix: String = "initial_conditions.json[actuator_states][%d]" % i
				var astate = actuator_states[i]
				if typeof(astate) == TYPE_DICTIONARY:
					if check_key.call(astate, "actuator_id", TYPE_STRING, astate_prefix):
						var act_id: StringName = StringName(astate["actuator_id"])
						if not act_id in actuator_ids:
							errors.append("%s: references unknown actuator_id '%s'" % [astate_prefix, act_id])

	# 4. Validate controllers_data if present
	if not controllers_data.is_empty():
		if check_key.call(controllers_data, "controllers", TYPE_ARRAY, "controllers.json"):
			var controllers_array: Array = controllers_data.get("controllers", [])
			for i in range(controllers_array.size()):
				var ctrl_prefix: String = "controllers.json[controllers][%d]" % i
				var ctrl_dict = controllers_array[i]
				if typeof(ctrl_dict) != TYPE_DICTIONARY:
					errors.append("%s: must be a dictionary" % ctrl_prefix)
					continue
					
				if not check_key.call(ctrl_dict, "controller_id", TYPE_STRING, ctrl_prefix):
					continue
				var ctrl_id: StringName = StringName(ctrl_dict["controller_id"])
				if all_ids.has(ctrl_id):
					errors.append("%s: duplicate controller_id '%s'" % [ctrl_prefix, ctrl_id])
				all_ids[ctrl_id] = "Controller"
				
				check_key.call(ctrl_dict, "type", TYPE_STRING, ctrl_prefix)
				check_key.call(ctrl_dict, "display_name", TYPE_STRING, ctrl_prefix)
				check_key.call(ctrl_dict, "target_actuator_id", TYPE_STRING, ctrl_prefix)
				check_key.call(ctrl_dict, "pv_unit_id", TYPE_STRING, ctrl_prefix)
				check_key.call(ctrl_dict, "pv_property", TYPE_STRING, ctrl_prefix)
				check_key.call(ctrl_dict, "control_mode", TYPE_STRING, ctrl_prefix)
				check_key.call(ctrl_dict, "gain", TYPE_FLOAT, ctrl_prefix)
				check_key.call(ctrl_dict, "deadband_m", TYPE_FLOAT, ctrl_prefix)
				check_key.call(ctrl_dict, "min_output", TYPE_FLOAT, ctrl_prefix)
				check_key.call(ctrl_dict, "max_output", TYPE_FLOAT, ctrl_prefix)
				
				var target_act_id: StringName = StringName(ctrl_dict.get("target_actuator_id", ""))
				if target_act_id != &"" and not target_act_id in actuator_ids:
					errors.append("%s: target_actuator_id '%s' is dangling (not defined in actuators)" % [ctrl_prefix, target_act_id])
					
				var pv_uid: StringName = StringName(ctrl_dict.get("pv_unit_id", ""))
				if pv_uid != &"" and not pv_uid in unit_ids:
					errors.append("%s: pv_unit_id '%s' is dangling (not defined in units)" % [ctrl_prefix, pv_uid])
					
				var gain: float = float(ctrl_dict.get("gain", 0.0))
				if gain <= 0.0:
					errors.append("%s: gain (%f) must be positive" % [ctrl_prefix, gain])
					
				var deadband: float = float(ctrl_dict.get("deadband_m", 0.0))
				if deadband < 0.0:
					errors.append("%s: deadband_m (%f) must be >= 0" % [ctrl_prefix, deadband])
					
				var min_out: float = float(ctrl_dict.get("min_output", 0.0))
				var max_out: float = float(ctrl_dict.get("max_output", 0.0))
				if min_out >= max_out:
					errors.append("%s: min_output (%f) must be < max_output (%f)" % [ctrl_prefix, min_out, max_out])

	# 5. Validate alarms_data if present
	if not alarms_data.is_empty():
		if check_key.call(alarms_data, "alarms", TYPE_ARRAY, "alarms.json"):
			var alarms_array: Array = alarms_data.get("alarms", [])
			for i in range(alarms_array.size()):
				var alarm_prefix: String = "alarms.json[alarms][%d]" % i
				var alarm_dict = alarms_array[i]
				if typeof(alarm_dict) != TYPE_DICTIONARY:
					errors.append("%s: must be a dictionary" % alarm_prefix)
					continue
					
				if not check_key.call(alarm_dict, "alarm_id", TYPE_STRING, alarm_prefix):
					continue
				var alarm_id: StringName = StringName(alarm_dict["alarm_id"])
				if all_ids.has(alarm_id):
					errors.append("%s: duplicate alarm_id '%s'" % [alarm_prefix, alarm_id])
				all_ids[alarm_id] = "Alarm"
				
				check_key.call(alarm_dict, "display_name", TYPE_STRING, alarm_prefix)
				check_key.call(alarm_dict, "target_unit_id", TYPE_STRING, alarm_prefix)
				check_key.call(alarm_dict, "target_property", TYPE_STRING, alarm_prefix)
				check_key.call(alarm_dict, "alarm_type", TYPE_STRING, alarm_prefix)
				check_key.call(alarm_dict, "threshold_value", TYPE_FLOAT, alarm_prefix)
				check_key.call(alarm_dict, "delay_s", TYPE_FLOAT, alarm_prefix)
				check_key.call(alarm_dict, "deadband", TYPE_FLOAT, alarm_prefix)
				
				var alarm_type_str: String = alarm_dict.get("alarm_type", "")
				if alarm_type_str != "HIGH" and alarm_type_str != "LOW":
					errors.append("%s: alarm_type must be either 'HIGH' or 'LOW'" % alarm_prefix)
					
				var tgt_uid: StringName = StringName(alarm_dict.get("target_unit_id", ""))
				if tgt_uid != &"" and not tgt_uid in unit_ids:
					errors.append("%s: target_unit_id '%s' is dangling (not defined in units)" % [alarm_prefix, tgt_uid])
					
				var delay: float = float(alarm_dict.get("delay_s", 0.0))
				if delay < 0.0:
					errors.append("%s: delay_s (%f) must be >= 0" % [alarm_prefix, delay])
					
				var db: float = float(alarm_dict.get("deadband", 0.0))
				if db < 0.0:
					errors.append("%s: deadband (%f) must be >= 0" % [alarm_prefix, db])

	return {"errors": errors, "warnings": warnings}

static func _dfs_check_cycle(node: StringName, adj_list: Dictionary, visited: Dictionary) -> bool:
	visited[node] = 1 # visiting
	for neighbor in adj_list[node]:
		if visited[neighbor] == 1:
			return true # cycle detected
		elif visited[neighbor] == 0:
			if _dfs_check_cycle(neighbor, adj_list, visited):
				return true
	visited[node] = 2 # visited
	return false
