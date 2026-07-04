class_name MassBalanceTracker
extends RefCounted

var initial_storage_m3: float = 0.0
var cumulative_inflow_m3: float = 0.0
var cumulative_treated_demand_m3: float = 0.0
var cumulative_process_waste_m3: float = 0.0
var cumulative_drain_m3: float = 0.0
var cumulative_spill_m3: float = 0.0

func initialize(starting_storage: float) -> void:
	initial_storage_m3 = starting_storage
	cumulative_inflow_m3 = 0.0
	cumulative_treated_demand_m3 = 0.0
	cumulative_process_waste_m3 = 0.0
	cumulative_drain_m3 = 0.0
	cumulative_spill_m3 = 0.0

func report(current_storage_m3: float) -> Dictionary:
	var error: float = (initial_storage_m3 + cumulative_inflow_m3 
		- cumulative_treated_demand_m3 - cumulative_process_waste_m3 
		- cumulative_drain_m3 - cumulative_spill_m3 - current_storage_m3)
	
	return {
		"initial_storage_m3": initial_storage_m3,
		"cumulative_inflow_m3": cumulative_inflow_m3,
		"cumulative_treated_demand_m3": cumulative_treated_demand_m3,
		"cumulative_process_waste_m3": cumulative_process_waste_m3,
		"cumulative_drain_m3": cumulative_drain_m3,
		"cumulative_spill_m3": cumulative_spill_m3,
		"current_storage_m3": current_storage_m3,
		"mass_balance_error_m3": error
	}

func validate(context: RefCounted) -> void:
	# Skeleton: no checks yet. Completed in WP1.2
	pass
