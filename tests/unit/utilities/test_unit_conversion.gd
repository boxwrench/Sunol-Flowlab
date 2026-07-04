extends "res://addons/gut/test.gd"

func test_round_trip_mgd_m3s() -> void:
	var original_mgd: float = 1.5
	var m3s: float = UnitConversion.mgd_to_m3s(original_mgd)
	var round_trip_mgd: float = UnitConversion.m3s_to_mgd(m3s)
	var diff: float = abs(round_trip_mgd - original_mgd)
	var relative_diff: float = diff / original_mgd
	assert_lt(relative_diff, 1e-12, "MGD round trip relative difference should be less than 1e-12")

func test_round_trip_ft_m() -> void:
	var original_ft: float = 10.0
	var m: float = UnitConversion.ft_to_m(original_ft)
	var round_trip_ft: float = UnitConversion.m_to_ft(m)
	var diff: float = abs(round_trip_ft - original_ft)
	var relative_diff: float = diff / original_ft
	assert_lt(relative_diff, 1e-12, "ft round trip relative difference should be less than 1e-12")

func test_round_trip_mg_m3() -> void:
	var original_mg: float = 2.5
	var m3: float = UnitConversion.mg_to_m3(original_mg)
	var round_trip_mg: float = UnitConversion.m3_to_mg(m3)
	var diff: float = abs(round_trip_mg - original_mg)
	var relative_diff: float = diff / original_mg
	assert_lt(relative_diff, 1e-12, "MG round trip relative difference should be less than 1e-12")
