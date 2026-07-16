# Known Limitations

This document lists the current limitations of the drinking water plant sandbox.  Stating limitations explicitly helps prevent misunderstanding about the simulator's accuracy and intended use.

## Hydraulics

- Dynamic pressure networks and hydraulic grade line calculations are out of scope.
- Computational fluid dynamics (CFD) and finite element modeling are out of scope.
- Hydraulics use a simplified gravity-flow approximation; dynamic pipe friction and pump head curves are out of scope.
- Filters are governed by capacity constraints; dynamic filter media head-loss and clogging calculations are out of scope.

## Water quality

- Water chemistry modeling (coagulation, flocculation, disinfection kinetics) is out of scope.
- Tracking water quality parameters (turbidity, pH, alkalinity, chlorine residual) is out of scope.
- Regulatory CT calculations for disinfection contact are out of scope.

## Equipment

- Physical pumps and motors are out of scope; flow links represent idealized, actuated pathways.
- Valves operate with rate-limited travel by default, with instant movement restricted to a testing/debugging override.
- Instruments (e.g., level transmitters) represent perfect measurements; sensor noise, drift, and calibration failures are out of scope.

## Control system

- Control logic is implemented as a velocity-form PID controller with deadband, proportional/derivative damping (kp/kd), and optional bumpless transfer; other complex PID topologies and advanced anti-reset windup are out of scope.
- External PLC or SCADA communication interfaces are out of scope; all control logic is executed natively by the simulation clock.

## Process details

- Sedimentation basins and filters are modeled as storage units; solids removal and filtration efficiency calculations are out of scope.
- Backwash sequences, filter-to-waste cycles, and filter media conditions are out of scope.
- Air scour and surface wash systems are out of scope.

## Visualisation

- Presentation uses low-poly assets; water surfaces are represented as flat, translation-based planes rather than dynamic liquid meshes.
- Visual indications of water quality (such as turbidity, color, or clarity changes) are out of scope.
- Photorealistic water, plant clutter, detailed pipe routing, ambient process-like motion,
  and decorative turbulence are intentionally excluded. Visual polish is limited to
  legible, snapshot-backed state mappings defined in `PRESENTATION_MAPPING.md`.

These scope definitions define the boundaries of the proof-of-concept simulation.  Users should not rely on this simulator for engineering design or regulatory compliance.
