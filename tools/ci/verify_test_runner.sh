#!/bin/bash
# Exercise the production runner with temporary real GUT scripts. No simulation
# logic is mocked or duplicated. The fixtures are removed even on failure.
set -euo pipefail
GODOT_PATH=${1:-godot}
PROBE_DIR=$(mktemp -d tests/wp46_runner_probe.XXXXXX)
PROBE_LOG="$PROBE_DIR/output.log"
CHECKS=0

cleanup() {
    rm -f -- "$PROBE_DIR/test_valid.gd" "$PROBE_DIR/test_valid.gd.uid" \
        "$PROBE_DIR/test_added.gd" "$PROBE_DIR/test_added.gd.uid" "$PROBE_LOG" "$PROBE_DIR/case.log"
    rmdir -- "$PROBE_DIR"
}
trap cleanup EXIT

run_case() {
    local label=$1 expected_result=$2 expected_count=$3
    local result=0
    bash tools/ci/run_tests.sh "$GODOT_PATH" "$PROBE_DIR" "$PROBE_LOG" \
        > "$PROBE_DIR/case.log" 2>&1 || result=$?
    if { [ "$expected_result" = pass ] && [ "$result" -ne 0 ]; } || \
       { [ "$expected_result" = fail ] && [ "$result" -eq 0 ]; }; then
        cat "$PROBE_DIR/case.log"
        rm -f -- "$PROBE_DIR/case.log"
        echo "FAIL: $label (unexpected exit $result)"
        exit 1
    fi
    if ! grep -q "Derived test-script count: $expected_count " "$PROBE_DIR/case.log"; then
        cat "$PROBE_DIR/case.log"
        rm -f -- "$PROBE_DIR/case.log"
        echo "FAIL: $label (incorrect derived count)"
        exit 1
    fi
    grep -E '^Derived test-script count:|^Loaded test-script count:|^Verified|^ERROR:' "$PROBE_DIR/case.log"
    rm -f -- "$PROBE_DIR/case.log"
    CHECKS=$((CHECKS + 1))
    echo "PASS: $label (runner exit $result)"
}

cat > "$PROBE_DIR/test_valid.gd" <<'GDSCRIPT'
extends "res://addons/gut/test.gd"
func test_valid_probe() -> void:
    assert_true(true)
GDSCRIPT
run_case 'one valid script' pass 1

cp "$PROBE_DIR/test_valid.gd" "$PROBE_DIR/test_added.gd"
run_case 'added valid script counted automatically' pass 2

cat > "$PROBE_DIR/test_added.gd" <<'GDSCRIPT'
extends "res://addons/gut/test.gd"
func test_broken( -> void:
GDSCRIPT
run_case 'unparseable script rejected' fail 2

cat > "$PROBE_DIR/test_added.gd" <<'GDSCRIPT'
extends RefCounted
func test_wrong_base() -> void:
    pass
GDSCRIPT
run_case 'wrong base class rejected' fail 2

cat > "$PROBE_DIR/test_added.gd" <<'GDSCRIPT'
extends "res://addons/gut/test.gd"
func should_skip_script():
    return "WP4.6 intentional skip probe"
func test_skipped() -> void:
    assert_true(true)
GDSCRIPT
run_case 'skipped script rejected' fail 2

cat > "$PROBE_DIR/test_added.gd" <<'GDSCRIPT'
extends "res://addons/gut/test.gd"
func test_pending() -> void:
    pending("WP4.6 intentional pending probe")
GDSCRIPT
run_case 'pending test rejected' fail 2

cat > "$PROBE_DIR/test_added.gd" <<'GDSCRIPT'
extends "res://addons/gut/test.gd"
func test_failing() -> void:
    assert_true(false)
GDSCRIPT
run_case 'failing test rejected' fail 2

rm -f -- "$PROBE_DIR/test_added.gd" "$PROBE_DIR/test_added.gd.uid"
printf '%s\n' 'extends "res://addons/gut/test.gd"' > "$PROBE_DIR/test_valid.gd"
run_case 'zero collected tests rejected' fail 1

rm -f -- "$PROBE_DIR/test_valid.gd" "$PROBE_DIR/test_valid.gd.uid"
run_case 'zero discovered scripts rejected' fail 0
echo "Runner guardrails: $CHECKS checks passed, 0 failed."
