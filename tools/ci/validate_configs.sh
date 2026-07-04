#!/bin/bash
# Validates plant configs against config/schema/*.schema.json.
# Positive: every JSON file in config/plants/*/ must pass its schema.
# Negative: every file in tests/fixtures/schema_invalid/ must FAIL its schema
# (guards against schemas so permissive they accept anything).
set -u
SCHEMA_DIR="config/schema"
fail=0

for f in config/plants/*/*.json; do
  name=$(basename "$f")
  schema="$SCHEMA_DIR/${name%.json}.schema.json"
  if [ ! -f "$schema" ]; then
    echo "FAIL: no schema for $f (expected $schema)"
    fail=1
    continue
  fi
  if check-jsonschema --schemafile "$schema" "$f"; then
    echo "ok: $f"
  else
    echo "FAIL: $f violates $schema"
    fail=1
  fi
done

for f in tests/fixtures/schema_invalid/*.json; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  schema="$SCHEMA_DIR/${name%.json}.schema.json"
  if [ ! -f "$schema" ]; then
    echo "FAIL: no schema for negative fixture $f"
    fail=1
    continue
  fi
  if check-jsonschema --schemafile "$schema" "$f" >/dev/null 2>&1; then
    echo "FAIL: $f unexpectedly PASSED $schema — schema too permissive"
    fail=1
  else
    echo "ok (rejected as intended): $f"
  fi
done

exit $fail
