class_name SnapshotService
extends RefCounted

static func take_snapshot(context: SimulationContext, engine: RefCounted) -> Dictionary:
	var snap: Dictionary = {
		"tick": context.current_tick,
		"dt": context.dt,
		"units": {},
		"links": {},
		"actuators": {},
		"controllers": {},
		"alarms": {},
		"plant_totals": {
			"initial_storage_m3": 0.0,
			"current_storage_m3": 0.0,
			"cumulative_inflow_m3": 0.0,
			"cumulative_treated_demand_m3": 0.0,
			"cumulative_process_waste_m3": 0.0,
			"cumulative_drain_m3": 0.0,
			"cumulative_spill_m3": 0.0,
			"mass_balance_error_m3": 0.0
		}
	}
	
	for unit in context.units_list:
		snap["units"][unit.unit_id] = unit.get_snapshot()
		
	for link in context.links_list:
		snap["links"][link.link_id] = link.get_snapshot()
		
	for act in context.actuators_list:
		snap["actuators"][act.actuator_id] = act.get_snapshot()
		
	for ctrl in context.controllers_list:
		snap["controllers"][ctrl.controller_id] = ctrl.get_snapshot()
		
	if engine != null and engine.get("alarm_engine") != null:
		var alarm_engine = engine.alarm_engine
		for alarm in alarm_engine.alarms_list:
			snap["alarms"][alarm.alarm_id] = alarm.get_snapshot()
			
	if engine != null and engine.get("mass_balance_tracker") != null:
		var tracker = engine.mass_balance_tracker
		var current_storage: float = 0.0
		for unit in context.units_list:
			if unit is StorageUnit:
				current_storage += unit.volume_m3
				
		var report: Dictionary = tracker.report(current_storage)
		snap["plant_totals"] = {
			"initial_storage_m3": report.initial_storage_m3,
			"current_storage_m3": report.current_storage_m3,
			"cumulative_inflow_m3": report.cumulative_inflow_m3,
			"cumulative_treated_demand_m3": report.cumulative_treated_demand_m3,
			"cumulative_process_waste_m3": report.cumulative_process_waste_m3,
			"cumulative_drain_m3": report.cumulative_drain_m3,
			"cumulative_spill_m3": report.cumulative_spill_m3,
			"mass_balance_error_m3": report.mass_balance_error_m3
		}
		
	# Return a deep duplicate to prevent external mutation
	return snap.duplicate(true)
