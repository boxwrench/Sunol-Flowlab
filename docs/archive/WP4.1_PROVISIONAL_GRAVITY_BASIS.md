# WP4.1 Provisional Gravity Hydraulic Design Basis

> [!IMPORTANT]
> **Historical. Non-binding. Not authoritative.**
>
> Provisional gravity hydraulic design basis used during WP4.1. First committed 2026-07-06.
>
> Current status: see [ROADMAP.md](../ROADMAP.md). Authority order: see [INDEX.md](../INDEX.md) §6.

This document records the provisional hydraulic elevation cascade synthesized for the `phase3_headworks` configuration re-baselined in WP4.1.

These values are provisional and will be reconciled against the real plant design documents in a subsequent phase.

## Design Rule
For each storage unit, a design operating level $L^*$ is chosen (sitting safely below the unit's spill level). The water-surface elevations are stepped monotonically downhill along the topological flow path. The floor elevation for each unit is then calculated as:
$$\text{floor\_elevation\_m} = \text{surface elevation} - L^*$$

The design-point head difference across each link is calculated as:
$$\text{design\_head\_m} = \Delta h_{\text{design}}$$

By setting $\text{design\_head\_m} = \Delta h$, the term $\sqrt{\Delta h / \text{design\_head\_m}} = 1.0$ at the design operating point. This ensures that the gravity link carries flow close to the restricted capacity design rate ($Q \approx Q_{\text{max}} \times \text{opening}$) when at the design point, keeping LevelControllers well-conditioned.

## Provisional Elevations Table

| Unit ID | Design Level $L^*$ (m) | Design Surface Elev (m) | Floor Elevation / Reference Head (m) |
| :--- | :---: | :---: | :---: |
| **EXTERNAL_SOURCE_01** | — | 20.0 | `reference_head_m = 20.0` |
| **EXTERNAL_SOURCE_02** | — | 20.0 | `reference_head_m = 20.0` |
| **RESERVOIR_01** | 5.0 | 18.0 | `floor_elevation_m = 13.0` |
| **RESERVOIR_02** | 5.0 | 18.0 | `floor_elevation_m = 13.0` |
| **MANIFOLD_01** | 2.0 | 16.0 | `floor_elevation_m = 14.0` |
| **FLASH_MIX_01** | 2.0 | 14.0 | `floor_elevation_m = 12.0` |
| **DIST_BOX_01** | 2.0 | 12.0 | `floor_elevation_m = 10.0` |
| **BASIN_01** ... **_05** | 3.0 | 9.0 | `floor_elevation_m = 6.0` |
| **APPLIED_CHANNEL_01** | 2.0 | 6.0 | `floor_elevation_m = 4.0` |
| **FILTER_FEED_01** | — | 4.5 | `reference_head_m = 4.5` |
| **DRAIN_SINK** | — | 0.0 | `reference_head_m = 0.0` |

## Per-Link Design Heads

| Link(s) | Design Head `design_head_m` (m) | Description |
| :--- | :---: | :--- |
| `LINK_IN_01`, `LINK_IN_02` | 2.0 | Source boundary $\rightarrow$ Reservoir |
| `LINK_OUT_RES_01`, `LINK_OUT_RES_02` | 2.0 | Reservoir $\rightarrow$ Manifold |
| `LINK_OUT_MAN_01` | 2.0 | Manifold $\rightarrow$ Flash Mix |
| `LINK_OUT_FM_01` | 2.0 | Flash Mix $\rightarrow$ Distribution Box |
| `LINK_OUT_DB_01` ... `_05` | 3.0 | Distribution Box $\rightarrow$ Basin |
| `LINK_OUT_BASIN_01` ... `_05` | 3.0 | Basin $\rightarrow$ Applied Channel |
| `LINK_OUT_AC_01` | 1.5 | Applied Channel $\rightarrow$ Filter Feed |
| `LINK_DRAIN_RES_01`, `_02` | 18.0 | Reservoir $\rightarrow$ Drain Sink |
| `LINK_DRAIN_BASIN_01` ... `_05` | 9.0 | Basin $\rightarrow$ Drain Sink |

## Re-baselining Scope
Only the `phase3_headworks` plant configuration and its associated integration/invariants tests were modified and re-baselined. The `phase1_single_basin` and `phase2_three_unit` configurations remain completely untouched, and their test expectations remain byte-identical.
