#!/usr/bin/env bash
# Runs the balance simulation (scripts/debug/campaign_sim.gd) as many headless
# processes in parallel and writes one JSON per process to OUT_DIR. Then
# tools/balance_report.py OUT_DIR > docs/BALANCE.md.
#
#   tools/balance_sim.sh OUT_DIR [campaign|matrix|all] [JOBS]
#
# campaign: fresh saves, 5 typical + 3 good players (seeds 1-5 / 1-3).
# early: 14 typical fresh saves, 6 runs each (boss on run 2-3, first unlock).
# matrix: 10 runs (RUNS=n) per hero per Danger for typical and good players, from a
#   fresh save (heroes owned) and from a maxed save; one process per Danger.
# Extra args for every process can go in SIM_ARGS (e.g. SIM_ARGS="--max_runs=40").
# The game steps at 20 fps (run.json max_dt is 0.05 s, so a step is never
# cut): about a third faster than 30 fps.
set -u
cd "$(dirname "$0")/.."
out=${1:?OUT_DIR}
what=${2:-all}
jobs=${3:-$(( $(nproc) - 2 ))}
mkdir -p "$out"
out=$(cd "$out" && pwd)
timeout 300 godot --headless --path . --import >/dev/null 2>&1

cmds=()
if [ "$what" = early ]; then
	for s in $(seq 101 114); do cmds+=("--mode=campaign --skill=typical --seed=$s --max_runs=6 --out=$out/campaign_typical_$s.json"); done
fi
if [ "$what" = campaign ] || [ "$what" = all ]; then
	for s in 1 2 3 4 5; do cmds+=("--mode=campaign --skill=typical --seed=$s --out=$out/campaign_typical_$s.json"); done
	for s in 1 2 3; do cmds+=("--mode=campaign --skill=good --seed=$s --out=$out/campaign_good_$s.json"); done
fi
if [ "$what" = matrix ] || [ "$what" = all ]; then
	for meta in fresh max; do
		for skill in typical good; do
			for d in 1 2 3 4 5; do
				cmds+=("--mode=matrix --meta=$meta --skill=$skill --dangers=$d --runs=${RUNS:-10} --seed=$d --out=$out/matrix_${meta}_${skill}_d$d.json")
			done
		done
	done
fi

printf '%s\n' "${cmds[@]}" | xargs -P "$jobs" -I{} sh -c \
	'timeout 14400 godot --headless --fixed-fps 20 --path . res://scenes/debug/campaign_sim.tscn -- {} '"${SIM_ARGS:-}"' 2>&1 | grep -E -A2 "^RESULT|SCRIPT ERROR|^ERROR" | cut -c1-300'
echo "balance_sim: done, $(ls "$out"/*.json | wc -l) files in $out"
