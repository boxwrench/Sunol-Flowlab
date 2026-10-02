#!/bin/bash
# Run from the repository root. An optional narrower test directory supports
# guardrail verification with temporary real GUT scripts.
set -euo pipefail
GODOT_PATH=${1:-godot}
TEST_DIR=${2:-tests}
OUTPUT_LOG=${3:-gut_output.log}

EXPECTED_SCRIPTS=$(find "$TEST_DIR" -type f -name 'test_*.gd' -printf '.\n' | wc -l | tr -d '[:space:]')
echo "Derived test-script count: $EXPECTED_SCRIPTS ($TEST_DIR/**/test_*.gd)"
if [ "$EXPECTED_SCRIPTS" -eq 0 ]; then
    echo "ERROR: No test scripts found."
    exit 1
fi

echo "Running GUT tests with: $GODOT_PATH"
set +e
"$GODOT_PATH" --headless -s addons/gut/gut_cmdln.gd "-gdir=res://$TEST_DIR" \
    -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gdisable_colors -gexit > "$OUTPUT_LOG" 2>&1
GUT_RC=$?
set -e
cat "$OUTPUT_LOG"

ACTUAL_SCRIPTS=$(awk '/^Scripts[[:space:]]+[0-9]+[[:space:]]*$/ {print $2}' "$OUTPUT_LOG")
echo "Loaded test-script count: ${ACTUAL_SCRIPTS:-unavailable}"

if grep -qiE 'Failing Tests|SCRIPT ERROR' "$OUTPUT_LOG"; then
    echo "ERROR: GUT reported test failures or script errors."
    exit 1
fi

# The production tick-order test contains a deliberately non-test inner helper.
# Ignore only that diagnostic, not failures to load a test script.
if grep -iE 'Parse error|does not extend GutTest|does not extend gut_test' "$OUTPUT_LOG" \
        | grep -vi 'Ignoring Inner Class'; then
    echo "ERROR: One or more test scripts failed to load."
    exit 1
fi
if grep -qiE 'Script was skipped|Risky/Pending[[:space:]]+[1-9]|\[Pending\]|\[Risky\]' "$OUTPUT_LOG"; then
    echo "ERROR: GUT skipped tests or reported risky/pending tests."
    exit 1
fi
if ! grep -qE '^Tests[[:space:]]+[1-9][0-9]*[[:space:]]*$' "$OUTPUT_LOG"; then
    echo "ERROR: Zero tests were collected or run."
    exit 1
fi
if ! [[ "$ACTUAL_SCRIPTS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not parse a unique loaded test-script count."
    exit 1
fi
if [ "$ACTUAL_SCRIPTS" -ne "$EXPECTED_SCRIPTS" ]; then
    echo "ERROR: Expected $EXPECTED_SCRIPTS test scripts but GUT loaded $ACTUAL_SCRIPTS."
    exit 1
fi
if [ "$GUT_RC" -ne 0 ]; then
    echo "ERROR: Godot exited with status $GUT_RC."
    exit "$GUT_RC"
fi
echo "Verified $ACTUAL_SCRIPTS of $EXPECTED_SCRIPTS test scripts; Godot exit status 0."
