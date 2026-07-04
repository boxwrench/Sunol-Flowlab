# Plant Topology

This document describes the process network modelled in the drinking water plant sandbox.  It is a human‑readable complement to the JSON topology configuration file.

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
