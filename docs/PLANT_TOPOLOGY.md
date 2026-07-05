# Plant Topology

This document describes the process network modelled in the drinking water plant sandbox.  It is a human‑readable complement to the JSON topology configuration file.

## Hydraulic Design Basis

This table is the authoritative source for link capacities. **Every `max_flow_m3s` value in
any plant config must trace to a row here.** When a new phase adds units, extend this table
first (spec-first), then set config capacities to match.

**Plant design flow (Phase 3 headworks): 10 m³/s** — set by the fixed treated-water demand
(`LINK_OUT_AC_01`), which equals the sustainable trunk supply. Capacities upstream carry
margin over this basis; capacities are intentionally NOT uniform.

| Stage | Link(s) | Count × cap (m³/s) | Total | Margin vs 10 | Notes |
|-------|---------|--------------------|-------|--------------|-------|
| Raw sources | LINK_IN_01/02 | 2 × 10 | 20 | +100% | Over-provisioned; sources never limiting |
| Reservoir outlets | LINK_OUT_RES_01/02 | 2 × 8 | 16 | +60% | |
| Trunk (manifold→flash→dist-box) | LINK_OUT_MAN_01, LINK_OUT_FM_01 | 1 × 12 (series) | 12 | +20% | Plant spine; single-file series path |
| DB → basin inlet gates | LINK_OUT_DB_01..05 | 5 × 3 | 15 | +50% | Actuated; ~2.0/3.0 (~67% open) at steady state |
| Basin outlets | LINK_OUT_BASIN_01..05 | 5 × 4 | 20 | +100% | |
| Applied-channel demand | LINK_OUT_AC_01 | 1 × 10 | 10 | basis | Fixed, unactuated — sets the design flow |
| Reservoir drains | LINK_DRAIN_RES_01/02 | 2 × 5 | — | — | DRAIN category; enabled out-of-service |
| Basin drains | LINK_DRAIN_BASIN_01..05 | 5 × 2 | — | — | DRAIN category |

**Coherence rule (must hold every phase):** fixed demand (10) < trunk (12) < DB gate total
(15). This gives the five level controllers real authority margin. The WP3.4 defect was a
violation of this rule (trunk 12 vs an original AC demand of 15); `cf64d5e` restored it by
setting the demand to 10.

**Non-self-regulation caveat:** the applied-channel demand is a fixed-max *unactuated* link,
so the Phase 3 plant has no self-regulation — this is what makes the level loops hard (see
Phase 3.5 / WP4.0, GRAVITY flow mode, in `ROADMAP.md`). Record any change to this design
choice here.

## Process‑flow diagram

```
Surface Water Reservoir 1 ─┐
                           ├─> Inlet Manifold
Surface Water Reservoir 2 ─┘
                                  │
                                  ▼
                            Flash Mix
                                  │
                                  ▼
                           Distribution Box
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
        Floc/Sed Basin 1    Floc/Sed Basin 2    Floc/Sed Basin 3
              ▼                   ▼                   ▼
        Floc/Sed Basin 4    Floc/Sed Basin 5
              └───────────────────┬───────────────────┘
                                  ▼
                            Applied Channel
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
      Filter 1                Filter 2                Filter 3
         ...                     ...                     ...
      Filter 10               Filter 11              Filter 12
          └───────────────────────┬───────────────────────┘
                                  ▼
                              Clearwell
                                  │
                   ┌──────────────┴──────────────┐
                   ▼                             ▼
             CT Basin 1                    CT Basin 2
                   └──────────────┬──────────────┘
                                  ▼
                     Treated Water Reservoir
                                  │
                                  ▼
                         System Demand
```

## Unit descriptions

### Surface water reservoirs

Two raw‑water storage reservoirs provide supply to the plant.  Each has its own outlet valve and can be operated independently or together.  The inlet manifold combines their flows.

### Inlet manifold

Modelled in the simulation as a small `StorageUnit` (e.g. surface area $1.0\text{ m}^2$) to avoid algebraic coupling. It combines reservoir outflows and sends total plant influent to the flash mix. It enforces throughput limits and reports low‑flow and high‑flow alarms.

### Flash mix

A small mixing chamber for chemical addition. It has limited storage and can enable or disable coagulant injection. For the proof of concept, no chemistry model is implemented.

### Distribution box

Modelled in the simulation as a small `StorageUnit` (e.g. surface area $1.0\text{ m}^2$) to avoid algebraic coupling. It splits the flash mix effluent among five parallel sedimentation/flocculation basins. It can split flow evenly or according to operator‑specified percentages. The distribution box enforces per‑basin capacity and raises alarms when flow cannot be delivered.

### Flocculation/sedimentation basins

Five trains remove suspended solids.  Each is represented as a single storage unit with an inlet gate, outlet gate and drain.  Real units would have separate flocculation and sedimentation sections; those details are abstracted here.

### Applied channel

Combines effluent from all sedimentation basins and feeds the filters.  Its level is sensitive to filter availability.  High‑level alarms, high‑high spill conditions and low‑level filter starvation conditions are generated here.

### Filters

Twelve parallel filters remove fine particles.  Each filter has a maximum filtration rate and can be taken in or out of service.  Backwash sequences are not implemented in the proof of concept.

### Clearwell

Collects all filter effluent.  Its level is controlled by adjusting the outflow to the chlorine contact basins.  High‑level and low‑level alarms protect against overflowing or starving downstream units.

### Chlorine contact basins

Two basins operating in parallel to provide detention time for disinfection.  No regulatory CT calculation is implemented; the simulation simply reports the hydraulic residence time.

### Treated‑water reservoir

Final storage before water enters the distribution system.  It is subject to system demand and may influence plant inflow in later phases.

## Placeholder values

Capacities, elevations and flow limits are represented with placeholder values in the proof‑of‑concept configuration files.  Do not interpret these values as design recommendations.

## Matching the JSON

This document should match the structure defined in `config/plants/default_surface_water_plant/topology.json`.  Any differences should be rectified by updating both the JSON and this documentation.
