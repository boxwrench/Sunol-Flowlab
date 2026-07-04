# Glossary

This glossary defines terms used in the drinking water plant sandbox documentation.  It helps align understanding between game developers, water operators and AI agents.

| Term | Definition |
| --- | --- |
| **Applied water** | Water downstream of sedimentation that is applied to filters. |
| **Clearwell** | A storage tank that collects filtered water before disinfection and distribution. |
| **CT basin** | Chlorine contact basin; provides detention time for disinfectant to inactivate pathogens. |
| **Process unit** | A discrete component of the plant (reservoir, basin, filter, clearwell, CT basin). |
| **Storage node** | A simulation object that stores water volume and computes level. |
| **Junction** | A node that splits or combines flows without storage. |
| **Flow port** | A connection point on a unit where flow enters or leaves. |
| **Permissive** | A condition that must be true before equipment can operate (e.g., sufficient volume). |
| **Interlock** | A logic rule that automatically stops equipment under unsafe conditions. |
| **Setpoint** | Target value for a controller (e.g., desired clearwell level). |
| **Actual flow** | Flow that actually occurs after applying constraints and valve positions. |
| **Commanded flow** | Flow requested by a controller or operator before constraints are applied. |
| **External source** | A supply of water that is not part of the simulated plant (e.g., raw water reservoir). |
| **External sink** | A destination for water that leaves the simulation (e.g., system demand, spill). |
