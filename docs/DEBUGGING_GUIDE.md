# Debugging Guide

This guide lists common issues that may arise during simulation development and suggestions for diagnosing them.

## Water disappearing

- Ensure that every inflow and outflow is accounted for in the mass balance equation.
- Check for negative volumes and clamp values to zero.
- Verify that spills and drains are recorded as external sinks and removed from the volume.

## Water being created

- Check that inflow does not exceed the available volume from the upstream source.
- Inspect flow links for incorrect flow modes or missing capacity limits.
- Ensure that no unit resets its volume without accounting for outflows.

## Negative volumes

- Clamp volumes to zero when subtracting outflows.
- Review the order of operations: flows must be calculated before volumes are updated.
- Increase numerical tolerance to avoid floating‑point drift.

## Simulation changes with frame rate

- Use a fixed simulation time step independent of rendering.
- Do not perform simulation updates in the `_process()` function; use `_physics_process()` with a fixed delta.

## Incorrect split flow

- Verify that the flow splitter controller correctly identifies in‑service units.
- Ensure that maximum capacities are honoured and excess flow is redistributed.
- Check that percentage splits sum to 100%.

## Valve animation differs from actual position

- Confirm that the valve model updates its visual representation based on the `position` field rather than the `commanded_position`.
- Check animation keyframes and ensure they cover the full 0–100% range.

## Configuration ID mismatch

- Make sure that IDs in the JSON configuration match those referenced in the topology and scene map.
- Use `docs/TAG_NAMING.md` to construct valid IDs.

## Scene not finding simulation snapshot

- Ensure that presentation adapters subscribe to the correct simulation IDs.
- Check that the snapshot is published after each simulation tick and before the UI updates.

## Controller oscillation

- Reduce the controller gain or introduce a deadband.
- Increase sample time or add integral action carefully.
- Check for conflicting controllers acting on the same valve or flow.

Following this guide should resolve most common issues.  For persistent problems, write a failing test case that reproduces the behaviour and fix the underlying logic before adding new features.
