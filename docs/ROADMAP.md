# Project Roadmap

This roadmap organises development into stages.  Dates are intentionally omitted to allow flexibility.

## Documentation

- End-to-end build guide: `docs/BUILDING_A_PLANT_SIMULATOR.md` — assembles the domain model,
  config/schema/factory contract, add-a-component recipes, and verification machinery into a single
  tutorial, with a portability appendix. (Draft; the control-law subsection tracks WP3.5.)

## Current phase

- Finalise documentation (scope, simulation rules, unit contracts, control logic).
- Implement project foundation: simulation clock, basic test harness, empty Godot project.
- Build single storage‑unit prototype to validate mass balance and spill logic.

## Next phase

- Connect a three‑unit sandbox (source → basin → receiver) and test flow propagation and simple level control.
- Build headworks and five sedimentation trains: reservoirs, manifold, flash mix, distribution box, basins and applied channel.
- Implement flow splitting and basin availability.

## Later phase

- Add twelve filters, clearwell, two CT basins and treated‑water reservoir.
- Implement filter flow splitting, clearwell level control and CT basin splitting.
- Add treated‑water demand and optional plant flow control.

## Future enhancements

- Backwash sequences and filter‑to‑waste.
- Coagulant dosing and simplified chemistry.
- Hydraulic grade line calculations with pump curves.
- PID control with anti‑reset windup.
- Scenario scripting and training modules.
- Integration with Node‑RED, MQTT or external control systems.
- Historian playback and data export.
- Port the engine to other utilities (e.g. wastewater) — the solver is utility-agnostic; see the
  portability appendix in `docs/BUILDING_A_PLANT_SIMULATOR.md`.

## Out of scope

- Real‑time multiplayer operations.
- Detailed CFD or finite element analysis.
- Regulatory compliance calculations.
- Live SCADA connections for a specific plant.
