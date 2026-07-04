# Known Limitations

This document lists the current limitations of the drinking water plant sandbox.  Stating limitations explicitly helps prevent misunderstanding about the simulator's accuracy and intended use.

## Hydraulics

- No pressure‑network hydraulic grade line calculations.
- No computational fluid dynamics (CFD) or finite element modelling.
- Simple gravity‑flow approximation; head losses and pump curves are ignored.
- No detailed filter head‑loss model; filters are limited only by capacity.

## Water quality

- No chemistry model for coagulation, flocculation or disinfection.
- No simulation of turbidity, pH, alkalinity or chlorine residual.
- No regulatory CT calculation for chlorine contact.

## Equipment

- Pumps and motors are not represented; flow is idealised.
- Valves move instantly in the current implementation (will be improved).
- Instruments (e.g., level transmitters) are perfect and never fail.

## Control system

- Simple proportional controllers with no integral or derivative terms.
- No deadband or anti‑reset windup in level controllers.
- No PLC or SCADA interfaces; all control logic runs inside the Godot simulation.

## Process details

- Sedimentation and filtration are modelled as storage units without removal efficiency.
- Backwash sequences, filter‑to‑waste and media condition are not modelled.
- Air scour and surface wash are not represented.

## Visualisation

- Low‑poly assets; water is shown as flat planes rather than dynamic surfaces.
- No lighting or shading variation to indicate water turbidity or clarity.

These limitations reflect the proof‑of‑concept scope and may be addressed in future expansions.  Users should not rely on this simulator for engineering design or regulatory compliance.
