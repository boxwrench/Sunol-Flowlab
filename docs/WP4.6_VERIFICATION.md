# WP4.6 — Derived CI test-script counts

Local verification on 2026-10-01 used official Godot
`4.7.stable.official.5b4e0cb0f`, committed GUT 9.7.0, and Git Bash on Windows.

## Behavior and changed files

- `tools/ci/run_tests.sh` now owns the workflow's defensive checks. It derives the
  expected count from the chosen test directory's recursive `test_*.gd` files and
  explicitly gives GUT the same prefix/suffix and subdirectory settings. Default: `tests`.
  Derived and loaded counts are printed. Missing or ambiguous loaded totals fail instead
  of silently bypassing the count check. Godot's nonzero exit status is enforced.
- `tools/ci/verify_test_runner.sh` exercises that production runner using temporary real
  GUT scripts inside the repository. Its exit trap removes all probe files and their
  directory. No hydraulic, tick, solver, or balance logic is mocked or duplicated.
- `.github/workflows/tests.yml` calls the guardrail probes and the shared full-suite
  runner. The hard-coded `EXPECTED_SCRIPTS` number and duplicated checks are gone.
- `AGENTS.md` and `docs/TESTING_STRATEGY.md` explain automatic count maintenance.
  `CHANGELOG.md` and `docs/ROADMAP.md` record this package.

The runner still rejects test/script errors, files with the wrong test base class,
skipped/risky/pending tests, zero collected tests, and loaded-versus-derived count
mismatches. Only the existing benign `Ignoring Inner Class` helper diagnostic is ignored.

## Executed guardrail probes

Command (first argument can supply a Godot executable path):

```bash
bash tools/ci/verify_test_runner.sh
```

| Case | Derived / loaded | Expected outcome | Observed runner exit |
|------|------------------|------------------|----------------------|
| One valid script | 1 / 1 | Accept | 0 |
| Add a second valid script | 2 / 2 | Accept without editing a total | 0 |
| Unparseable second script | 2 / 1 | Reject script error | 1 |
| Second script has wrong base class | 2 / 1 | Reject failed load | 1 |
| Second script explicitly skips | 2 / 1 | Reject skipped test script | 1 |
| Second test is pending | 2 / 2 | Reject pending test | 1 |
| Second test fails an assertion | 2 / 2 | Reject failing test | 1 |
| Valid test base with no test methods | 1 / unavailable | Reject zero collected tests | 1 |
| No test scripts | 0 / not run | Reject empty discovery | 1 |

Final harness output: `Runner guardrails: 9 checks passed, 0 failed.` Harness exit: 0.
Both shell files passed `bash -n`. After exit, no probe directory or probe GDScript
remained, and independent discovery again counted 34 production test scripts.

## Executed full production suite

```bash
bash tools/ci/run_tests.sh
```

Actual output:

```text
Derived test-script count: 34 (tests/**/test_*.gd)
Scripts              34
Tests               106
Passing Tests       106
Asserts           513364
Time              167.952s
---- All tests passed! ----
Loaded test-script count: 34
Verified 34 of 34 test scripts; Godot exit status 0.
```

Collected: 106. Passed: 106. Failed: 0. The zero-failure line is omitted by GUT.
Runner exit: 0. The existing replay, conservation, nonnegative-storage, and long soak/churn
tests executed; no domain or presentation code changed.

`bash tools/ci/validate_configs.sh` exited 0: 18 valid plant JSON files accepted and all
6 invalid fixtures rejected. No plant fields or schemas changed.

## Remaining scope

WP4.7 is NOT done. Phase 3 / WP4.1 gate closure, plant visuals, filters, clearwell, and
downstream treatment were not built in this package. Existing shutdown diagnostics
(4,815 ObjectDB instances and 6 resources still in use in the full run) remain; the
runner does not newly classify those pre-existing cleanup diagnostics as script errors.
The PowerShell convenience wrapper remains a direct GUT invocation; the shared shell
runner is the defensive CI entry point.
