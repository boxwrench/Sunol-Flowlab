# WP4.5 — Startup and configured alarms

Local verification performed on 2026-10-01 with official Godot
`4.7.stable.official.5b4e0cb0f` and committed GUT 9.7.0.

## Resulting behavior

The main headworks scene builds startup state from the same committed initial conditions
as a headless plant. Its four upstream demonstration valve targets are configured before
the first snapshot, with actual positions still closed so normal actuator travel is
preserved. There are no hidden scene-local startup commands.

The bootstrap registers both applied-channel threshold alarms directly with the existing
alarm engine. The top-left panel displays active/clear text, symbols, and the snapshot
tick. It reads snapshots without modifying domain state. Map loading uses the existing
`PresentationMapHandler.load_map()` implementation.

Only existing initial-condition values changed; no config fields or schema contracts
were added. The CI script-count guard is updated to 34; deriving it remains WP4.6.

## Executed checks

The new integration regression initially ran against the old bootstrap:

```text
Scripts               1
Tests                 4
Passing Tests         1
Failing Tests         3
```

After the implementation, the complete production suite ran with:

```text
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Final runner output:

```text
Scripts              34
Tests               106
Passing Tests       106
Asserts           513364
Time              185.502s
---- All tests passed! ----
```

Collected: 106. Passed: 106. Failed: 0. The runner omits the `Failing Tests` line when zero.
Exit code: 0. No script/parse errors or silently skipped test scripts were reported.

Pull-request CI also passed both `test` and `config-schema` jobs in
[run 36955569604](https://github.com/boxwrench/Sunol-Flowlab/actions/runs/36955569604).
Delivery to main is through [PR #9](https://github.com/boxwrench/Sunol-Flowlab/pull/9);
the roadmap's delivered status is gated by green CI on main as usual.

The suite includes configured first-snapshot parity, same-command headless/main-scene
parity through each of the five basin outages and returns, high-alarm activation and
clearing with exactly one event per transition, an empty-start low alarm, low-alarm delay
reset/deadband behavior, and immutable same-tick alarm presentation. Existing replay,
mass balance, no-negative-storage, and 100,000-tick soak/churn tests also executed.

The manifold-combining regression exposed an obsolete startup-dependent numeric baseline.
It now checks its stated contract: both reservoirs contribute nonzero flow, and manifold
inflow equals the sum of the actual reservoir outlet flows. No solver math was changed.

`bash tools/ci/validate_configs.sh` exited 0: all 18 plant JSON files accepted and all
6 deliberately invalid fixtures rejected. A source scan found no Node inheritance,
presentation/scene dependencies, or autoload references in `scripts/simulation/`.

## Rendered main-scene check

Executed the committed capture runner with a graphical Godot build:

```text
godot --path . --rendering-method gl_compatibility --resolution 1440x900 -s tools/verification/capture_wp45.gd
```

The runner loads the real main scene and advances the production engine. It first captures
the configured startup, then disables the demand link to fill the channel and activate
the high alarm. It restores demand and commands all five basins out of service to clear
the alarm. Captures were visually inspected: the alarm panel is readable, shows
`[!] ACTIVE` with one active alarm at tick 100, and returns to `[OK] CLEAR` at tick 200.

- [Configured startup, tick 0](images/wp45-startup.png)
- [High alarm active, tick 100](images/wp45-high-alarm.png)
- [Alarm cleared and five-basin outage, tick 200](images/wp45-cleared-outage.png)

Output: `WP4.5 rendered main scene: startup, high alarm, clearing, five-basin outage verified.`
Exit code: 0. This is automated rendered verification plus screenshot inspection, not a
human blind-read study or independent WP4.7 gate closure.

## Remaining limitations and deferred work

- The low-alarm threshold equals the channel's 0.5 m outlet cutoff. Normal demand stops
  at that level and does not activate the strictly-below-threshold alarm. The test uses a
  valid empty initial channel. No thresholds, cutoff behavior, or hydraulics were changed.
- Existing shutdown cleanup diagnostics remain: the complete suite reports 4,815 leaked
  ObjectDB instances and 6 resources still in use. The pre-fix regression already reported
  739 instances and 6 resources; the actual main-scene capture reports 129 and 6. These
  diagnostics do not change the runner's zero exit code, but cleanup is unresolved.
- Existing right-side asset/service panels overlap and clip text at 1440×900. The new
  alarm panel is separately readable; wider UI layout work is not included here.
- The system `godot` command still resolves to 4.5; this verification used official 4.7.
- WP4.6, WP4.7, filters, clearwell, and downstream treatment were not implemented.

## Asset reuse findings

The repository already contains reusable basin, pipe, and enclosure GLB models with an
[asset manifest](../assets/licenses/asset_manifest.csv). The presentation map supports
mesh replacement. For later visual work, Kenney's
[City Kit (Industrial)](https://kenney.nl/assets/city-kit-industrial) and
[Factory Kit](https://kenney.nl/assets/factory-kit) are candidate sources; both official
pages list CC0 licensing. No external models were imported or claimed as verified here.
