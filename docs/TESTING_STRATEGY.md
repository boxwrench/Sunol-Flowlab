# Testing Strategy

Reliable simulation requires robust automated testing.  This document outlines the types of tests to be implemented and the expectations for new contributions.

## Unit tests

Unit tests verify the behaviour of individual classes:

- **Storage nodes:** mass balance, spill logic, drain logic.
- **Flow links:** flow modes, valve positions, capacity limits.
- **Controllers:** proportional control, flow splitting, lead‑lag behaviour.
- **Alarms:** activation and clear conditions, delays and deadbands.

Each test should exercise one behaviour and assert against expected values.  Use headless Godot execution to run tests without rendering.

## Integration tests

Integration tests assemble multiple units into a small network (e.g., source → basin → receiver) and verify that flows and levels propagate correctly.  Include cases such as:

- Emptying a source node.
- Filling a receiving node.
- Closing valves and observing upstream level rise.

## Plant‑wide invariant tests

These tests run the full plant configuration and check global invariants:

- **Mass conservation** – sum of volumes and external sources minus sinks remains constant.
- **No negative storage** – volumes never drop below zero.
- **Spills only above spill elevation**.
- **No flow through closed equipment**.

Use accelerated time to simulate extended operation and check invariants.

## Scenario regression tests

Define a set of named scenarios (e.g., loss of one source reservoir, sedimentation basin isolation, filter capacity reduction).  For each scenario:

1. Start from a known initial condition.
2. Apply specific changes (e.g., close reservoir outlet).
3. Run the simulation for a period.
4. Compare key outputs (levels, flows, alarm states) against stored baseline data.

If simulation code changes, regenerate baseline data only when intentionally changing behaviour.

## Numerical tolerances

Define an epsilon for floating‑point comparisons.  Use `abs(actual - expected) ≤ tolerance` rather than strict equality.

## Test fixtures

Store JSON fixtures for plant configurations, initial conditions and controller settings under `simulation/tests/fixtures/`.  Tests should load these fixtures and avoid hard‑coding values.

## Headless test command

Run all tests from the command line:

```
godot --headless --script res://simulation/tests/test_runner.gd
```

Include this command in continuous integration workflows.

## Regression policy

Every hydraulic bug or unexpected behaviour discovered must result in a new test that fails without the fix and passes with the fix.  This prevents regressions in future changes.
