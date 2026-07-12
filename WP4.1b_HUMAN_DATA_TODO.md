# WP4.1b — Human Data-Gathering Checklist (real gravity basis)

Everything the GRAVITY model + 3D layout needs, and which config field each item feeds.
Goal: replace the provisional cascade with real, document-sourced numbers.

---

## 0. The one thing everything hangs off
- [ ] **Vertical datum = absolute sea level** (per our engineering docs). Note *which* datum the
      drawings cite (e.g. NAVD88 / NGVD29 / MSL) and record it once.
      All `floor_elevation_m` and `reference_head_m` are entered as **absolute sea-level
      elevations, straight off the drawings — no conversion**.
      IMPORTANT: only `floor_elevation_m` and `reference_head_m` are absolute (MSL). The level/alarm
      fields (`bottom_elevation_m`, `high_level_m`, `spill_level_m`, `min_operating_level_m`) stay
      **relative to each unit's own bottom**, with `bottom_elevation_m = 0.0`. Do NOT put MSL values
      in the level/alarm fields — that would break alarms and the water viz.

## 1. Elevations per structure  → `floor_elevation_m` (11 StorageUnits)
Source: as-built / record drawings, structural sections.
- [ ] RESERVOIR_01, RESERVOIR_02 — floor (invert) elevation
- [ ] MANIFOLD_01 — floor/invert elevation
- [ ] FLASH_MIX_01 — floor elevation
- [ ] DIST_BOX_01 — floor elevation
- [ ] BASIN_01 … BASIN_05 — floor elevation (each, if they differ)
- [ ] APPLIED_CHANNEL_01 — channel invert elevation

## 2. Normal operating water levels  → defines design Δh (and sanity-checks `high/spill/min` levels)
Source: operating manual / SCADA normal setpoints.
- [ ] Normal operating water-surface elevation for each unit above (or operating depth + floor)
- [ ] Confirm existing `high_level_m`, `spill_level_m`, `min_operating_level_m` match real weir/alarm settings

## 3. Boundary heads  → `reference_head_m` (4 boundaries)
- [ ] EXTERNAL_SOURCE_01 / _02 — raw-water supply head (intake WSEL if gravity-fed, or pump discharge head if pumped — note which)
- [ ] FILTER_FEED_01 — downstream water-surface elevation the applied channel discharges to
- [ ] DRAIN_SINK — drain/outfall discharge elevation

## 4. Conveyance data  → `design_head_m` + validates `max_flow_m3s` (24 links)
Source: hydraulic profile / pipe schedule / headloss calcs. If no calc exists, we approximate
`design_head_m` = design Δh between the two structures (current rule).
- [ ] Per pipe/channel: design head loss at design flow **OR** enough to compute it
      (diameter, length, material/roughness, design flow)
- [ ] Design/rated flow per link to confirm the `max_flow_m3s` capacities
- [ ] Note any pumped links (gravity model assumes head-driven; pumped legs may need to stay RESTRICTED)

## 5. Aerial / plan layout  → 3D presentation (`presentation_map.json`, not the hydraulics)
Source: site aerial, civil site plan, GIS.
- [ ] Plan (X/Z) position of each unit — a dimensioned site plan or georeferenced aerial
- [ ] Plant orientation (north arrow) and a known scale/reference distance
- [ ] Plan footprint dimensions per structure — validates `surface_area_m2` and drives mesh sizing
- [ ] (Optional) a clean top-down image to use as the blueprint underlay

## 6. Source documents to locate (so the above is traceable)
- [ ] Record/as-built drawings (plans + sections with elevations)
- [ ] Hydraulic profile drawing (the classic stepped head diagram) — if it exists, it answers §1–§4 at once
- [ ] Site/civil plan or georeferenced aerial (answers §5)
- [ ] Operating manual / normal SCADA setpoints (answers §2)

---

### Minimum to unblock WP4.1b §3.1
§0 (datum) + §1 (floors) + §2 (operating levels) + §3 (boundary heads) is enough to replace the
elevations. §4 refines `design_head_m`; §5 is a separate improvement to the 3D view. A single
**hydraulic profile drawing** would cover §1–§4 in one shot — grab that first if it exists.
