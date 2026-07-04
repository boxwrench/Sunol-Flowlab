class_name UnitConversion
extends RefCounted

# Conversion constants from INTERNAL_UNITS.md
const CUBIC_METERS_TO_GALLONS: float = 264.172052
const SECONDS_PER_DAY: float = 86400.0

# Naming from INTERNAL_UNITS.md
const GALLONS_PER_DAY_TO_M3S: float = 0.043812637

# Exact conversion factor for MGD <-> m3/s
# 1 MGD = 1,000,000 gallons / day = 1,000,000 * (1 / 264.172052) m3 / 86400 s
const MGD_TO_M3S: float = 1000000.0 / (CUBIC_METERS_TO_GALLONS * SECONDS_PER_DAY)
const M3S_TO_MGD: float = 1.0 / MGD_TO_M3S

# Elevation/Depth ft <-> m
const FT_TO_M: float = 0.3048
const M_TO_FT: float = 1.0 / FT_TO_M

# Volume MG <-> m3
# 1 MG = 1,000,000 gallons / CUBIC_METERS_TO_GALLONS m3
const MG_TO_M3: float = 1000000.0 / CUBIC_METERS_TO_GALLONS
const M3_TO_MG: float = 1.0 / MG_TO_M3

static func mgd_to_m3s(mgd: float) -> float:
	return mgd * MGD_TO_M3S

static func m3s_to_mgd(m3s: float) -> float:
	return m3s * M3S_TO_MGD

static func ft_to_m(ft: float) -> float:
	return ft * FT_TO_M

static func m_to_ft(m: float) -> float:
	return m * M_TO_FT

static func mg_to_m3(mg: float) -> float:
	return mg * MG_TO_M3

static func m3_to_mg(m3: float) -> float:
	return m3 * M3_TO_MG
