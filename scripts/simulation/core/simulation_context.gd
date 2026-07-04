class_name SimulationContext
extends RefCounted

var dt: float = 1.0
var current_tick: int = 0

# Registries: sorted arrays for deterministic iteration + dictionaries for fast lookup
var units_list: Array = []
var units_dict: Dictionary = {}

# Topological order of ProcessUnits — computed once by PlantFactory via Kahn's
# algorithm (lexicographic tie-breaking on unit_id).  Used by FlowSolver for
# deterministic two-pass sweep.  Empty until build_plant() succeeds.
var topological_units_list: Array = []

var links_list: Array = []
var links_dict: Dictionary = {}

var actuators_list: Array = []
var actuators_dict: Dictionary = {}

var controllers_list: Array = []
var controllers_dict: Dictionary = {}

# Pending events accumulated during tick execution
var pending_events: Array[SimulationEvent] = []

# Seeded Random Number Generator for deterministic domain calculations
var rng: RandomNumberGenerator

func _init() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 12345
