# WP4.7 — Headworks and gravity exit verification

Verified the shipped main revision `4b97453ad3a28507fb8850a2f34e2ea8ec2c1ba8` after the
visual corrections. This is a fresh production-main run and rendered verification,
not a claim that prior implementation commits alone closed the gate. No simulation
code, plant tuning, capacities, initial conditions or schema fields changed in WP4.7.

## Executed production test evidence

[Main CI run 36963614652](https://github.com/boxwrench/Sunol-Flowlab/actions/runs/36963614652)
completed successfully on Godot 4.7 / GUT 9.7.0. Its actual runner summary:

```text
Scripts              34
Tests               110
Passing Tests       110
Asserts           513421
Time              242.079s
Verified 34 of 34 test scripts; Godot exit status 0.
```

Collected **110**, passed **110**, failed **0**. Zero failures are represented by the
omitted failing-test row plus the guarded runner's successful exit; zero collection,
script errors, skips and risky/pending tests are rejected. The real-GUT guardrail
probes also passed **9** checks with **0** failures.

| Required evidence | Executed production check |
|---|---|
| Replay | `test_deterministic_replay_phase3`, every tick of the 1,000-tick command trajectory |
| Mass conservation | Production ledger invariants, single-basin and headworks tests |
| No negative storage | Aggressive draining invariant; every tick of both headworks long runs |
| 100k-tick soak | `test_phase3_soak_100k_ticks`: 49,416.741 ms |
| 100k-tick churn | `test_availability_churn_100k_ticks`: 48,078.536 ms |
| Headless/visual parity | Real main-scene startup and every basin outage/return compared with headless production snapshots |
| Startup | Configured valve targets/actual travel, empty command queue and both configured alarm IDs |
| Gravity | Positive/zero/negative head, capacity limits and directed flow tests |
| Outages | Each of five basins, all-off demonstration, disabled normal links and enabled drains |
| Alarms | Configured high activation/clearing once, configured empty-start low activation once, delay/deadband tests, immutable snapshot display |

Local config validation on the audited checkout exited 0: **17** valid JSON files
accepted, **6** invalid fixtures rejected. Main CI's schema job and domain-inheritance
guard passed. A direct domain search found no scene paths, presentation/UI imports,
autoload references or Node inheritance. The existing solver/balance implementation
was used throughout; no surrogate tick, solver or mass-balance implementation was added.

## Rendered main-scene checks

Executed `tools/verification/capture_wp47.ps1` with the official graphical Godot 4.7
executable and OpenGL Compatibility. It calls the existing production-scene capture
tool with WP4.7 output names, preserving WP4.5's historical screenshots.

- [Startup, tick 0](images/wp47-startup.png): configured water levels, all five basins
  available, both alarm IDs visible and clear; no hidden startup commands.
- [High alarm, tick 100](images/wp47-high-alarm.png): demand-link closure makes the
  real engine fill the channel; its configured high alarm is visibly active.
- [Clearing and all-five outage, tick 200](images/wp47-cleared-outage.png): restored
  demand and production service commands clear the high alarm; all five basins show
  Offline and no normal flow. Ledger residual **0.000000000001 m³**; no negative storage.
- [Low alarm, tick 5](images/wp47-low-alarm.png): an empty channel and closed basin
  outlets are a valid temporary startup input. The real main-scene bootstrap loads
  that fixture, produces one low-alarm activation and shows it; channel level **0 m**,
  ledger residual **0 m³**. The harness restores exact original config text in `finally`;
  `git diff` confirmed no persistent initial-condition changes.

All four images were visually inspected. Both render invocations returned exit 0.
The low threshold equals the outlet cutoff: normal demand stops at 0.5 m, so ordinary
drawdown does not cross it. The empty-start demonstration is explicitly an input
fixture, not a claim that default operation empties the channel below its cutoff.

Reproduce from PowerShell:

```powershell
& tools/verification/capture_wp47.ps1 -GodotPath '<path to graphical Godot 4.7 executable>'
```

## Closure and remaining scope

WP4.7 closes the Phase 3 / WP4.1 headworks-gravity gate once this evidence is on main
with green CI. Phase 4a may then be planned and built. Filters, clearwell, contact
basins and treated-water storage were NOT implemented in this work package.

The audit corrected stale introductions in `SIMULATION_RULES.md`, `CONTROL_LOGIC.md`
and `PLANT_TOPOLOGY.md` to match already enforced flow/control contracts. These are
documentation corrections, not new modes or hydraulic behavior. No review-verdict
documents were edited or outside-review acceptance claimed.

Existing shutdown diagnostics remain (4,937 ObjectDB instances/6 resources in the
complete suite; 129/6 in the scene). Visual geography is illustrative and junction
labels can crowd. Human blind-read studies, lifecycle cleanup, downstream stages,
backwash, chemistry and pressure-network modeling were NOT done. Edited file endings
and `git diff --check` were verified; the completed handoff requires a clean worktree.
