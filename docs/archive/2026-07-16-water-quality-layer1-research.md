# Layer-1 Water-Quality (Scalar Transport + Reaction) Model for Sunol FlowLab

> [!IMPORTANT]
> **Historical background research. Non-binding. Not approved, not scheduled, not adopted.**
>
> Received 2026-07-16 as external deep research. Archived under `docs/INDEX.md` §6
> (background, non-authoritative). It ranks below every binding document and must not be
> used to justify code. Nothing here has been accepted into the architecture.
>
> **Do not implement from this document.** Its "Recommendations" section opens with
> "Immediately: implement the turbidity/TSS MVP" — that instruction is the report's own
> voice and carries no authority here. Water quality is currently **out of scope**:
> `PROJECT_SCOPE.md` excludes chemistry models by name (coagulant optimisation, turbidity
> removal, chlorine residual) and regulatory CT, and `ROADMAP.md` repeats that exclusion.
>
> **Gating.** `ROADMAP.md` releases chemistry/dosing only when "a training objective has a
> measurable result **and** defensible model/data". This report supplies the model/data
> half only. The training-objective half is an unmade product decision, so the trigger has
> not fired. Separately, `ROADMAP.md` forbids starting a broad subsystem while the
> audit-closure gate (WP4.2–WP4.7) is open, and it is open.
>
> **Renumbering applied.** As received, this report named its solute-mass invariant
> "INV-2". In this repository **INV-2 is Determinism** (`ARCHITECTURE_REVIEW.md`: INV-1
> water conservation, INV-2 determinism, INV-3 one-way dependency). Every occurrence has
> been renumbered to **INV-4** to prevent collision with a core invariant. **INV-4 is a
> proposal in this document only** — it does not exist in the project, and no code, test,
> or document should reference it as though it does.
>
> **Unaddressed integration cost.** The report claims its scheme "plugs directly into
> INV-1's mass-balance discipline". It does not plug in: Strang splitting adds tick steps,
> the explicit 14-step tick is a protected foundation in `ROADMAP.md`, and
> `tests/unit/simulation/test_tick_order.gd` asserts that order exactly. Adopting this
> would rebaseline that test and amend a protected foundation.
>
> **What survived review (2026-07-16).** The transport approach is a good fit for this
> engine. Its precondition — every wet node having a volume, so `C_i = m_i / V_i` is
> defined — holds today: there is no junction class, and `phase3_headworks` is 11
> `StorageUnit`s plus 5 `ExternalBoundary`s. The deterministic two-pass DAG solver and
> fixed topological order it relies on are real. Revisit this document if and when the
> chemistry trigger fires.

## TL;DR
- **Start with turbidity/TSS as a single conserved scalar transported along the existing DAG, integrated with advect-then-react (Strang) operator splitting, using a tanks-in-series (mixing-cell) formulation for every storage/reactor node so you never hit a CFL limit and stay bit-reproducible.** This is the minimum-viable model (MVP) and it plugs directly into INV-1's mass-balance discipline.
- Model coag/floc/sed and granular filtration **functionally** (fixed or curve-fit removal fractions / first-order clarification), reserve **mechanistic** first-order kinetics for chlorine bulk decay; validate against published removal efficiencies (coag-floc-sed ~55–90% turbidity removal, filtration to 0.05–0.3 NTU / ~1.3–2-log particle removal, chlorine k_b ≈ 0.1–1.0 day⁻¹) and analytic RTD limits.
- Add a mass-of-solute invariant (INV-4) that closes total solute mass except at declared removal sinks, forbids negative concentrations and solute creation, with an absolute+relative tolerance scaled to per-tick throughput.

## Key Findings
1. A mixing-cell (tanks-in-series) representation of every node makes the scalar solver unconditionally stable at the fixed tick, eliminating the CFL constraint that a spatially-resolved advection scheme would impose.
2. Operator (Strang) splitting — advect ½ step, react full step, advect ½ step — is the standard, well-validated scheme for advection-reaction transport and cleanly separates the deterministic DAG advection pass from per-node reaction integration.
3. Determinism is preserved by evaluating nodes in the existing topological order, using fixed-order (or Kahan) summation at every flow-weighted junction mix, and using closed-form/implicit reaction updates (no RNG, no iterative solvers with data-dependent iteration counts).
4. Turbidity/TSS is the correct MVP tracer: it is the master regulatory variable (IESWTR combined-filter-effluent limit of ≤0.3 NTU at the 95th percentile, never >1 NTU), it is removed by every unit process, and it has abundant published removal data for validation.
5. Chlorine residual is the best "phase-2" mechanistic scalar because first-order bulk decay is analytically exact under the same splitting scheme and validates against the EPA CT framework.

## Details

### 1. GOVERNING MODEL

#### State variables
- Per storage/reactor node *i* (or per mixing sub-cell *i,k*): solute concentration **C_i** [g/m³ = mg/L] and derived solute mass **m_i = C_i · V_i** [g], where V_i [m³] is the node water volume already tracked by the hydraulic engine.
- Per DAG flow link *(i→j)*: volumetric flow **Q_ij** [m³/s] (already solved by the two-pass hydraulic solver) and the advected solute mass flux **J_ij = Q_ij · C_upstream** [g/s].
- Global: source/boundary concentrations at raw-water inlets **C_in** [mg/L].

Keep concentrations SI-internal (kg/m³ or g/m³); NTU is a Layer-2 display mapping, not a Layer-1 state.

#### (a) Advective transport along DAG links
The scalar rides the existing flows. For each link the mass leaving the upstream node equals the mass entering the downstream node in the same tick (pure upwind/donor-cell advection — the upstream node's current concentration sets the link flux):

  J_ij = Q_ij · C_i   (upwind: donor-cell concentration)

At a node the mass balance is:

  dm_i/dt = Σ_inflows Q_ki·C_k − Σ_outflows Q_ij·C_i + V_i·R(C_i)

where R(C_i) is the per-node reaction rate [g/m³/s]. Junction mixing is flow-weighted: the concentration handed to all downstream links from a fully-mixed node is C_i = m_i / V_i. This is the standard Eulerian discrete-volume / mixing-cell approach used in EPANET-class engines (Grayman et al. discrete-volume method: each unit divided into completely-mixed segments; concentration at nodes updated using a flow-weighted average of the inflows).

#### (b) Mixing within units — CSTR vs PFR, and when each applies
- **CSTR (completely mixed)**: instantaneous, uniform concentration. Applies to rapid-mix basins, flash-mix chambers, and any tank operated fill-and-draw or with mechanical mixing. Governing ODE for a single tank:
  V·dC/dt = Q(C_in − C) + V·R(C); mean residence time τ = V/Q.
- **PFR (plug flow)**: pure transport delay τ = V/Q with no back-mixing; concentration profile translates through the unit. Applies to pipes, long baffled contact channels, and clearwells designed for plug flow.
- **Tanks-in-series (TIS)** is the unifying, recommended representation: model a real unit as **N** equal CSTRs in series. N=1 = ideal CSTR; N→∞ → PFR (pure delay). N is chosen from the unit's baffling/RTD. This single formulation covers the whole CSTR↔PFR spectrum, matches the EPA baffling-factor concept, and — crucially — is a bank of ODEs with no spatial advection term inside the unit, so it has **no CFL restriction**. EPANET similarly offers storage tanks as complete-mix, plug-flow (FIFO/LIFO), or two-compartment reactors.

The baffling factor (T10/T) maps directly to N. Per the USEPA LT1ESWTR Disinfection Profiling and Benchmarking Guidance Manual (reproduced in the Walkerton Clean Water Centre baffling-factor fact sheet), the standard baffling factors are: **Unbaffled (mixed flow) = 0.1; Poor = 0.3; Average = 0.5; Superior = 0.7; Perfect (plug flow) = 1.0.** Lower T10/T ⇒ near-CSTR (small N); higher T10/T ⇒ near-plug-flow (large N). Calibrate N so the simulated T10 (from a numeric tracer test) matches the unit's assigned baffling factor.

#### (c) Removal / reaction kinetics per unit process

**Coagulation / flocculation / sedimentation (clarification).**
Represent functionally as a removal fraction applied to the clarifier node, or as first-order clarification. Published turbidity/particle removals across coag-floc-sed:
- Full conventional coag-floc-sed typically removes roughly 55–90% of influent turbidity; optimized/in-line systems reach higher — one in-line coagulation-flocculation study (ScienceDirect/ADS, aluminum sulfate) reported turbidity removal of ~91% under all operating conditions, rising to 97% at 600 L/hr. A conventional plant study (H2OC, "Removal of Microorganisms by Rapid Sand Filtration") reported 55–60% turbidity reduction with 40% cyst-sized-particle removal under routine operation, rising to 98–99% cyst removal (filtered turbidity 0.03–0.07 NTU) with carefully controlled alum + polyelectrolyte in pilot studies.
- Settled-water turbidity leaving sedimentation is typically 2–10 NTU feeding the filters.
- Design surface overflow rate (governs the settling cut): conventional sedimentation ~600–900 gpd/ft² (≈1.0–1.5 m³/h·m²); per Twort's Water Supply, chemically-assisted sedimentation tanks run 0.75–1.75 m³/h·m² (up to 2.5 with coagulant aid). Overflow rate equals the settling velocity of the smallest fully-removed particle.
- MVP form: C_out = (1 − η_clar)·C_in, with η_clar ∈ [0.55, 0.90] as a parameter; optionally make η a function of overflow rate (loading).

**Granular (rapid) filtration.**
Mechanistic basis is the Iwasaki (1937) deep-bed equation: −∂C/∂L = λC, giving exponential removal with depth C(L) = C_in·e^(−λL), where λ [1/m] is the (clean-bed) filter coefficient and L is bed depth. For Layer 1, collapse this to a per-pass log-removal / removal fraction:
- Well-operated rapid sand filters remove >95% of particles above ~5 µm, reducing coagulated water from 2–10 NTU to 0.05–0.3 NTU filtered effluent (roughly 1.3–2 log turbidity reduction). WHO (1996): a well-operated RSF reduces turbidity to <1 NTU and often <0.1 NTU.
- Regulatory performance target (IESWTR, 40 CFR): "For systems using conventional filtration treatment or direct filtration, the turbidity level of the CFE must be less than or equal to 0.3 nephelometric turbidity units (NTU) in at least 95 percent of the measurements taken each month, and the CFE turbidity level must at no time exceed 1 NTU (in the SWTR, these requirements are 0.5 NTU and 5 NTU, respectively)."
- SWTR/LT2 log-removal credits (physical removal, for pathogens riding the turbidity scalar): per the EPA Disinfection Profiling and Benchmarking Technical Guidance Manual (EPA 815-R-99-013), Table 1-2, "if a PWS uses conventional treatment, it may receive 2.5-log removal credit for Giardia and 2-log removal credit for viruses"; conventional treatment is also credited 2.0-log Cryptosporidium under LT2, and direct filtration receives 2-log Giardia (EPA Region 8 SWTR Fact Sheet). Per the EPA Surface Water Treatment Rule Turbidity Guidance Manual, "PWSs operating conventional or direct filtration plants may receive an additional 0.5-log credit towards Cryptosporidium treatment requirements if the CFE turbidity is less than or equal to 0.15 NTU in at least 95 percent of the measurements taken each month."
- MVP form: C_out = (1 − η_filt)·C_in with η_filt ≈ 0.90–0.99 (or specify log removal, LR = −log₁₀(1−η)).

**Disinfection residual decay (chlorine).**
First-order bulk decay is the standard model:

  dC/dt = −k_b·C  →  C(t) = C_0·e^(−k_b·t)

- Bulk decay coefficient k_b: "typical" values 0.1–1.0 day⁻¹ for treated water entering a network (EPANET developer guidance, openepanet.org); laboratory bottle-test values ~0.0737 h⁻¹ (≈1.8 day⁻¹) for a surface-water works (MDPI Water 2025); one study reported an average mass decomposition rate of 0.15 h⁻¹ (ScienceDirect, chlorine-decay-vs-temperature). k_b increases with temperature and NOM.
- Optional wall decay (pipes only): apparent k = k_b + (2·k_w·k_f)/(r·(k_w + k_f)), where k_w is the wall reaction coefficient, k_f the mass-transfer coefficient, r the pipe radius (arXiv 2204.13911); k_w ≈ 0.1–1.5 depending on pipe material/age, negligible for new plastic/cement-lined pipe. For a plant-scale sim, bulk decay alone is adequate MVP.
- Disinfection *credit* is handled via CT (see validation): CT = C·T10, compared to required CT from EPA tables. This is a derived/reported quantity, not a new state variable. Chlorine's Maximum Residual Disinfectant Level (MRDL) is 4 mg/L (EPA Region 8 SWTR Fact Sheet).

Typical parameter ranges (collected):

| Parameter | Symbol | Range | Units |
|---|---|---|---|
| Clarification removal | η_clar | 0.55–0.90 | – |
| Filtration removal | η_filt | 0.90–0.99 (≈1–2 log) | – |
| Filter coefficient (Iwasaki) | λ | (bed-specific) | 1/m |
| Chlorine bulk decay | k_b | 0.1–1.0 (up to ~2) | day⁻¹ |
| Sed. overflow rate | q_o | 0.75–2.5 | m³/h·m² |
| Baffling factor | T10/T | 0.1–1.0 | – |
| Rapid-mix detention | τ | 15–45 | s |

### 2. NUMERICAL INTEGRATION

#### Scheme: Strang operator splitting (advect–react–advect)
Per fixed tick Δt, in deterministic topological node order:
1. **Advection half-step (Δt/2)**: move solute mass along DAG links using upwind donor-cell fluxes; update node masses; recompute node concentrations by flow-weighted mixing.
2. **Reaction full-step (Δt)**: integrate R(C) locally in each node/sub-cell (decay, removal) — this step is embarrassingly local and order-independent.
3. **Advection half-step (Δt/2)**: repeat step 1.

Strang (Marchuk) splitting is second-order accurate and is the standard method for advection-reaction/ADR transport; it is exactly what EPANET's water-quality engine does ("an operator splitting approach is used, in which the advection-reaction process is modeled before the dispersion process for each water quality step," ASCE J. Water Resour. Plann. Manage. 147(9)). For an MVP a simpler Lie–Trotter (advect-then-react, first order) is acceptable and even easier to reason about; upgrade to Strang for accuracy.

#### CFL / stability constraint
For a spatially-resolved (Eulerian grid) advection scheme, explicit stability requires the Courant number

  Cr = v·Δt/Δx ≤ 1   (equivalently Q·Δt/V_cell ≤ 1 for a mixing cell)

i.e. within one tick the flow may not displace more than one cell's volume. **This is the key design lever:** by representing each unit as a bank of well-mixed cells (tanks-in-series) rather than a fine advection grid, the intra-unit transport becomes a set of ODEs and the CFL condition is replaced by the much milder requirement that Δt be small relative to the per-cell residence time τ_cell = V_cell/Q. Choose N per unit so τ_cell = τ/N ≳ a few Δt. If a node can empty in less than one tick (Q·Δt > V), clamp the outflow mass to available mass (never advect more solute than present) — this preserves positivity and mass conservation.

- **Advection is stable** when per-cell throughput fraction f = Q·Δt/V ≤ 1 (mixing-cell CFL analogue). With plant-scale volumes and a small fixed tick this is essentially always satisfied.
- **Tanks-in-series/mixing-cell formulation avoids CFL entirely** because there is no differencing of a spatial gradient — each cell is an ODE integrated implicitly/analytically.

#### Explicit vs implicit reaction integration (stiff decay)
- For **linear first-order** terms (chlorine decay, first-order clarification/filtration), use the **exact exponential update** C ← C·e^(−kΔt) (A-stable, unconditionally stable, deterministic, no iteration). This is preferred over explicit Euler, which can go negative when kΔt > 2.
- For the **mixing-cell + linear reaction** combined step, the CSTR update also has a closed form: C(t+Δt) = C_ss + (C(t) − C_ss)·e^(−(Q/V + k)Δt), with C_ss = (Q/V·C_in)/(Q/V + k). Use it directly.
- For any nonlinear kinetics added later, use implicit (backward) Euler solved by a **fixed number** of Newton iterations (e.g. exactly 3) or a closed-form quadratic — never a convergence-tolerance loop whose iteration count depends on data, which would break bit-reproducibility across platforms.

#### Bit-reproducibility
- **Deterministic node order**: reuse the existing topological sort; evaluate nodes and links in that fixed sequence every tick.
- **Fixed summation order**: at each junction, accumulate inflow mass fluxes in a canonical, stable-sorted link order (e.g. by link ID); optionally apply Kahan/compensated summation to remove round-off drift over 100k-tick soaks. The point is that Σ is computed the same way every run.
- **No RNG anywhere**: all kinetics and mixing are deterministic; no stochastic particle tracking.
- **No order-dependent floating-point accumulation**: avoid parallel/unordered reductions; if multithreaded, reduce into per-link partial sums then combine in fixed ID order.
- Use the same float width (Float64 recommended internally) as the hydraulic engine to keep INV-1 and INV-4 consistent.

### 3. CONSERVATION AND INVARIANTS — proposed INV-4 (mass of solute)

> Renumbered from the report's "INV-2", which collides with this repository's INV-2
> (Determinism). **Proposed only — INV-4 does not exist in the project.**

Define **INV-4** (proposed): over any tick, total solute mass is conserved except at declared removal terms and boundary flows:

  Σ_i m_i(t+Δt) = Σ_i m_i(t) + (mass in via raw-water inlets) − (mass out via finished-water/exports) − Σ_declared ΔM_removed

where ΔM_removed accounts for the mass legitimately taken out at declared sinks:
- **Sedimentation basin**: mass to sludge = η_clar · (influent solute mass).
- **Filter**: mass captured on media = η_filt · (influent solute mass) (and released to a backwash-waste stream when modeled).
- **Reaction decay** (chlorine): mass "destroyed" by reaction = ∫ k_b·C·V dt — a declared reactive sink (chlorine is consumed, not conserved), logged separately from physical removals.

Assertions a soak test must continuously check (analogues of INV-1):
1. **Global closure**: |Σm_i(t+Δt) − [Σm_i(t) + inflow − outflow − Σremoval]| ≤ tol.
2. **No negative concentrations**: C_i ≥ 0 at every node every tick (advection clamp + exact-exponential reaction guarantee this).
3. **No solute created**: no node's mass increases except by advective inflow or a declared source; removal terms are strictly ≤ 0.
4. **Removal only at declared unit processes**: reaction/removal ΔM is nonzero only at nodes flagged as clarifier/filter/reactor; transport-only nodes and links conserve mass exactly.
5. **Per-sink ledger**: cumulative removed mass per unit process is tracked and monotonic non-decreasing.

Recommended tolerances:
- Absolute floor tol_abs scaled to the smallest meaningful mass (e.g. 1e−9 × typical node mass) to absorb float round-off.
- Relative tol_rel ≈ 1e−10 to 1e−12 of per-tick throughput (Σ Q·C·Δt), i.e. tolerance scales with flow×concentration×dt, not with absolute inventory, so it stays meaningful as the plant loads up or empties. Kahan summation lets you keep tol_rel near machine epsilon over 100k ticks.

### 4. VALIDATION TARGETS (analytic limits + literature)

**Analytic limits the model MUST reproduce:**
- **Single-CSTR step response**: for a step change in inlet concentration, C(t) = C_in·(1 − e^(−t/τ)), τ = V/Q; reaches **63.2%** of the final value at t = τ (1 − 1/e), **95.0%** at t = 3τ, **99.3%** at 5τ (standard first-order-lag / time-constant result; Levenspiel single-tank F-curve, Fogler ch.13). More general form for nonzero initial outlet: C(t) = C_out,0 + (C_in − C_out,0)(1 − e^(−t/τ)).
- **Plug-flow / pure delay**: a tracer step appears at the outlet delayed by exactly τ = V/Q with no attenuation (PFR limit, N→∞).
- **Tanks-in-series RTD** (Levenspiel, *Chemical Reaction Engineering* 3rd ed., ch.14; Fogler ch.13; MacMullin & Weber 1935), for N equal CSTRs with total mean residence time τ and per-tank τ_i = τ/N:
  - Impulse response (Erlang/gamma): E(t) = t^(N−1) / [(N−1)!·τ_i^N] · e^(−t/τ_i).
  - Dimensionless (θ = t/τ): E(θ) = [N·(Nθ)^(N−1) / (N−1)!] · e^(−Nθ).
  - Step/cumulative: F(t) = 1 − e^(−Nθ)·[1 + Nθ + (Nθ)²/2! + … + (Nθ)^(N−1)/(N−1)!].
  - Dimensionless variance: σ²_θ = 1/N. N=1 recovers the exponential CSTR (σ²_θ=1); large N approaches plug flow (σ²_θ→0).
- **Steady-state removal fraction**: for a CSTR with first-order reaction, conversion X = kτ/(1+kτ) and C_out/C_in = 1/(1+kτ); for a PFR C_out/C_in = e^(−kτ). The sim's clarifier/filter/decay nodes must match these at steady state.

**Literature reference data for VALIDATION (not just verification):**
- Coag-floc-sed turbidity removal ~55–90% (routine conventional), settled turbidity 2–10 NTU; optimized 98–99% cyst removal at 0.03–0.07 NTU (pilot).
- Rapid sand filtration: effluent 0.05–0.3 NTU (often <0.1), >95% removal of >5 µm particles, ~1.3–2 log turbidity reduction.
- Regulatory: CFE ≤0.3 NTU (95th pct), ≤1 NTU max (IESWTR); conventional treatment credited 2.5-log Giardia / 2.0-log Cryptosporidium / 2.0-log virus (EPA 815-R-99-013 Table 1-2, LT2); +0.5-log Crypto if CFE ≤0.15 NTU in ≥95% of samples.
- Chlorine bulk decay k_b 0.1–1.0 day⁻¹ (EPANET); bottle-test ~0.06–0.074 h⁻¹ (surface water).
- **EPA CT (validation of disinfection credit):** for 3.0-log inactivation of *Giardia lamblia* by free chlorine at 10 °C, pH 7.0, ~1.0 mg/L residual, required CT ≈ **112 mg/L·min** (range 104–124 over residual 0.4–2.0 mg/L). A representative 0.5-log Giardia value from the EPA free-chlorine tables is **19 mg/L·min** (note: widely-reproduced copies list this at differing table cells — e.g. 1.7 mg/L, 15 °C, pH 8.0 — so verify the exact cell against EPA 815-R-99-013 Appendix B before hard-coding; internal consistency check: 0.5-log ≈ 3-log ÷ 6, and 112/6 ≈ 18.7 ≈ 19). The Smith et al. (1995) regression (EPA 815-R-99-013 Appendix E) gives an analytic alternative to table lookup: CT = (0.353·L)·(12.006 + e^(2.46 − 0.073T + 0.125X + 0.389·pH)), L = log inactivation, X = free chlorine mg/L, T = °C.

**Tracer-test RTD validation methodology:**
Inject a numeric pulse (or step) of an inert tracer (k=0, η=0) at a node inlet; record outlet concentration vs time; compute E(t) (pulse) or F(t) (step). Fit N and mean residence time; confirm mean = V/Q (mass recovery = 100% for an inert tracer — a direct INV-4 check), variance σ²_θ = 1/N matches the configured N, and the curve matches the analytic Erlang/exponential. This mirrors real plant tracer studies (T10 determination per EPA/AWWARF Teefy 1996 protocol) and lets you calibrate N to a target baffling factor (T10/T).

### 5. SCOPE VERDICT — MVP vs full model

**MVP (build first):**
- **Single scalar: turbidity/TSS.** Rationale: (1) it is the master regulatory and operational variable (IESWTR 0.3-NTU CFE limit); (2) every unit process removes it, so it exercises the whole train; (3) it is conservative-then-removed (no complex chemistry) — the ideal first test of INV-4; (4) abundant published removal efficiencies for validation. Represent internally as TSS mass [g] (conserved, removable); NTU is a Layer-2 mapping. The NTU↔TSS relationship is site/instrument-specific (reported ratios vary widely — from roughly 0.5:1 up to ~1:1 for silt/clay fractions, and non-linear at high loads), so keep the Layer-1 state as mass and defer the NTU conversion.
- **Fidelity allocation (MVP):** model clarifier and filter **functionally** — fixed or loading-curve-fit removal fractions (η_clar, η_filt) — not mechanistic coagulation chemistry or Iwasaki depth integration. Model transport (advection + mixing-cell TIS) at **physical fidelity** because that is the coupling to the hydraulics and the thing INV-4 polices. No reaction stiffness in the MVP (removal is a fraction, decay is off).

**Staged path to full model:**
- **Phase 2 — Chlorine residual** (second scalar): first-order bulk decay (mechanistic, analytically exact under the split), plus CT reporting. Validates against EPA CT tables and exercises the stiff-decay/exponential-update path.
- **Phase 3 — Loading-dependent removals**: make η_clar a function of overflow rate and η_filt a function of filtration rate / filter run time (ripening, breakthrough); introduce Iwasaki λ for depth-resolved filtration if desired.
- **Phase 4 — Multi-species / DBP precursors, temperature/pH dependence, wall decay in pipes, filter head-loss coupling.** Pursue mechanistic coagulation kinetics only if a training/optimization use-case demands it; otherwise functional curves remain the honest choice at plant scale.

**Fidelity budget summary:** physical/mechanistic = transport (advection, mixing-cell RTD), chlorine first-order decay; functional = coag-floc-sed removal, granular filtration removal (curve-fit), CT credit (table lookup).

### 6. LAYER-2 HAND-OFF (name only, do not solve)

This new observable creates the following mapping obligations for a separate Layer-2 pass:
- **New perceivable quantities**: solute concentration at each node; removal (efficiency or log-removal) across each unit process; chlorine residual (phase 2); CT and CT-ratio; cumulative mass sent to each declared sink (sludge, backwash-waste).
- **Units and ranges a Layer-2 pass must honestly translate**:
  - Turbidity: internal TSS mass/concentration [mg/L] → display NTU (state the site-specific conversion explicitly; representative ranges: raw 5–1000+ NTU, settled 2–10 NTU, filtered 0.05–0.3 NTU, regulatory 0.3/1 NTU markers).
  - Chlorine residual [mg/L], typical 0.2–4 mg/L; MRDL 4 mg/L.
  - Log-removal (0–4+ log) and % removal (0–100%).
  - CT [mg/L·min] and CT-ratio (dimensionless, ≥1 = compliant).
  - Residence time / RTD (τ, T10) [min].
- **Honesty constraints to flag for Layer-2**: the NTU↔TSS conversion is approximate and instrument/site-specific (do not imply false precision); removal fractions are functional (curve-fit), not measured particle-by-particle — represent as modeled estimates; distinguish physical removal (to sludge/backwash) from reactive consumption (chlorine) in any visualization; never present a removed-mass sink as if solute vanished from the conservation ledger (it is accounted in INV-4); concentrations must never display negative; steady-state vs transient (approach-to-τ) behavior should be perceivable as such.

## Recommendations
1. **Immediately**: implement the turbidity/TSS MVP — one conserved scalar, upwind advection on the existing DAG, tanks-in-series mixing cells per node (N from baffling factor: unbaffled 0.1 → poor 0.3 → average 0.5 → superior 0.7 → plug flow 1.0), functional η_clar/η_filt, no reaction stiffness. Wire INV-4 (global closure + non-negativity + declared-sink ledger) into the existing soak-test harness with tol_rel ≈ 1e−10 of per-tick throughput and Kahan summation at junctions.
2. **First validation gate**: reproduce the four analytic limits (CSTR 63.2%/95.0%/99.3% step response, PFR pure delay, TIS Erlang RTD with σ²_θ = 1/N, steady-state removal fractions) via numeric tracer tests before trusting any removal number. **Threshold to proceed**: inert-tracer mass recovery = 100% ± tol, RTD variance within ~1% of 1/N.
3. **Second gate (literature validation)**: confirm the modeled train reproduces published ranges — settled 2–10 NTU, filtered ≤0.3 NTU, conventional ~2-log particle removal. **If the model can't hit these with plausible η, revisit parameters, not the scheme.**
4. **Phase 2 when MVP is green**: add chlorine as a second scalar with exact-exponential first-order decay and CT reporting; validate 3-log Giardia CT ≈ 112 mg/L·min at 10 °C / pH 7.0 / ~1 mg/L.
5. **Change triggers**: adopt Strang (from Lie–Trotter) if second-order transport accuracy is needed; add loading-dependent η only if operators need to see clarifier/filter performance vary with flow; add wall decay only when distribution-system pipes are in scope.

## Caveats
- Published removal efficiencies vary widely with source water, coagulant, dose, and operation; treat all η values as calibratable parameters, not universal constants. Many of the highest turbidity-removal figures (97–99%+) come from optimized jar tests or industrial wastewater, not routine surface-water plant operation (~55–90% is the realistic routine range for coag-floc-sed).
- The NTU↔TSS relationship is not universal (reported ratios span roughly 0.5–1.5, and the relationship becomes non-linear when sand-size fractions are present); keeping the Layer-1 state as mass avoids baking in a false conversion.
- Chlorine k_b values in the literature span more than an order of magnitude and are reported in mixed units (day⁻¹ vs h⁻¹); normalize carefully. Bulk decay alone omits wall decay (pipes) — acceptable at plant scale but not for full distribution modeling.
- EPA CT table values cited here are drawn from widely-reproduced secondary copies of EPA 815-R-99-013; the exact table cell for the 0.5-log Giardia value differs between reproductions — verify against the primary EPA PDF before hard-coding compliance logic.
- Operator splitting introduces a small splitting error; Strang keeps it second-order, but stiff reaction + advection can still show splitting artifacts at large Δt — keep Δt well below the fastest reaction time constant (1/k_b) and per-cell residence time.
- This is Layer 1 only; all perceptual/units decisions (including the NTU display mapping) are explicitly deferred to the Layer-2 pass.