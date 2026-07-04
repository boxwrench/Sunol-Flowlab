# Drinking Water Plant Digital Twin Sandbox

This repository implements a low‑poly, Godot‑based sandbox for simulating a surface‑water treatment plant.  The initial focus is on **mass‑balance simulation** and **visual clarity**, not on regulatory compliance or detailed hydraulics.  It allows you to build a process train of reservoirs, flash mixers, sedimentation basins, filters, clearwells, chlorine contact basins and treated‑water reservoirs and see how water levels and flows respond to valve changes, equipment outages and demand changes.

## Current status

The project is at the proof‑of‑concept stage.  Core simulation components have been outlined and documentation has been written; no compiled binary exists yet.  Please review the documents in the `docs/` directory for detailed requirements, simulation rules and guidance.

## Running the project

1. Install Godot 4.x.
2. Clone this repository.
3. Open the project in Godot and run the **Main** scene.
4. To run headless tests, execute `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

## Testing

Automated tests are provided under `tests/`.  Run them with `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.  Every change to simulation behaviour must be accompanied by new tests according to the [testing strategy](docs/TESTING_STRATEGY.md).

## Implemented units

The first iteration includes definitions for generic storage nodes, junction nodes, flow links and controllers.  Future phases will introduce full modules for reservoirs, basins, filters and more.

## For AI agents

**Start here, every session, before any change:** follow the Cold-Start Protocol in [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md). Minimum required reading: [AGENTS.md](AGENTS.md) (binding rules, including the failure-mode guardrails), then [docs/REPOSITORY_ARCHITECTURE.md](docs/REPOSITORY_ARCHITECTURE.md), then your assigned work package. Do not work from a task prompt or prior-context summary alone.

## Documentation

- [Project scope](docs/PROJECT_SCOPE.md)
- [Repository architecture](docs/REPOSITORY_ARCHITECTURE.md)
- [Simulation rules](docs/SIMULATION_RULES.md)
- [Control logic](docs/CONTROL_LOGIC.md)
- [Process unit contracts](docs/PROCESS_UNIT_CONTRACTS.md)
- [Plant topology](docs/PLANT_TOPOLOGY.md)
- [Internal units](docs/INTERNAL_UNITS.md)

This sandbox is **not** intended to be a regulatory digital twin.  It omits complex hydraulics, chemistry and compliance calculations.
