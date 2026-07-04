extends "res://addons/gut/test.gd"

func test_solve_fill() -> void:
	var res: Dictionary = StorageBalance.solve(10.0, [2.0, 3.0], 1.0, 0.0, 100.0, 80.0, 1.0)
	
	assert_eq(res.new_volume_m3, 14.0, "Volume should be 10 + 5 - 1 = 14")
	assert_eq(res.actual_inflow_m3s, 5.0)
	assert_eq(res.actual_outflow_m3s, 1.0)
	assert_eq(res.actual_drain_flow_m3s, 0.0)
	assert_eq(res.actual_spill_flow_m3s, 0.0)

func test_solve_drain() -> void:
	var res: Dictionary = StorageBalance.solve(10.0, [0.0], 2.0, 1.0, 100.0, 80.0, 1.0)
	
	assert_eq(res.new_volume_m3, 7.0, "Volume should be 10 - 2 - 1 = 7")
	assert_eq(res.actual_inflow_m3s, 0.0)
	assert_eq(res.actual_outflow_m3s, 2.0)
	assert_eq(res.actual_drain_flow_m3s, 1.0)
	assert_eq(res.actual_spill_flow_m3s, 0.0)

func test_solve_spill() -> void:
	var res: Dictionary = StorageBalance.solve(78.0, [5.0], 0.0, 0.0, 100.0, 80.0, 1.0)
	
	assert_eq(res.new_volume_m3, 80.0, "Volume should clamp to spill volume (80)")
	assert_eq(res.actual_spill_flow_m3s, 3.0, "Spill flow should be 78 + 5 - 80 = 3.0 m3/s")

func test_solve_proration() -> void:
	# Over-withdrawal proration case:
	# outlet requests 3.0, drain requests 2.0, only 4.0 available volume (current + inflow)
	# total request = 5.0 volume. proration = 4.0 / 5.0 = 0.8
	# granted outflow = 3.0 * 0.8 = 2.4
	# granted drain = 2.0 * 0.8 = 1.6
	var res: Dictionary = StorageBalance.solve(1.0, [3.0], 3.0, 2.0, 10.0, 8.0, 1.0)
	
	assert_almost_eq(res.actual_outflow_m3s, 2.4, 1e-9, "Outflow should be prorated to 2.4")
	assert_almost_eq(res.actual_drain_flow_m3s, 1.6, 1e-9, "Drain should be prorated to 1.6")
	assert_eq(res.new_volume_m3, 0.0, "Final volume should be exactly 0")
	assert_eq(res.actual_spill_flow_m3s, 0.0)
