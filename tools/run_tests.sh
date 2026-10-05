#!/usr/bin/env bash
# Runs the headless test suite. Fails on any failed check AND on any engine or
# script error in the output (a GDScript runtime error doesn't fail a check by
# itself, it only aborts that test function).
set -u
cd "$(dirname "$0")/.."
out=$(godot --headless --path . -s res://tests/run_tests.gd 2>&1)
code=$?
echo "$out" | grep -E "FAIL|SCRIPT ERROR|^ERROR|checks"
if [ $code -ne 0 ] || echo "$out" | grep -qE "SCRIPT ERROR|^ERROR"; then
	echo "TESTS FAILED"
	exit 1
fi
echo "TESTS OK"
