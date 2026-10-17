#!/usr/bin/env python3
"""One line per sim save: each run as W (beat Mega Mole) or the end reason's
letter, time, level and Danger; then the run of the first boss win and the
first unlock bought.  tools/balance_runs.py OUT_DIR"""
import glob, json, sys
for p in sorted(glob.glob(sys.argv[1] + '/*.json')):
    d = json.load(open(p))
    runs = ' '.join(('W' if r['won'] else r['reason'][0]) + f"{int(r['time'])//60}:{int(r['time'])%60:02d}L{r['level']}D{r['danger']}" for r in d['runs'])
    m = d.get('milestones', {})
    print(p.split('/')[-1][:-5], runs, '| boss', m.get('first_boss', {}).get('run'), 'unlock', m.get('first_unlock_bought', {}).get('run'))
