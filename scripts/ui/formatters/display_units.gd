class_name DisplayUnits
extends RefCounted

static func format_flow(m3s: float) -> String:
	var mgd: float = UnitConversion.m3s_to_mgd(m3s)
	return "%.2f MGD" % mgd

static func format_level(m: float) -> String:
	var ft: float = UnitConversion.m_to_ft(m)
	return "%.2f ft" % ft

static func format_volume(m3: float) -> String:
	var mg: float = UnitConversion.m3_to_mg(m3)
	return "%.3f MG" % mg
