# Contributing Guide

Thank you for considering a contribution to the drinking water plant sandbox.  This guide outlines the process for submitting changes and the expectations for contributors.

## Branch strategy

Develop your changes on a feature branch, named descriptively (e.g., `feature/add-filter-module`).  Do not commit directly to the `main` branch.

## Commit format

Write clear commit messages following the pattern:

```
<type>: <short summary>

<detailed description>
```

Types include `feat`, `fix`, `docs`, `test`, `refactor`.

## Pull requests

When opening a pull request:

- Reference the issue or feature request it addresses.
- Describe what was changed and why.
- Explain how to test the changes.
- Ensure the branch is up to date with `main`.
- Include screenshots or recordings if the UI is affected.
- Assign reviewers familiar with the affected components.

## Testing requirements

- All new or changed simulation logic must be covered by unit or integration tests.
- Run the test suite (`godot --headless --script res://simulation/tests/test_runner.gd`) before submitting.
- If a bug is fixed, include a failing test that would have caught it.

## Documentation requirements

- Update relevant documentation (e.g., contracts, configuration reference, control logic) when behaviour or interfaces change.
- Add or update comments in code to explain non‑obvious logic.

## Adding new process units

Refer to `docs/ADDING_A_PROCESS_UNIT.md` for a checklist on integrating new modules.

## Code style

Use spaces (4 per indent), UTF‑8 encoding and LF line endings.  The `.editorconfig` file defines these settings.

We appreciate your contributions and aim to review pull requests in a timely manner.  Please raise any questions in issues before starting major work.
