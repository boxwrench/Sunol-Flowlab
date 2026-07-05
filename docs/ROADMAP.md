# Project Roadmap

This roadmap organises development into numbered phases matching the rest of the
repository (Phase 0–3 delivered, Phase 4 next). Detailed per-phase work packages live
in the `*_IMPLEMENTATION_PLAN.md` documents; this file is the high-level map and status.
Dates are intentionally omitted to allow flexibility.

**Authority note:** per `docs/INDEX.md`, `REPOSITORY_ARCHITECTURE.md` and the binding
specs win all conflicts. Where this roadmap and a phase plan disagree on scope, the phase
plan governs the work — and this file must be updated to match rather than the reverse.

## Status at a glance

| Phase | Scope | Status |
|-------|-------|--------|
| Phase 0 — Project Foundation | clock, engine shell, tick pipeline, CI, base classes | ✅ Delivered |
| Phase 1 — Single Storage-Unit Prototype | mass-balance ledger, config load, snapshot, phase-1 verification | ✅ Delivered |
| Phase 2 — Three-Unit Flow Sandbox | source→basin→receiver flow propagation, closed-loop level control | ✅ Delivered |
| Phase 3 — Headworks + Sedimentation | reservoirs, manifold, flash mix, distribution box, 5 basins, applied channel, availability, 5 level loops |  Delivered — **pending exit gate (WP3.8 batch audit)** |
| Phase 3.5 — Self-Regulating Hydraulics (WP4.0) | implement GRAVITY flow mode; re-baseline Phase 3 hydraulics | ⬜ Next |
| Phase 4a — Filtration + Clearwell | 12 filters, clearwell, filter flow splitting, one clearwell level loop | ⬜ Planned |
| Phase 4b — Contact + Treated Water | 2 CT basins, treated-water reservoir, treated-water demand, plant flow control (cascade) | ⬜ Planned |

## Cross-cutting workstreams

### Continuous testing (CI)
- GitHub Actions runs the full GUT test suite and config-schema validation on every
  push to `main`. A green run means the suite passed — that's the signal a change is
  good; if CI goes red, fix it before building on top. CI runs on GitHub's servers
  in the background, so there's nothing to wait on — push and check back.
- When you add or remove a test script, update `EXPECTED_SCRIPTS` in the workflow.

### Hydraulic design basis (prerequisite for Phase 4a)
- Maintain the authoritative design-basis table in `docs/PLANT_TOPOLOGY.md`. Every future
  `max_flow_m3s` value must cite it. Phase 3's 15-vs-12 trunk defect was the direct result
  of having no design basis; the filter phase multiplies that exposure.

### Telemetry & trends (near-term)
- Implement a minimal ring-buffer trend historian behind `_step_record_telemetry()`
  (currently a `pass` stub) with simple UI overlays, per the scope goals. Beyond being a
  stated goal, it makes control diagnostics (e.g. limit cycles) observable without
  throwaway debug scripts.

## Phase 3.5 / WP4.0 — Self-regulating hydraulics (next)

The Phase 3 control effort — limit cycles at any gain, the velocity-PID escalation —
traced to a plant with **zero self-regulation**: every downstream demand is a fixed-max,
unactuated link. `SIMULATION_RULES.md` already specifies flow mode 3 (flow ∝ valve · √head)
and `flow_link.gd` stubs it with a warn-once fallback. Implementing it makes basin and
channel outflow level-dependent — self-regulating — and makes the Phase 4 clearwell and CT
control problems materially easier.

**Sequencing note:** lightweight in code, heavy in re-verification. It changes existing
Phase 3 steady-states, so it must land as its own gated WP that re-tunes the five Phase 3
controllers and re-baselines the headworks and verification tests, with full determinism
and mass-balance reverification. It is sequenced **before** Phase 4a so the filters build
on self-regulating hydraulics.

## Phase 4 — Filtration through Treated Water (split)

Phase 3 required a mid-phase structural escalation; Phase 4's original single-phase scope
is roughly twice Phase 3's surface area, so it is split at a natural batch-audit boundary:

- **Phase 4a — Filters + clearwell.** Reuses Phase 3 patterns (proration-based splitting,
  one level loop), ideally on top of GRAVITY mode.
- **Phase 4b — CT basins + treated-water reservoir + plant flow control.** Introduces the
  first two-layer (cascade / supervisory) control loop, driven by treated-water level —
  which gets its own spec-first WP, the way basin availability did.

Detailed WPs will be authored in `PHASE4_IMPLEMENTATION_PLAN.md` after the Phase 3 exit
gate closes.

## Future enhancements

- **Cyclic topology support (recycle streams).** A single structural capability — the
  DAG-only solver rejects cycles today — and the shared precondition for backwash /
  filter-to-waste return, backwash waste handling, **and** any wastewater port. Grouped so
  the dependency is explicit.
- Backwash sequences and filter-to-waste (depends on cyclic topology).
- Coagulant dosing and simplified chemistry.
- Interlocks / permissives (specced in `CONTROL_LOGIC.md`, unimplemented; first matters at
  the filter phase for service-state preconditions).
- Hydraulic grade line calculations with pump curves (the heavyweight hydraulics; distinct
  from the near-term GRAVITY mode above).
- Scenario scripting and training modules.
- Historian playback and data export (the full version; the near-term trend buffer above is
  the minimal slice).
- Port the engine to other utilities (e.g. wastewater). ~95% portable at the code level
  (boundary labels, ledger fields, display vocabulary), **but requires cyclic topology
  support first** — a wastewater plant is built around recycle streams (return activated
  sludge, supernatant returns, backwash recovery) that the DAG solver cannot represent. See
  the portability appendix in `docs/BUILDING_A_PLANT_SIMULATOR.md`.
- Integration with Node-RED, MQTT or external control systems — gated post-POC behind a
  versioned snapshot/command API; not required by the scope doc's completion criteria.

> Removed: "PID control with anti-reset windup." It is shipped — WP3.5 delivered a
> velocity-form PID whose output clamping inherently avoids reset windup. The residual
> control work is bumpless transfer on AUTO entry (WP3.5-R) and per-loop tuning guidance.

## Out of scope

- Real-time multiplayer operations.
- Detailed CFD or finite element analysis.
- Regulatory compliance calculations.
- Live SCADA connections for a specific plant.
