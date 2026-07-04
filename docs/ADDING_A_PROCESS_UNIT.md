# Adding a Process Unit

This guide provides a checklist for adding a new process unit (e.g., pump, additional basin) to the drinking water plant sandbox.  Following these steps ensures consistent integration with the simulation engine, configuration and UI.

1. **Create the domain model**
   - Decide which contract (StorageNode, JunctionNode, FlowLink, Valve, Controller) best fits the new unit.  If none fits, define a new contract in `docs/PROCESS_UNIT_CONTRACTS.md`.
   - Implement the model under `simulation/components/` using GDScript.
   - Include inputs, outputs, stored state, commands and events as defined in the contract.

2. **Define ports**
   - Determine the number and type of inflow and outflow ports.
   - Update the unit contract if necessary.

3. **Add configuration schema**
   - Add the unit to `config/plants/<plant_id>/topology.json` with its ID, type and ports.
   - Add default parameters to `config/plants/<plant_id>/equipment/`.
   - Document new fields in `docs/CONFIGURATION_REFERENCE.md`.

4. **Register the factory**
   - Implement a factory method in `simulation/core/plant_network.gd` to construct the unit from configuration.

5. **Write tests**
   - Create unit tests under `simulation/tests/` to verify mass balance, flow constraints and state transitions.
   - Add integration tests if the unit interacts with existing units.

6. **Build the visual scene**
   - Create a low‑poly 3D scene for the unit under `scenes/modules/`.
   - Design the scene so that water level, flow direction and equipment state are clear.

7. **Add the presentation adapter**
   - Write a script that binds the unit's simulation data to the scene (e.g., moves water plane, updates labels).
   - Ensure the scene subscribes to simulation snapshots.

8. **Update documentation**
   - Add the unit to `docs/PLANT_TOPOLOGY.md` if it is part of the default plant.
   - Update `docs/PROCESS_UNIT_CONTRACTS.md` with any new contract fields.
   - Add a description of the unit to `docs/PROJECT_SCOPE.md` if relevant.

9. **Add the unit to the plant**
   - Instantiate the unit in the Godot scene hierarchy.
   - Place it at a reasonable position using `presentation_map.json`.

10. **Run invariant tests**
    - Execute the headless test suite to ensure that adding the unit has not broken mass balance or other invariants.

By following this checklist, you reduce integration problems and ensure that the new unit behaves consistently with existing simulation rules.
