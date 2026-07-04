# Documentation Index

This index defines the authority order of the repository documentation. In the event of any structural conflict or contradiction between documents, the priority hierarchy is:

1. **Canonical architecture**
   - [REPOSITORY_ARCHITECTURE.md](REPOSITORY_ARCHITECTURE.md) — Canonical design, naming, folder structure, layers, and contracts. Wins all conflicts.
2. **Process specifications** (binding on code)
   - [SIMULATION_RULES.md](SIMULATION_RULES.md) — Physics, mass-balance equations, tick order, determinism mechanics, proration.
   - [PROCESS_UNIT_CONTRACTS.md](PROCESS_UNIT_CONTRACTS.md) — Interface definitions for all simulated unit classes.
   - [INTERNAL_UNITS.md](INTERNAL_UNITS.md) — SI internal units, display units, naming suffixes.
   - [CONTROL_LOGIC.md](CONTROL_LOGIC.md) — Control modes, controller order, splitting rules.
   - [PLANT_TOPOLOGY.md](PLANT_TOPOLOGY.md) — Connectivity, ports, and plant configuration.
   - [TAG_NAMING.md](TAG_NAMING.md) — Identifier format and tag structure.
   - [CONFIGURATION_REFERENCE.md](CONFIGURATION_REFERENCE.md) — Plant JSON configuration fields.
3. **Planning & reviews**
   - [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) — Work packages, gates, exit criteria, **Cold-Start Protocol**.
   - [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md) — Invariants INV-1/2/3, gates G0–G5, design rationale.
   - [PHASE1_CODE_REVIEW.md](PHASE1_CODE_REVIEW.md) — Findings F1–F8 and remediation record.
   - [PHASE2_CODE_REVIEW.md](PHASE2_CODE_REVIEW.md) — WP2.2 review, findings F2.2-1…5, WP2.2-R fix list.
   - [ROADMAP.md](ROADMAP.md) — Multi-phase milestones.
   - [DECISIONS/](DECISIONS/) — Architecture Decision Records (ADR 0001–0006).
4. **Project metadata**
   - [PROJECT_SCOPE.md](PROJECT_SCOPE.md) — POC boundaries vs future phases.
   - [PROJECT_OUTLINE.md](PROJECT_OUTLINE.md) — High-level functional specification.
   - [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) — Explicit scope exclusions.
   - [GLOSSARY.md](GLOSSARY.md) — Plant terminology.
5. **Guides** (non-binding how-to)
   - [ADDING_A_PROCESS_UNIT.md](ADDING_A_PROCESS_UNIT.md) — Adding new units.
   - [DEBUGGING_GUIDE.md](DEBUGGING_GUIDE.md) — Tracing common errors.
   - [TESTING_STRATEGY.md](TESTING_STRATEGY.md) — Test categories and expectations.
6. **Archive** (background, non-authoritative)
   - [archive/deep-research-report.md](archive/deep-research-report.md) — Pre-project engine research.

Agent behavior rules live in [`AGENTS.md`](../AGENTS.md) at the repository root and apply above everything here except REPOSITORY_ARCHITECTURE.md structural rulings.

All links are relative — do not use absolute `file:///` paths anywhere in this repository's documentation.
