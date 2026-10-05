#!/usr/bin/env bash
# Runs the headless test suite. Fails on any failed check AND on any engine or
# script error in the output (a GDScript runtime error doesn't fail a check by
# itself, it only aborts that test function).
set -u
cd "$(dirname "$0")/.."
# Refresh the global class cache first: new class_name scripts are not seen
# by "-s" runs until an import has scanned them.
timeout 300 godot --headless --path . --import >/dev/null 2>&1
# A script that fails to compile can stop the runner before quit(); the
# timeout turns that hang into a failure.
out=$(timeout 900 godot --headless --path . -s res://tests/run_tests.gd 2>&1)
code=$?
echo "$out" | grep -E -A2 "FAIL|SCRIPT ERROR|^ERROR|checks"
if [ $code -ne 0 ] || echo "$out" | grep -qE "SCRIPT ERROR|^ERROR"; then
	echo "TESTS FAILED"
	exit 1
fi
echo "TESTS OK"
