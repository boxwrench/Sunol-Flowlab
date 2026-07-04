# Tag Naming Conventions

Consistent identifiers are critical when referencing process units, instruments, alarms and links across configuration files, tests and code.  This document defines the naming rules for tags.

## General rules

- Use **uppercase letters** and underscores (`_`).
- Begin with a prefix that identifies the unit type (e.g., `SED`, `FLT`, `CWL`).
- Include a two‑digit index for numbered units (e.g., `SED_BASIN_01`).
- Use clear suffixes to distinguish between influent and effluent, gates and valves.
- Avoid spaces and special characters.

## Unit identifiers

Unit IDs typically follow the pattern:

```
<PREFIX>_<NAME>_<INDEX>
```

Examples:

- `SED_BASIN_01` – Sedimentation basin #1
- `FLT_07` – Filter #7
- `CWL` – Clearwell (no index if only one)

## Instrument tags

Instrument IDs include a function indicator:

```
<FUNCTION>_<UNIT_ID>_<LOCATION>
```

Functions:

- `LIT` – Level indicating transmitter.
- `FIT` – Flow indicating transmitter.
- `PIT` – Pressure indicating transmitter.
- `AIT` – Analytical indicating transmitter.

Locations:

- `IN` – Inlet.
- `OUT` – Outlet.
- `EFF` – Effluent.

Example:

- `LIT_CWL_01` – Level transmitter for clearwell #1.
- `FIT_FLT_07_EFF` – Effluent flow transmitter for filter #7.

## Actuator tags

Gate and valve tags begin with:

- `GV` – Gate valve.
- `MV` – Motor valve.

Example:

- `GV_SED_03_IN` – Inlet gate valve for sedimentation basin #3.

## Alarm tags

Alarm IDs start with `ALM_` followed by the object and condition:

```
ALM_<OBJECT>_<CONDITION>
```

Examples:

- `ALM_APPLIED_CH_HI` – High level alarm for the applied channel.
- `ALM_CWL_LO` – Low level alarm for the clearwell.

## Link identifiers

Links use `LINK_<SOURCE>_TO_<DESTINATION>`:

Example:

- `LINK_SED_01_TO_APPLIED` – Flow link from sedimentation basin #1 effluent to applied channel.

## Human‑readable names

While tags are used internally, the user interface should display **human‑readable names** stored in configuration files (`display_name`).  Do not derive names from tags in the UI.
