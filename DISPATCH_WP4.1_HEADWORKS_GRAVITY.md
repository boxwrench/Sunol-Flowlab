# WP4.1 — Headworks → GRAVITY Migration (controlled re-baseline of phase3_headworks ONLY)

**Author:** Orchestrator / Reviewer
**Implementer:** run on Windows + Godot 4.7, GUT locally, push to `main`, one commit.
**Base commit:** `33e7c65` (== origin/main, tree clean).
**Commit prefix:** `WP4.1:` — one WP, one commit, no out-of-scope files.

---

## 1. Goal

Convert `config/plants/phase3_headworks` from RESTRICTED to self-regulating GRAVITY hydraulics,
using the mechanics already shipped in WP4.0. This **deliberately re-certifies phase3_headworks**:
its flow/level trajectories WILL change and its integration-test expectations WILL move. That is
the point of the WP.

**Hard guardrail:** `phase1_single_basin` and `phase2_three_unit` are NOT touched. Their configs,
tests, and results must remain **byte-identical / green**. Only `phase3_headworks` re-baselines.

Scope decisions (locked for this WP):
- **Elevation basis:** agent **synthesizes** a plausible monotonic-downhill cascade, documented as
  **PROVISIONAL** (to be reconciled against the real design docs in a later pass). See §4.
- **Gravity scope:** **every link** in `phase3_headworks/topology.json` flips to `GRAVITY`,
  **including source-inflow and drains** (24 links total).

---

## 2. What WP4.0 already gives you (no code/schema change needed)

Confirmed from objects at `33e7c65`:

- `topology.schema.json` already accepts `floor_elevation_m` (StorageUnit), `reference_head_m`
  (ExternalBoundary), and `design_head_m` (link). **No schema edit.**
- `storage_unit.gd`: `water_surface_elevation_m() = floor_elevation_m + level_m`; and
  `floor_elevation_m = config.get("floor_elevation_m", bottom_elevation_m)`. Leaving
  `bottom_elevation_m` at its current value (0.0) means **`level_m`, volume, alarms, and the
  presentation water viz are unaffected** — `floor_elevation_m` only offsets the gravity head.
- `external_boundary.gd`: `reference_head_m = config.get("reference_head_m", 0.0)`.
- `flow_link.gd` GRAVITY branch: `dh = up_surface − down_surface`;
  `Q = max_flow*opening*sqrt(dh/design_head_m)`, sign-preserving clamp to `max_flow`; reverse
  gated by `reverse_flow_allowed` (default false); **`design_head_m` MUST be > 0 or the link is
  dead (Q=0)**; a link with no actuator runs at `opening = 1.0`.

**Therefore WP4.1 is a config edit + a test re-baseline. No `.gd` production code changes.**

---

## 3. Files to change (exhaustive)

1. `config/plants/phase3_headworks/topology.json`
   - Add `floor_elevation_m` to all **12 StorageUnits**: `RESERVOIR_01`, `RESERVOIR_02`,
     `MANIFOLD_01`, `FLASH_MIX_01`, `DIST_BOX_01`, `BASIN_01`…`BASIN_05`, `APPLIED_CHANNEL_01`.
     Leave `bottom_elevation_m` = 0.0 unchanged.
   - Add `reference_head_m` to the boundaries that terminate a gravity link: `EXTERNAL_SOURCE_01`,
     `EXTERNAL_SOURCE_02`, `FILTER_FEED_01`, `DRAIN_SINK`. (`SPILL_SINK` needs none — spill is
     passive internal routing, not a link.)
   - Set `"flow_mode": "GRAVITY"` and a positive `"design_head_m"` on **all 24 links**.

2. `config/plants/phase3_headworks/initial_conditions.json` — *optional but recommended*:
   nudge initial volumes to sit near the design operating levels in §4 so startup transients don't
   pin links at the clamp or trigger spurious spills. Any change here is part of the documented
   re-baseline. Keep it minimal; do not add/remove units.

3. Integration/invariant tests that hardcode RESTRICTED-mode magnitudes — re-baseline (see §5).

4. Documentation of the provisional basis — see §6.

**Do not** touch `plant.json`, `alarms.json`, `controllers.json`, `presentation_map.json`, any
`scripts/` file, or any phase1/phase2 file.

---

## 4. Provisional elevation cascade (recommended starting point)

Design rule, applied uniformly:
> Pick a design operating **level** `L*` for each unit (inside its `min_operating_level_m` …
> `spill_level_m` band), step the **water-surface elevations** monotonically downhill along the
> topological order, set `floor_elevation_m = surface − L*`, and set each link's
> **`design_head_m` = the design-point Δh across that link**.

Setting `design_head_m = Δh` makes `sqrt(dh/design_head_m) = 1` at the design point, so
`Q ≈ max_flow × opening` there (RESTRICTED-like at design, self-regulating off-design). This keeps
the LevelControllers well-conditioned and makes the new goldens interpretable.

Recommended provisional numbers (agent may refine; must keep it monotonic and each `Δh > 0`):

| Unit | L* (m) | surface elev (m) | `floor_elevation_m` |
|---|---|---|---|
| EXTERNAL_SOURCE_01/02 | — | 20.0 | `reference_head_m = 20.0` |
| RESERVOIR_01 / _02 | 5.0 | 18.0 | 13.0 |
| MANIFOLD_01 | 2.0 | 16.0 | 14.0 |
| FLASH_MIX_01 | 2.0 | 14.0 | 12.0 |
| DIST_BOX_01 | 2.0 | 12.0 | 10.0 |
| BASIN_01…05 | 3.0 | 9.0 | 6.0 |
| APPLIED_CHANNEL_01 | 2.0 | 6.0 | 4.0 |
| FILTER_FEED_01 | — | 4.5 | `reference_head_m = 4.5` |
| DRAIN_SINK | — | 0.0 | `reference_head_m = 0.0` |

Per-link `design_head_m` (= design Δh):

| Link(s) | Δh / `design_head_m` |
|---|---|
| `LINK_IN_01`, `LINK_IN_02` (src→res) | 2.0 |
| `LINK_OUT_RES_01`, `LINK_OUT_RES_02` (res→manifold) | 2.0 |
| `LINK_OUT_MAN_01` (manifold→flashmix) | 2.0 |
| `LINK_OUT_FM_01` (flashmix→distbox) | 2.0 |
| `LINK_OUT_DB_01…05` (distbox→basin) | 3.0 |
| `LINK_OUT_BASIN_01…05` (basin→applied channel) | 3.0 |
| `LINK_OUT_AC_01` (applied channel→filter feed, **no actuator, opening=1.0**) | 1.5 |
| `LINK_DRAIN_RES_01/02` (res→drain sink) | 18.0 |
| `LINK_DRAIN_BASIN_01…05` (basin→drain sink) | 9.0 |

All chosen `L*` sit below each unit's `spill_level_m`, so no spill at the design point
(reservoir spill 9.5, basins 5.0, manifold/FM/DB 10.0, applied channel 5.0).

---

## 5. Test re-baseline (the real work)

**There is no committed golden-hash file.** The determinism tests
(`test_deterministic_replay.gd`, the replay block in `test_phase3_verification.gd`) assert
**run1 == run2 self-consistency**, which is config-independent — they should **stay green as-is**.
Do not weaken them.

What WILL break are the phase3 integration tests that hardcode RESTRICTED magnitudes. Update these
to the new gravity behavior, justifying every new expected value (see §7):

- `tests/integration/phase3_headworks/test_reservoir_manifold.gd` — e.g. "manifold inflow == 8.0",
  starve/steal assertions. Recompute under head-driven flow.
- `tests/integration/phase3_headworks/test_distribution_box.gd` — equal-split / proration
  expectations no longer hold as pure capacity splits; re-derive from head + valve opening.
- `tests/integration/phase3_headworks/test_basin_availability_integration.gd` — "Basin flow 2.0",
  "total 10.0", "4-basin 2.5". Re-baseline; keep the **out-of-service basin flow == 0.0** assertion.
- `tests/integration/phase3_headworks/test_headworks_controller.gd` — controller settling and the
  "flow to Basin 1 == 0 when commanded shut" assertion; settling values move under gravity.
- `tests/integration/phase3_headworks/test_applied_channel.gd` — the "AC inflow == Σ basin
  outflows" assertion is a **conservation** check and should still hold; keep it, verify it passes.
- `tests/integration/phase3_headworks/test_phase3_verification.gd` — fill-ratio / link-ratio
  computations are derived from actuals and should self-adjust; audit for any hardcoded magnitude.
- `tests/invariants/test_phase3_invariants.gd` — **mass balance must still hold** (guardrail);
  verify, do not relax the tolerance.

Also `git grep` phase3 tests/configs for any assertion assuming `flow_mode == "RESTRICTED"` and
fix. Do **not** edit phase1/phase2 tests.

---

## 6. Document the provisional basis

Because the elevations are synthesized, not from the real design docs, record that clearly so the
later reconciliation pass knows what to replace. Add a short `docs/` note (e.g.
`docs/archive/WP4.1_PROVISIONAL_GRAVITY_BASIS.md`) stating: the cascade is provisional, the design
rule (`design_head_m = design Δh`), the table in §4, and that phase3_headworks goldens were
re-baselined here while phase1/phase2 were not. Summarize the same in the commit body and
`CHANGELOG.md`.

---

## 7. Acceptance / verification checklist (implementer runs; reviewer re-checks from objects)

1. **Determinism:** `phase3_headworks` still replays bit-identically (run1==run2); iteration stays
   sorted (F-11). Green.
2. **Mass balance:** `test_phase3_invariants.gd` mass-balance holds within the standard tolerance —
   unchanged tolerance.
3. **Equalization / no lockup:** confirm the plant reaches a sensible steady operating state — every
   forward link keeps `Δh > 0` (no unintended `GRAVITY reverse blocked` stalling the chain), no
   persistent spill or empty-oscillation on the small buffer tanks (MANIFOLD/FLASH_MIX/DIST_BOX,
   area 1 m²). If a buffer oscillates or a link pins at the clamp, retune `L*`/`design_head_m` and
   re-document — do NOT change code.
4. **Water viz unchanged path:** `level_m` (and the presentation fill viz) still tracks
   volume/area exactly as before; `floor_elevation_m` only shifted the gravity head. Sanity-check
   the 3D view still animates water from `level_m`.
5. **phase1/phase2 untouched:** those configs/tests/results byte-identical and green.
6. **Every new expected test value is justified** in the test or the doc (why that flow/level, from
   head + opening), not just curve-fit to whatever the sim printed.
7. **Hygiene:** `WP4.1:` commit, only the files in §3, tree clean after commit, no temp/log
   artifacts, `.uid` files committed.

**Hand back for review:** pasted GUT output (full phase3 + invariants suite) **and** the specific
green CI run URL `.../actions/runs/<id>` (both jobs) on the pushed commit.

**Reviewer verdict rule for WP4.1:** accept when origin/main == the pushed commit, that CI run is
green on both jobs, code/config audited from objects matches this package, determinism +
mass-balance intact, phase3 goldens re-baselined **with justification**, and **phase1/phase2
byte-identical**. phase3_headworks trajectory movement is expected and allowed; phase1/phase2
movement is a hard fail.
