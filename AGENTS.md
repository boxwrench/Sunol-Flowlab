# Guidance for AI Agents

This file defines how autonomous assistants such as Claude Code and Codex should interact with this repository.

## Required reading

Before making any changes, agents **must** read the following documents:

- `docs/PROJECT_SCOPE.md` – defines what belongs in the proof of concept and what is explicitly out of scope.
- `docs/PLANT_TOPOLOGY.md` – details the process units and how they connect.
- `docs/SIMULATION_RULES.md` – specifies the mass‑balance equations, fixed time step and flow constraints.
- `docs/CONTROL_LOGIC.md` – describes manual vs automatic operation, flow splitting and level control.
- `docs/PROCESS_UNIT_CONTRACTS.md` – defines interfaces for every process unit.
- `docs/TAG_NAMING.md` – details naming conventions for tags and identifiers.
- `docs/REPOSITORY_ARCHITECTURE.md` – explains how simulation code, configuration files and scenes are organised.

Agents should treat these documents as the canonical specification. On any structural conflict between docs, REPOSITORY_ARCHITECTURE.md wins. If a required field or rule is missing, add it to the appropriate document.

## Dependency rules

Simulation code **must not** depend on presentation code.  The mass‑balance engine and controllers belong under `simulation/` and should be testable without loading any Godot scenes.  Controllers should not call UI functions, and scene scripts should not contain simulation logic.

- **No Autoloads or Node inheritance in domain**: Domain classes must extend `RefCounted` only, never `Node`. Domain code must never reference autoloads (e.g., `CommandBus` or `EventBus`) directly.
- **No External Signals**: Domain classes must not emit signals to external objects. Instead, events are appended to the `SimulationContext` and flushed to the application layer after invariant validation.
- **Strict Scope Guard**: Do not create files for future phases or implement modules not required by the current phase's exit condition.

## Unit conventions

The simulation operates internally in SI units (m³, m³/s, metres, seconds).  Conversion to U.S. customary units (MGD, MG, feet, hours) happens in the UI.  Do not hard‑code unit conversions in simulation classes.

## Development checklist

Before completing a task, an agent should:

1. Run the relevant unit and integration tests.
2. Verify that no negative storage can occur.
3. Confirm that simulation code does not depend on visual scenes.
4. Update configuration schemas if fields changed.
5. Update documentation if behaviour changed.
6. Report changed files and remaining limitations.

## Prohibited actions

- Do **not** implement CFD, pressure‑network solvers or detailed water chemistry.
- Do **not** silently change unit systems.
- Do **not** duplicate logic across similar units; reuse generic components instead.
- Do **not** merge untested changes.

Failure to follow this guidance may result in incorrect simulations or broken pipelines.
