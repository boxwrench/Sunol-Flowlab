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

Simulation code **must not** depend on presentation code.  The mass‑balance engine and controllers belong under `scripts/simulation/` and should be testable without loading any Godot scenes.  Controllers should not call UI functions, and scene scripts should not contain simulation logic.

- **No Autoloads or Node inheritance in domain**: Domain classes must extend `RefCounted` only, never `Node`. Domain code must never reference autoloads (e.g., `CommandBus` or `EventBus`) directly.
- **No External Signals**: Domain classes must not emit signals to external objects. Instead, events are appended to the `SimulationContext` and flushed to the application layer after invariant validation.
- **Strict Scope Guard**: Do not create files for future phases or implement modules not required by the current phase's exit condition.

## Unit conventions

The simulation operates internally in SI units (m³, m³/s, metres, seconds).  Conversion to U.S. customary units (MGD, MG, feet, hours) happens in the UI.  Do not hard‑code unit conversions in simulation classes.

## Verification and failure-mode guardrails

Each rule below exists because the failure it names actually occurred in this repository (see `docs/PHASE1_CODE_REVIEW.md`). These rules are binding.

1. **Proof of execution, or say "unverified".** Never state that tests pass without including the actual test-runner output (total collected, passed, failed) in the commit or PR description. If the runner cannot be executed in your environment, the required wording is: "Tests written but NOT executed — unverified." Zero collected tests is a failure, not a pass. *(Occurred: entire suite referenced an uninstalled framework; every "tests pass" claim was false.)*

2. **Referenced dependencies must exist in the same commit.** If code references a file, addon, or class (e.g., `res://addons/gut/test.gd`), that dependency must be present in the repository when the commit lands. *(Occurred: GUT was never committed.)*

3. **Never reimplement the system under test.** Tests must instantiate production classes (`SimulationEngine`, `PlantFactory`, real config). A test double may stub *inputs*; it may never re-create tick, solver, or balance logic. If production code lacks behavior a test needs, that is a production bug — fix the engine, not the test. *(Occurred: a `MockSolveEngine` reimplemented the tick correctly and the invariant test proved the mock.)*

4. **Every hook must have a real caller and a real implementation, wired in the same commit.** Do not add `has_method`-style duck-typed dispatch: call concrete methods on concrete types so missing implementations fail loudly. A deliberately empty pipeline step must be `pass` with a comment naming the WP that fills it. *(Occurred: the actuator-update step called a method no class implemented; valves silently never moved.)*

5. **One implementation per behavior — search before writing.** Before writing any hydraulic, flow, or balance logic, grep for an existing class that does it and call it. Never leave a class in the tree that the production path does not use. *(Occurred: `FlowSolver` existed as dead code while the engine duplicated its logic inline.)*

6. **Report scope honestly; never renumber.** Commit messages and PR descriptions must use WP numbers exactly as defined in `docs/IMPLEMENTATION_PLAN.md`. If a WP is partially done or skipped, state it explicitly: "WP1.5 SKIPPED — snapshot service not built." Completing WP N+2 does not imply WP N+1. *(Occurred: commits renumbered WPs so skipped deliverables looked finished.)*

7. **No correctness by coincidence.** ID sort order, dictionary insertion order, and naming conventions exist for deterministic *iteration* only — semantic correctness must never depend on them. If computation B needs the result of computation A, express that ordering explicitly in the tick pipeline. *(Occurred: the mass-balance ledger was only correct because "BASIN_01" happened to sort before its sinks.)*

8. **Branch on typed fields, never on ID substrings.** Use contract enums (`port_type == &"DRAIN"`), never string matching on identifiers (`"drain" in String(port_id)`). If the needed enum value is missing, add it to the contract and the doc. *(Occurred: drain ports were detected by substring match.)*

9. **Every clamp is ledgered or asserted.** Any `min`/`max`/clamp on a volume or flow must either feed the mass-balance ledger or be a debug `assert` proving it is unreachable. Silent truncation of water is an INV-1 violation even when the current config makes it a no-op. *(Occurred: an unledgered `min(volume, max_volume)` sat after spill calculation.)*

10. **Configuration fields must be enforced or deleted.** Do not accept a config parameter the code ignores (e.g., a declared `flow_limit_m3s` nothing checks). Wire it or remove it and note the removal.

11. **Clean handoff.** End every task with `git status` clean: commit or revert everything. After any bulk file write, verify the last line of each written file is intact — truncated writes have corrupted this repository before. Never hand off mid-write.

12. **All deliverables live inside the repository.** Never write plans, specs, reports, or any referenced file to a scratch, brain, artifact, or tool-internal folder (e.g., `~/.gemini/.../brain/...`). Those locations are invisible to the orchestrator, to git, to other agents, and to future sessions. Every file you mention in a report must exist at a repo-relative path and be committed. If your tooling drafts in a scratch location, copying it into the repo and committing it IS the deliverable step — a report referencing an uncommitted scratch file counts as work not done. *(Occurred: a Phase 2 plan was reported as delivered but existed only in an agent's brain folder.)*

13. **Config schema sync.** Any addition or change to a plant-config field updates the matching schema in `config/schema/` and `scripts/configuration/plant_validator.gd` in the same commit. `tools/ci/validate_configs.sh` must pass. Field documentation lives in the schema `description` — do not duplicate it in prose docs.

## Development checklist

Before completing a task, an agent should:

1. Run the relevant unit and integration tests and capture the runner output (guardrail 1).
2. Verify that no negative storage can occur.
3. Confirm that simulation code does not depend on visual scenes.
4. Update configuration schemas if fields changed.
5. Update documentation and `CHANGELOG.md` if behaviour changed.
6. Report changed files, what was NOT done, and remaining limitations.
7. Confirm `git status` is clean and edited files are not truncated (guardrail 11).

## Prohibited actions

- Do **not** implement CFD, pressure‑network solvers or detailed water chemistry.
- Do **not** silently change unit systems.
- Do **not** duplicate logic across similar units; reuse generic components instead.
- Do **not** merge untested changes.

Failure to follow this guidance may result in incorrect simulations or broken pipelines.
