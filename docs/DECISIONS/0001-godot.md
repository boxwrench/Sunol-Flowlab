# Decision 0001: Choose Godot and GDScript

## Status

Accepted

## Context

The project requires a cross‑platform engine capable of rendering 3D scenes, handling user input and integrating with a custom simulation engine.  It should be open source and amenable to AI‑assisted development.

## Decision

Use **Godot Engine 4.x** as the rendering and UI platform.  Implement gameplay scripts and simulation visualisation in **GDScript**, Godot's built‑in scripting language.

## Rationale

- Godot 4.x is open source, lightweight and runs on multiple platforms (Windows, Linux, macOS).
- GDScript offers tight integration with Godot's scene tree and node system.
- The engine includes a physics engine suitable for camera interactions and object selection; however, we will **not** use its fluid simulation capabilities.
- Godot's asset pipeline supports importing low‑poly models from Blender and CC0 asset packs.
- The community provides a rich ecosystem of add‑ons and tutorials.

## Consequences

- Contributors must install Godot 4.x to develop and run the project.
- The simulation logic must remain decoupled from Godot scenes to allow headless testing.
- Future porting to another engine would require reimplementing the UI layer.
