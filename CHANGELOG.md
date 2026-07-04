# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] - 2026-07-04

### Added
- Completed **WP1.1 (Domain Base Classes)**: ProcessUnit, StorageUnit, ExternalBoundary, FlowPort, SimValve, FlowLink.
- Completed **WP1.2 (Storage Balance & Mass Ledger)**: StorageBalance 1D Euler integrator, MassBalanceTracker validation logic.
- Completed **WP1.3 (Config Loading & Validation)**: ConfigLoader, PlantValidator (DAG cycle and dangling port verification), PlantFactory.
- Completed **WP1.4 (Solver Step & Alarms)**: FlowSolver, ThresholdAlarm, AlarmEngine.
- Completed **WP1.5 (Snapshot Service)**: SnapshotService deep-copy snapshot capture with mutation-guard checks.
- Completed **WP1.6 (Presentation + UI Slice)**: `generic_basin.tscn` 3D visual, Storage/Valve/WaterSurface visual adapters, `AssetPanel` instrumentation control panel.
- Completed **WP1.7 (Phase 1 Verification Suite)**: High-fidelity demonstrations, extended soak, deterministic replay, and headless-to-presentation parity tests.
- Committed GUT 9.x to the repository and added verification checks in CI.

### Changed
- Wired valve updates via FlowLinks and SimulationContext actuators list, eliminating duck-typing.
- Moved flow boundaries calculations and proration out of domain classes to engine step `_step_calculate_levels_spills`.
- Replaced ID substring-based drain matching with explicit `DRAIN` port type.
- Replaced silent clamping in StorageBalance with debug assertion.

### Fixed
- Fixed mass balance validation errors by registering ports on parent units in tests.
- Fixed CI runner configuration to enforce that tests run and fail on zero collected tests.
- Reorganized documentation structure by cleaning up root-level duplicate documents and consolidating references.
