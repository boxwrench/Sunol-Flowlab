class_name MassBalanceTracker
extends RefCounted

var initial_storage_m3: float = 0.0
var cumulative_inflow_m3: float = 0.0
var cumulative_treated_demand_m3: float = 0.0
var cumulative_process_waste_m3: float = 0.0
var cumulative_drain_m3: float = 0.0
var cumulative_spill_m3: float = 0.0

var is_initialized: bool = false

func initialize(starting_storage: float) -> void:
	initial_storage_m3 = starting_storage
	cumulative_inflow_m3 = 0.0
	cumulative_treated_demand_m3 = 0.0
	cumulative_process_waste_m3 = 0.0
	cumulative_drain_m3 = 0.0
	cumulative_spill_m3 = 0.0
	is_initialized = true

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
	var dt: float = context.dt
	var tick_count: int = context.current_tick
	
	# Calculate total active storage
	var current_storage: float = 0.0
	for unit in context.units_list:
		if unit is StorageUnit:
			current_storage += unit.volume_m3
			
	if not is_initialized:
		initialize(current_storage)
		return
		
	# Accumulate flow inputs from ExternalBoundaries in this tick
	for unit in context.units_list:
		if unit is ExternalBoundary:
			var flow_volume: float = unit.current_flow_m3s * dt
			match unit.boundary_type:
				&"SOURCE_INFLOW":
					cumulative_inflow_m3 += flow_volume
				&"TREATED_DEMAND":
					cumulative_treated_demand_m3 += flow_volume
				&"PROCESS_WASTE":
					cumulative_process_waste_m3 += flow_volume
				&"DRAIN":
					cumulative_drain_m3 += flow_volume
				&"SPILL":
					cumulative_spill_m3 += flow_volume
					
	# Calculate tolerance based on total volume scale and tick count
	var total_volume_scale: float = max(initial_storage_m3 + cumulative_inflow_m3, 1.0)
	var ticks: float = max(float(tick_count), 1.0)
	var tolerance: float = 1e-9 * total_volume_scale * sqrt(ticks)
	
	var r: Dictionary = report(current_storage)
	var err: float = abs(r.mass_balance_error_m3)
	
	if err > tolerance:
		var msg: String = "Mass Balance Violation: error is %f m3, tolerance is %f m3 (tick %d)" % [err, tolerance, tick_count]
		push_error(msg)
		
		# Append event to context (drained after tick/invariant check)
		var event: SimulationEvent = SimulationEvent.new(&"MassBalanceViolation", tick_count, {
			"error_m3": err,
			"tolerance_m3": tolerance,
			"report": r
		})
		context.pending_events.append(event)
		
		# Debug assertion
		assert(err <= tolerance, msg)
