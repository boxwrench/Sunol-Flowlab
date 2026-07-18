# Drinking Water Plant Digital Twin Sandbox

## Proof-of-Concept Project Outline

## 1. Project Purpose

Build a **desktop-first, low-poly 3D drinking water plant sandbox in Godot** where the user can:

- Move around the plant with an orbiting 3D camera.
- Observe water levels and flows throughout the process train.
- Open, close, and throttle valves and gates.
- Place individual basins and filters in or out of service.
- Adjust flow setpoints and automation logic.
- Create spills, drain-downs, bottlenecks, and low-level conditions.
- Pause, accelerate, and step through simulated time.
- Examine how changes propagate through the complete plant.

The initial product is a **process simulator**, not a game. Goals, scenarios, scoring, operator training, and failure challenges can be added after the underlying simulation is reliable.

---

## 2. Selected Stack

### Core Technology

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Presentation:** Low-poly 3D
- **Initial platform:** Windows desktop
- **Simulation approach:** Custom mass-balance and flow-network model
- **Physics engine:** Godot physics only for camera interaction, object selection, and collision
- **Hydraulic model:** Custom code, not Box3D or CFD
- **Source control:** GitHub
- **AI development:** Claude Code and Codex
- **Modeling tools:** Godot primitives initially, Blender for plant-specific assets
- **Reusable assets:** Kenney, Quaternius, KayKit, Godot Asset Library, and other CC0-compatible sources

### Deliberate Exclusions From the Proof of Concept

- CFD
- Pressure-network solvers
- Full pump curves
- Detailed head-loss calculations
- Detailed flocculation chemistry
- Particle settling physics
- Filter media hydraulics
- Disinfection compliance calculations
- Live SCADA connections
- MQTT or Node-RED integration
- Multiplayer
- Gameplay or scoring

These can be layered onto the same architecture later.

---

## 3. Plant Process Train

```text
Surface Water Reservoir 1 ─┐
                           ├─> Inlet Manifold
Surface Water Reservoir 2 ─┘
                                  │
                                  ▼
                            Flash Mix Facility
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
                         Simulated System Demand
```

The first version should represent this complete topology, but complexity should be introduced one layer at a time.

---

## 4. Fundamental Simulation Model

### 4.1 Fixed Simulation Tick

The hydraulic simulation should run independently from graphics using a fixed time step.

Suggested initial setting:

```text
One simulation update = one simulated second
```

The user can change simulation speed:

- Paused
- Single step
- 1×
- 5×
- 10×
- 30×
- 60×

The engine may render at 60 frames per second, but the process calculations should use a fixed and deterministic simulation clock.

### 4.2 Storage Calculation

Every reservoir, basin, channel, clearwell, and contact basin follows the basic volume balance:

```text
New Volume =
Previous Volume
+ Inflow
- Outflow
- Spill Flow
- Drain Flow
```

In code terms:

```gdscript
volume += (
    inflow_mgd
    - outflow_mgd
    - spill_mgd
    - drain_mgd
) * conversion_factor * simulation_delta
```

Water elevation is then calculated from storage:

```text
Elevation = Bottom Elevation + Water Depth
```

For rectangular structures:

```text
Water Depth = Volume / Surface Area
```

The architecture should also allow a future elevation-storage curve for irregular reservoirs.

### 4.3 Flow Behavior

For the first version, each connection should support one of three flow modes.

#### Commanded Flow

The user or controller requests a specific flow.

```text
Actual Flow = Requested Flow, limited by available water and equipment capacity
```

#### Restricted Flow

The requested flow is reduced by valve or gate position.

```text
Actual Flow = Maximum Flow × Valve Opening
```

#### Simple Gravity Flow

For locations where elevation differences should matter:

```text
Flow = Flow Coefficient × Valve Opening × √Head Difference
```

This simplified head relationship can be added selectively. The entire proof of concept does not need to begin with gravity calculations.

### 4.4 Flow Constraints

Every connection must enforce:

- No negative volume.
- No outflow greater than available water.
- No flow through a fully closed valve.
- No flow through equipment marked out of service.
- Maximum capacity limits.
- Spill flow when maximum operating volume is exceeded.
- Optional low-level cutoff.
- Reverse-flow prohibition (the topology is a directed acyclic graph).

These constraints are more important initially than high hydraulic precision.

---

## 5. Modular Simulation Architecture

The visual Godot scenes should not contain the primary hydraulic calculations. The simulation should remain separate from the 3D models.

This makes it easier to test, modify, and eventually run without graphics.

### 5.1 Core Object Types

#### `StorageNode`

Represents anything that stores water.

Examples:

- Raw-water reservoir
- Sedimentation basin
- Applied channel
- Clearwell
- CT basin
- Treated-water reservoir

Core properties:

```text
ID
Display name
Current volume
Maximum volume
Minimum operating volume
Surface area
Bottom elevation
Current water elevation
Spill elevation
Inflow
Outflow
Drain flow
Spill flow
Operational state
```

#### `JunctionNode`

Represents a location that splits or combines flows without requiring significant storage.

Examples:

- Inlet manifold
- Distribution box
- Filter effluent header

Core properties:

```text
Available inflow
Requested outlet flows
Maximum throughput
Flow distribution method
```

#### `FlowLink`

Connects two process components.

Examples:

- Reservoir to inlet manifold
- Distribution box to Basin 1
- Applied channel to Filter 7

Properties:

```text
Source
Destination
Maximum flow
Requested flow
Actual flow
Valve position
Enabled state
Reverse flow allowed
Flow calculation mode
```

#### `Valve`

Properties:

```text
Position: 0–100%
Manual or automatic
Opening rate
Closing rate
Failure state
Commanded position
Actual position
```

Valve motion should occur over time rather than jumping instantly, although an instant mode can be available for debugging.

#### `Controller`

Represents automation logic.

Examples:

- Level controller
- Flow controller
- Equal-flow splitter
- Lead-lag source selection
- High-level override
- Low-level shutdown

#### `Alarm`

Properties:

```text
Tag
Priority
Trigger condition
Delay
Active state
Acknowledged state
Activation time
Clear time
```

---

## 6. Process-Unit Modules

Each major plant component should be built as a reusable Godot scene backed by one or more simulation objects.

### 6.1 Surface-Water Reservoir Module

Create two instances of the same reservoir scene.

#### Initial Functions

- Adjustable starting elevation.
- Maximum and minimum storage.
- User-adjustable outlet-flow setpoint.
- Outlet valve.
- Low-level alarm.
- Low-low outlet shutdown.
- Visible moving water surface.
- Optional source availability status.

#### Initial Automation

The inlet manifold can draw from:

- Reservoir 1 only.
- Reservoir 2 only.
- Both reservoirs equally.
- Both reservoirs using a configurable percentage split.
- Lead reservoir with lag-reservoir assistance.

### 6.2 Inlet Manifold Module

The inlet manifold combines flows from both reservoirs.

#### Initial Functions

- Display each reservoir's contribution.
- Display total plant influent.
- Enforce manifold capacity.
- Send total flow to flash mix.
- Allow independent inlet valve control.
- Generate a low-flow or high-flow alarm.

It can begin as a junction without meaningful storage.

### 6.3 Flash Mix Module

The flash mix should have a small but visible volume.

#### Initial Functions

- Influent and effluent flow.
- Water level.
- Mixer on/off status.
- Coagulant injection enabled/disabled.
- Chemical dose setpoint.
- Chemical feed rate calculated from plant flow.
- High- and low-level alarms.

#### Initial Water-Quality Placeholder

No chemistry model is required, but the unit can produce a process-state value:

```text
Coagulant Applied = True/False
```

Later this can expand into:

- Dose in mg/L.
- Mixing intensity.
- Coagulation effectiveness.
- Raw-water turbidity.
- pH or alkalinity effects.

### 6.4 Distribution Box Module

The distribution box divides flash-mix effluent among five sedimentation/flocculation trains.

#### Flow Distribution Options

- Equal split among available basins.
- Manually assigned percentage.
- Manually assigned flow setpoint.
- Automatic redistribution when one basin is removed from service.
- Maximum inlet limit for each basin.

#### Example

With a total plant flow of 100 MGD and five basins available:

```text
Basin 1: 20 MGD
Basin 2: 20 MGD
Basin 3: 20 MGD
Basin 4: 20 MGD
Basin 5: 20 MGD
```

With Basin 3 out of service:

```text
Remaining four basins: 25 MGD each
```

The controller should respect each basin's maximum capacity. Excess flow should cause the distribution-box level to rise or produce a capacity alarm.

### 6.5 Flocculation/Sedimentation Basin Module

Create one reusable module and instantiate it five times.

For the proof of concept, each train can be represented as one combined storage process, while the 3D model visually shows flocculation and sedimentation sections.

#### Initial Functions

- Inlet gate.
- Outlet gate.
- Drain valve.
- Water elevation.
- Basin volume.
- Maximum flow.
- Minimum operating level.
- High-level spill.
- In service/out of service state.
- Filling, operating, draining, and empty states.
- Residence-time estimate.

#### Operating States

```text
OFFLINE
FILLING
IN_SERVICE
DRAINING
EMPTY
HIGH_LEVEL
SPILLING
```

#### Simplified Residence Time

```text
Residence Time = Current Volume / Current Throughput
```

No settling-efficiency calculation is required initially.

### 6.6 Applied Channel Module

The applied channel combines flow from the five sedimentation basins and feeds the twelve filters.

This is one of the most important storage elements because filter availability should visibly affect channel level.

#### Initial Functions

- Combine basin effluent.
- Store a configurable volume.
- Display water elevation.
- Split flow among available filters.
- High-level alarm.
- High-high spill condition.
- Low-level filter starvation condition.
- Individual filter influent gates.

#### Important Sandbox Behavior

Taking filters out of service should reduce downstream capacity. If sedimentation flow remains high:

1. Applied-channel level rises.
2. High-level alarm activates.
3. High-high alarm activates.
4. The channel spills if inflow remains greater than filter capacity.

### 6.7 Filter Module

Create one reusable filter scene and instantiate twelve times.

#### Initial Functions

- In service/out of service.
- Influent gate.
- Effluent valve.
- Current flow.
- Maximum filtration rate.
- Filter water level.
- Runtime counter.
- Flow distribution among available filters.
- High-level and low-level alarms.

#### Initial Operating States

```text
OFFLINE
FILLING
FILTERING
DRAINING
EMPTY
```

Backwash can be reserved for the second major development phase.

#### Simplified Throughput Model

```text
Filter Flow =
Minimum of:
- Assigned flow
- Filter capacity
- Available applied-channel water
- Effluent acceptance capacity
```

#### Future Expansion

- Filter loading rate.
- Head loss.
- Turbidity breakthrough.
- Backwash sequence.
- Filter-to-waste.
- Air scour.
- Surface wash.
- Media condition.
- Run-length optimization.

### 6.8 Clearwell Module

The clearwell combines all filter effluent.

#### Initial Functions

- Current volume.
- Water elevation.
- Filter effluent inflow.
- Outlet flow to the CT basins.
- High-level and low-level alarms.
- Spill condition.
- Low-low pump or outlet shutdown.
- Level setpoint.
- Automatic outlet-flow control.

The clearwell is a good first location for demonstrating automatic level control.

### 6.9 Chlorine Contact Basin Modules

Create two instances of a common CT-basin module.

#### Initial Functions

- Parallel flow split.
- Inlet and outlet gates.
- Volume.
- Water elevation.
- Flow.
- Estimated detention time.
- In service/out of service.
- Drain mode.
- High- and low-level alarms.

#### Initial Detention-Time Display

```text
Theoretical Detention Time = Current Volume / Current Flow
```

This is not yet a regulatory CT calculation. It is only a hydraulic residence-time indicator.

#### Flow Modes

- Equal split.
- Operator-assigned percentage split.
- One basin in service.
- Both basins in service.
- Automatic redistribution when one basin is unavailable.

### 6.10 Treated-Water Reservoir Module

This is the final storage component.

#### Initial Functions

- Combined CT-basin inflow.
- Adjustable system demand.
- Current volume.
- Water elevation.
- High- and low-level alarms.
- Spill condition.
- Demand shortfall alarm.
- Optional automatic plant-flow setpoint.

#### Demand Profiles

Initial demand options:

- Constant demand.
- Manually adjustable demand.
- Step change in demand.
- Simple daily demand curve.

A daily curve can be added after the constant-demand version works.

---

## 7. Automation System

Automation should be implemented inside Godot for the proof of concept. Node-RED, MQTT, or PLC emulation can be added later.

### 7.1 Automation Modes

Every controllable asset should support:

```text
MANUAL
AUTO
FORCED
FAILED
```

#### Manual

The user directly controls valve position, gate position, flow setpoint, or equipment state.

#### Auto

A controller determines the command.

#### Forced

A test or scenario overrides normal control.

#### Failed

The equipment cannot follow its command.

### 7.2 Initial Controllers

#### Source-Flow Controller

Maintains the requested plant influent using one or both reservoirs.

#### Sedimentation Flow Splitter

Divides flow among available basins.

#### Filter Flow Splitter

Divides applied-channel flow among available filters.

#### Clearwell Level Controller

Adjusts clearwell outlet flow to maintain a level setpoint.

#### CT-Basin Splitter

Divides clearwell outflow between available contact basins.

#### Treated-Reservoir Level Controller

Optionally adjusts plant influent based on treated-water reservoir level.

This should be added only after manual operation is working.

### 7.3 Editable Control Parameters

The sandbox UI should allow the user to change:

- Level setpoints.
- High and low alarm limits.
- Valve movement rates.
- Maximum flows.
- Flow splits.
- Controller gain.
- Deadband.
- Response delay.
- Startup and shutdown levels.
- Equipment availability.
- Automatic redistribution rules.

The initial controller can use simple proportional logic rather than a full PID.

```text
Output Command =
Current Output
+ Gain × Level Error
```

PID can be added after the simple controller is stable and understandable.

---

## 8. 3D Visual Design

### 8.1 Visual Style

Use a clean, readable low-poly style rather than attempting photographic realism.

Priorities:

1. Water elevation must be obvious.
2. Flow direction must be understandable.
3. Equipment state must be visible.
4. Plant modules must remain visually distinct.
5. Controls and labels must remain legible.

### 8.2 Reusable Assets

Use premade assets where reasonable for:

- Buildings.
- Roads.
- Fencing.
- Trees and terrain.
- Electrical cabinets.
- Generic pumps.
- Pipes.
- Handrails.
- Stairs.
- Lighting.
- Vehicles.
- Operator characters, if later desired.

Custom assets will probably be needed for:

- Sedimentation basins.
- Flocculation chambers.
- Filter cells.
- Clearwell.
- CT basins.
- Applied channel.
- Distribution box.
- Flash mixer.
- Large process gates.

These can initially be assembled from Godot primitives and later replaced with cleaner Blender models.

### 8.3 Water Visualization

Each storage structure should include:

- A movable horizontal water plane.
- Transparent or partially transparent water material.
- Visible wall markings or level scale.
- Spill animation at the overflow elevation.
- Optional arrows or particles indicating flow.
- Highlighting during alarms.

Do not simulate actual fluid surfaces. Move or scale the visual water mesh based on calculated elevation.

### 8.4 Camera Controls

Initial camera features:

- Orbit.
- Pan.
- Zoom.
- Reset view.
- Focus on selected asset.
- Process-area bookmarks.
- Optional overhead plant view.
- Optional follow-flow mode later.

Suggested bookmarks:

- Raw-water reservoirs.
- Headworks.
- Sedimentation area.
- Filter gallery.
- Clearwell and CT.
- Treated-water reservoir.
- Full plant overview.

---

## 9. User Interface

### 9.1 Main Layout

#### 3D Viewport

The plant occupies most of the screen.

#### Selected-Asset Panel

Displays information for the selected equipment:

```text
Name
Equipment type
Operating state
Water elevation
Volume
Inflow
Outflow
Valve position
Setpoint
Alarm status
Manual/Auto mode
```

#### Plant Summary Bar

Displays:

- Plant influent.
- Sedimentation throughput.
- Total filter flow.
- Clearwell level.
- Plant effluent.
- Treated-reservoir level.
- System demand.
- Active alarm count.
- Simulation speed.

#### Time Controls

- Pause.
- Play.
- Single step.
- Speed selector.
- Reset simulation.

#### Alarm Panel

- Timestamp.
- Priority.
- Equipment.
- Alarm description.
- Active/cleared.
- Acknowledged/unacknowledged.

### 9.2 Visualization Overlays

The user should be able to toggle:

- Flow values.
- Water elevations.
- Valve positions.
- Equipment states.
- Alarm indicators.
- Flow-direction arrows.
- Automation mode.
- Capacity utilization.
- Process labels.

### 9.3 Trends

The first version should support a small rolling trend for the selected asset.

Possible variables:

- Level.
- Inflow.
- Outflow.
- Valve position.
- Controller output.
- Flow setpoint.

A full historian is unnecessary initially. An in-memory rolling buffer is sufficient.

---

## 10. Suggested Godot Project Architecture

See [REPOSITORY_ARCHITECTURE.md](file:///C:/Github/Sunol%20FlowLab/docs/REPOSITORY_ARCHITECTURE.md) §3 for the canonical directory structure and project layout.


---

## 11. Data-Driven Configuration

Plant capacities, elevations, and setpoints should not be buried in scripts.

Use Godot Resources or JSON configuration files for:

- Unit capacities.
- Surface areas.
- Bottom elevations.
- Initial water levels.
- Maximum flows.
- Alarm setpoints.
- Valve movement rates.
- Initial equipment states.
- Controller parameters.
- Flow-distribution rules.

This allows a new plant or alternate configuration to be built without rewriting the simulation engine.

Example:

```json
{
  "id": "SED_BASIN_01",
  "type": "storage_node",
  "display_name": "Floc/Sed Basin 1",
  "surface_area_sqft": 85000,
  "bottom_elevation_ft": 412.0,
  "maximum_depth_ft": 18.0,
  "initial_depth_ft": 14.0,
  "maximum_flow_mgd": 40.0,
  "high_level_ft": 17.0,
  "spill_level_ft": 18.0
}
```

The values above are placeholders rather than proposed plant values.

---

## 12. Implementation Sequence

### Phase 0: Project Foundation

Create:

- Godot project.
- GitHub repository.
- Coding standards.
- Unit conventions.
- Tag-naming conventions.
- Simulation clock.
- Automated test structure.
- Basic orbit camera.
- Placeholder environment.

#### Exit Condition

A blank 3D sandbox runs, simulation time can start and stop, and automated tests can execute.

### Phase 1: Single Storage-Unit Prototype

Build one generic rectangular basin with:

- Inlet flow.
- Outlet flow.
- Drain.
- Spill.
- Moving water surface.
- Level display.
- Adjustable valves.
- High- and low-level alarms.

#### Required Demonstration

- Inflow greater than outflow raises the level.
- Outflow greater than inflow lowers the level.
- Closing the outlet causes a spill.
- Opening the drain empties the basin.
- The displayed volume remains consistent with flow balance.

This validates the fundamental simulation before constructing the plant.

### Phase 2: Connected Three-Unit Sandbox

Connect:

```text
Source Reservoir → Basin → Receiving Reservoir
```

Add:

- Flow links.
- Valve restrictions.
- Source depletion.
- Downstream filling.
- Flow propagation.
- Simple automatic level control.

#### Exit Condition

Changes at the first reservoir propagate correctly through all three units without creating or destroying water.

### Phase 3: Headworks and Five Basin Trains

Build:

- Two raw-water reservoirs.
- Inlet manifold.
- Flash mix.
- Distribution box.
- Five flocculation/sedimentation basins.
- Applied channel.

Add:

- Source selection.
- Basin flow splitting.
- Basin availability.
- Redistribution.
- Basin draining.
- Applied-channel level response.

#### Exit Condition

Any basin can be removed from service, and flow is redistributed without violating capacities.

### Phase 4: Twelve-Filter Block

Build one reusable filter module and instantiate twelve.

Add:

- Filter availability.
- Filter flow assignment.
- Applied-channel level effects.
- Filter effluent combining.
- Basic filter runtime.
- Filter capacity alarms.

#### Exit Condition

Removing filters from service reduces plant capacity and can cause the applied channel to rise and spill.

### Phase 5: Clearwell, CT Basins, and Treated Storage

Build:

- Clearwell.
- Two CT basins.
- Treated-water reservoir.
- System demand.

Add:

- CT flow splitting.
- Clearwell level controller.
- Treated-reservoir level response.
- Demand changes.
- Final plant mass-balance reporting.

#### Exit Condition

The entire plant runs from raw-water reservoirs to treated-water demand.

### Phase 6: Control Interface and Alarm System

Complete:

- Selected-asset control panel.
- Manual/auto switching.
- Editable setpoints.
- Alarm list.
- Alarm acknowledgement.
- Trend display.
- Flow and level overlays.
- Simulation reset.
- Save and load initial conditions.

### Phase 7: Visual Refinement

Replace placeholder geometry where useful.

Add:

- Low-poly process assets.
- Better water materials.
- Flow arrows.
- Valve animations.
- Spill effects.
- Plant labels.
- Roads, buildings, terrain, and generic utility assets.
- Camera bookmarks.
- Alarm highlighting.

Simulation correctness should remain more important than visual detail.

---

## 13. Proof-of-Concept Test Scenarios

The finished sandbox should demonstrate at least these behaviors.

### Scenario 1: Loss of One Source Reservoir

- Reservoir 1 outlet closes.
- Reservoir 2 increases contribution.
- Plant flow either recovers or decreases based on available capacity.
- Low-influent alarms activate when appropriate.

### Scenario 2: Sedimentation Basin Isolation

- Basin 3 is removed from service.
- Its inlet gate closes.
- Remaining basins receive redistributed flow.
- Capacity alarms occur if the remaining basins cannot accept the total flow.

### Scenario 3: Sedimentation Outlet Restriction

- One basin outlet gate is throttled.
- The basin level rises.
- High-level alarm activates.
- The basin spills if the condition persists.

### Scenario 4: Filter-Capacity Reduction

- Several filters are taken offline.
- Available filtration capacity decreases.
- Applied-channel level rises.
- The channel spills if influent is not reduced.

### Scenario 5: Excess System Demand

- Treated-water demand increases sharply.
- Treated-reservoir level falls.
- Low-level alarm activates.
- Automatic plant-flow control increases production if enabled.

### Scenario 6: Downstream Shutdown

- Clearwell outlet closes.
- Clearwell level rises.
- Filter effluent backs up operationally.
- Upstream levels eventually rise unless plant flow is reduced.

The model does not need to simulate physical reverse pressure for this scenario. It only needs to propagate reduced acceptance capacity upstream.

### Scenario 7: Full Drain-Down

- Raw-water inflow is stopped.
- Plant units continue discharging.
- Each structure drains according to available water and valve state.
- No component produces negative volume.

---

## 14. Proof-of-Concept Completion Criteria

The POC is successful when:

- The entire plant process train is represented.
- Each storage unit has a visible and numerically correct water level.
- Water is conserved throughout the model.
- Valves and gates affect flows.
- Capacity limits are enforced.
- Equipment can be placed in and out of service.
- Flow can be redistributed across five basins and twelve filters.
- Spills and drain-downs occur correctly.
- Manual and automatic control modes work.
- Setpoints can be changed during operation.
- Alarms activate and clear correctly.
- The simulation can be paused, accelerated, reset, and single-stepped.
- The user can select and inspect every process unit.
- The full plant can run for an extended accelerated period without unstable calculations or negative storage.

---

## 15. AI-Assisted Development Rules

Because Claude Code and Codex will perform much of the implementation, the repository should be designed to reduce ambiguity.

### Canonical Documentation

Both agents should always reference:

- `PROJECT_SCOPE.md`
- `PLANT_TOPOLOGY.md`
- `SIMULATION_RULES.md`
- `CONTROL_LOGIC.md`
- `TAG_NAMING.md`
- `AI_DEVELOPMENT_RULES.md`

### Important Instructions for the Agents

- Keep simulation logic separate from visual scenes.
- Add tests before expanding a hydraulic behavior.
- Do not add CFD or rigid-body fluid physics.
- Do not silently change units.
- Use one canonical internal unit system.
- Document assumptions directly beside the relevant model.
- Use reusable components rather than one-off basin or filter scripts.
- Do not duplicate logic across the twelve filters or five basins.
- Preserve deterministic fixed-step simulation.
- Treat water conservation as a required invariant.
- Keep pull requests or work units small.
- Require a test for every correction to mass balance, splitting, spill, or controller behavior.

### Recommended Internal Units

Use SI internally even when displaying US customary units:

- Volume: cubic meters
- Flow: cubic meters per second
- Elevation: meters
- Time: seconds

The UI can display:

- MGD
- Million gallons
- Feet
- Minutes or hours

This reduces conversion errors inside the simulation kernel.

---

## 16. Expansion Path After the Proof of Concept

Once the sandbox is stable, the next layers could include:

1. Filter backwash and filter-to-waste sequences.
2. Filter head-loss and turbidity models.
3. Raw-water quality changes.
4. Coagulant dose and mixing effectiveness.
5. Simplified settling performance.
6. Chlorine dose, residual decay, and CT calculations.
7. Pump curves and simple hydraulic-grade calculations.
8. PLC-style permissives and interlocks.
9. Equipment failures and instrument faults.
10. Historian playback.
11. Scenario authoring.
12. Operator objectives and scoring.
13. Training modules.
14. Cyber-physical attack scenarios.
15. Node-RED or external automation integration.
16. MQTT telemetry.
17. Live or historical SCADA tag adapters.
18. Alternate plant configurations built from the same reusable modules.

The key architectural decision is to build the **single-basin mass-balance prototype first**, then the connected three-unit test, before assembling the full plant. That will reveal nearly all foundational problems while the project is still small.
