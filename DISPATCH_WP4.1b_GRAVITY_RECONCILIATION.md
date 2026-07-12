# WP4.1b — Gravity Basis Reconciliation + phase3 hygiene/tuning

**Author:** Orchestrator / Reviewer
**Implementer:** Windows + Godot 4.7, GUT locally, push to `main`, one commit.
**Base commit:** the accepted WP4.1 head (`20afd73` or later). **Do NOT start until WP4.1 is
accepted** (green CI run URL + GUT output confirmed).
**Commit prefix:** `WP4.1b:` — one WP, one commit, no out-of-scope files.

---

## 1. Why this WP exists

WP4.1 flipped `phase3_headworks` to GRAVITY using a **provisional, agent-synthesized** elevation
cascade (`docs/archive/WP4.1_PROVISIONAL_GRAVITY_BASIS.md`). This WP replaces the provisional
numbers with the **real design-basis elevations** and cleans up two findings logged during the
WP4.1 review. This is again a **controlled re-baseline of `phase3_headworks` ONLY** — phase1 and
phase2 stay byte-identical/green.

---

## 2. Prerequisite input (blocks the elevation part)

Real elevations from the design docs are **not yet in the repo**. Before doing §3.1, obtain from
the plant owner, per unit / boundary / link:
- StorageUnit `floor_elevation_m` (datum-referenced) for the 11 phase3 StorageUnits.
- ExternalBoundary `reference_head_m` for `EXTERNAL_SOURCE_01/02`, `FILTER_FEED_01`, `DRAIN_SINK`.
- Per-link `design_head_m` — the true design head across each of the 24 links.

If real values are still unavailable when this WP is picked up, do §3.2 and §3.3 only and leave the
provisional cascade in place (skip §3.1), noting so in the commit.

---

## 3. Scope

### 3.1 Replace provisional elevations with real design basis (needs §2 input)
- **Datum convention (locked):** `floor_elevation_m` and `reference_head_m` are **absolute
  sea-level elevations (MSL)**, entered straight from the engineering drawings — no conversion,
  no local benchmark. The gravity model only uses head *differences*, so absolute magnitudes
  (hundreds of metres) behave identically to the provisional 0–20 range.
- Update `config/plants/phase3_headworks/topology.json` `floor_elevation_m` / `reference_head_m` /
  `design_head_m` to the real values. **Keep `bottom_elevation_m` = 0.0 and all level/alarm fields
  (`high_level_m`, `spill_level_m`, `min_operating_level_m`) RELATIVE to each unit's own bottom.**
  Only `floor_elevation_m` / `reference_head_m` carry MSL; mixing MSL into the level/alarm fields
  breaks alarms and the water viz. This split isolates gravity head from level/volume/alarm/viz,
  exactly as in WP4.1.
- Re-align `initial_conditions.json` volumes to the new design operating levels if they shift.
- Keep the design rule `design_head_m = design Δh` unless the docs specify otherwise, so
  `Q ≈ max_flow × opening` at the design point.
- Re-baseline the phase3 integration tests to the new numbers (same files as WP4.1:
  `test_reservoir_manifold`, `test_distribution_box`, `test_basin_availability_integration`,
  `test_headworks_controller`, `test_applied_channel`). Every new expected value must be justified
  from head + opening, not curve-fit.
- Promote `docs/archive/WP4.1_PROVISIONAL_GRAVITY_BASIS.md` to a non-provisional design-basis note
  (or supersede it), citing the source design docs.

### 3.2 Hygiene fix (logged in WP4.1 review)
- `config/plants/phase3_headworks/initial_conditions.json` lost its trailing newline in WP4.1
  (`\ No newline at end of file`). Restore the final newline — the repo enforces whitespace
  hygiene (see the earlier `ci:` whitespace commit); this may otherwise trip a lint.

### 3.3 Controller offset (logged in WP4.1 review) — DECISION REQUIRED
- Under gravity the LevelControllers (proportional-only: `kp` set, `kd=0`, no integral term) run a
  persistent **~0.13–0.30 m steady-state offset below** the APPLIED_CHANNEL setpoint of 2.0 m
  (WP4.1 measured 1.8729 pre-disturbance, 1.7036 post). This is expected P-only droop against a
  gravity load, not a fault.
- **Owner decides one of:**
  (a) **Accept the droop** — leave setpoint 2.0, keep the re-baselined offset values as the
      documented plant behavior. No controller change.
  (b) **Bias the setpoint** — raise the `setpoint` in `controllers.json` so the achieved level
      lands near the intended 2.0 (pure config, still P-only).
  (c) **Add integral action** — introduce a `ki` term to `LevelController` to drive offset to zero.
      This is a **shared domain-class change** and MUST follow the DEFAULT-OFF, backward-compatible
      guardrail (new `ki` defaults to 0.0 ⇒ existing plants byte-identical) with **full-suite
      reverification proving phase1/phase2 goldens unchanged**. If chosen, this likely warrants its
      **own separate WP** (WP4.1c) rather than riding in 4.1b.
- Do NOT implement (c) inside this WP without an explicit go-ahead and its own reverification.

---

## 4. Guardrails / acceptance

- Only `phase3_headworks` config/tests + the two docs move. `phase1_single_basin` and
  `phase2_three_unit` byte-identical/green. No `scripts/` change (unless option 3.3c is explicitly
  approved as a separate WP).
- Determinism (replay run1==run2, sorted iteration) intact; mass-balance holds at the standard
  1e-9 tolerance — do not relax invariant tolerances.
- Buffer units (Manifold/Mix/Dist Box, 1 m²) still stabilize with no lockup/oscillation/persistent
  spill under the real elevations.
- `level_m` and the 3D water viz still track volume/area exactly (floor only offsets gravity head).
- `WP4.1b:` commit, only in-scope files, tree clean, `.uid` committed, no temp/log artifacts.
- **Hand back:** pasted GUT output (phase3 + invariants) **and** the specific green CI run URL
  (`.../actions/runs/<id>`, both jobs) on the pushed commit.

**Reviewer verdict:** accept when origin/main == the pushed commit, that CI run is green on both
jobs, config/tests audited from objects match this package, determinism + mass-balance intact,
phase3 goldens re-baselined **with justification**, and **phase1/phase2 byte-identical**.
