#!/usr/bin/env python3
"""Turns the JSON files of tools/balance_sim.sh into the tables of
docs/BALANCE.md (Markdown on stdout).

  tools/balance_report.py OUT_DIR [--title=...]

Campaign files (campaign_<skill>_<seed>.json): fresh saves played forward.
Matrix files (matrix_<meta>_<skill>_d<n>.json): fixed saves, every hero on a
Danger level. Weapon counts leave out the hero's own signature weapon (it is
in every one of that hero's runs and isn't a choice); the "with signature"
column counts it too.
"""
import glob
import json
import os
import statistics
import sys

HEROES = {"sir_loaf": "Sir Loaf", "turbo_pigeon": "Turbo Pigeon", "gary": "Gary"}
TARGET_SHARE = (0.30, 0.40)


def load(d):
    out = {"campaign": [], "matrix": []}
    for p in sorted(glob.glob(os.path.join(d, "*.json"))):
        with open(p) as f:
            j = json.load(f)
        j["_file"] = os.path.basename(p)
        out[j.get("mode", "campaign")].append(j)
    return out


def pct(a, b):
    return "-" if b == 0 else f"{100.0 * a / b:.0f}%"


def med(xs, fmt="{:.0f}"):
    xs = [x for x in xs if x is not None]
    return "-" if not xs else fmt.format(statistics.median(xs))


def mmss(s):
    return f"{int(s) // 60}:{int(s) % 60:02d}"


def table(head, rows):
    lines = ["| " + " | ".join(head) + " |", "| " + " | ".join("---" for _ in head) + " |"]
    lines += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(lines)


def hero_table(runs):
    rows = []
    for h, name in HEROES.items():
        rs = [r for r in runs if r["hero"] == h]
        if not rs:
            continue
        won = [r for r in rs if r["won"]]
        rows.append([name, len(rs), pct(len(won), len(rs)), mmss(statistics.median(r["time"] for r in rs)),
                     med([r["level"] for r in rs]), med([r["kills"] for r in rs]), med([r["run_coins"] for r in rs])])
    return table(["Hero", "Runs", "Beat Mega Mole", "Median time", "Median level", "Median KO", "Median run coins"], rows)


def weapon_table(runs):
    wins = [r for r in runs if r["won"]]
    allw = sorted({w for r in runs for w in r["weapons"]})
    rows = []
    for w in allw:
        held = [r for r in runs if w in r["weapons"] and w != r["signature"]]
        held_won = [r for r in held if r["won"]]
        in_wins = [r for r in wins if w in r["weapons"] and w != r["signature"]]
        in_wins_sig = [r for r in wins if w in r["weapons"]]
        rows.append([w.replace("_", " ").title(), pct(len(in_wins), len(wins)), pct(len(in_wins_sig), len(wins)),
                     pct(len(held), len(runs)), pct(len(held_won), len(held))])
    rows.sort(key=lambda r: -float(r[1].rstrip("%")) if r[1] != "-" else 0)
    return table(["Weapon", "In winning runs (taken)", "With signature", "Taken in runs", "Win rate when taken"], rows), wins


def danger_table(groups):
    """groups: [(label, runs)] -> one row per danger, one column per group."""
    dangers = sorted({r["danger"] for _, runs in groups for r in runs})
    rows = []
    for d in dangers:
        row = [f"Danger {d}"]
        for _, runs in groups:
            rs = [r for r in runs if r["danger"] == d]
            row.append("-" if not rs else f"{pct(sum(r['won'] for r in rs), len(rs))} ({len(rs)})")
        rows.append(row)
    return table(["Danger"] + [g for g, _ in groups], rows)


def campaign_section(camps):
    out = []
    for skill in ("typical", "good"):
        cs = [c for c in camps if c["skill"] == skill]
        if not cs:
            continue
        out.append(f"\n#### {skill.title()} player ({len(cs)} fresh saves)\n")
        keys = ["first_boss", "first_unlock_done", "first_unlock_bought", "hero_turbo_pigeon", "hero_gary",
                "danger_2_open", "danger_3_open", "danger_4_open", "danger_5_open", "all_buildings_built",
                "all_unlocks", "all_buildings_max", "all_shop_max", "danger_5_beaten"]
        names = {"first_boss": "First Mega Mole win", "first_unlock_done": "First unlock challenge done",
                 "first_unlock_bought": "First unlock bought", "hero_turbo_pigeon": "Turbo Pigeon hired",
                 "hero_gary": "Gary hired", "danger_2_open": "Danger 2 open", "danger_3_open": "Danger 3 open",
                 "danger_4_open": "Danger 4 open", "danger_5_open": "Danger 5 open",
                 "all_buildings_built": "All 4 buildings built", "all_unlocks": "All 19 unlocks bought",
                 "all_buildings_max": "Every building at max level", "all_shop_max": "Every shop upgrade at max",
                 "danger_5_beaten": "Mega Mole beaten on Danger 5"}
        rows = []
        for k in keys:
            got = [c["milestones"][k] for c in cs if k in c["milestones"]]
            rows.append([names[k], f"{len(got)}/{len(cs)}", med([g["run"] for g in got]),
                         med([g["hours"] for g in got], "{:.1f}"), med([g["days"] for g in got])])
        out.append(table(["Milestone", "Saves that got there", "Median run", "Median hours played", "Median day"], rows))
        done = [c for c in cs if c.get("done")]
        coins = {k: sum(c["coins"][k] for c in cs) for k in ("run", "quest", "patrol")}
        total = sum(coins.values())
        out.append(f"\nCoins over all {sum(c['runs_played'] for c in cs)} runs: runs {coins['run']:,}, quests {coins['quest']:,}, "
                   f"Patrol {coins['patrol']:,}. Quests' share: **{pct(coins['quest'], total)}** of all coins "
                   f"({pct(coins['quest'], coins['run'] + coins['quest'])} of runs + quests). "
                   f"{len(done)}/{len(cs)} saves finished everything within the run cap.")
        # Quests share over the first 20 runs (the phase 12 measure).
        early = {"run": 0, "quest": 0, "patrol": 0}
        for c in cs:
            for r in c["runs"][:20]:
                early["run"] += r["run_coins"]
                early["quest"] += r.get("quest_coins", 0)
                early["patrol"] += r.get("patrol_coins", 0)
        out.append(f"First 20 runs: quests {pct(early['quest'], sum(early.values()))} of all coins "
                   f"({pct(early['quest'], early['run'] + early['quest'])} of runs + quests).")
    return "\n".join(out)


def main():
    d = sys.argv[1]
    data = load(d)
    camps, mats = data["campaign"], data["matrix"]
    print("<!-- generated by tools/balance_report.py from %s -->" % d)
    if camps:
        runs = [r for c in camps for r in c["runs"]]
        print("\n### Campaign: fresh saves played forward\n")
        print(campaign_section(camps))
        print("\n#### Per hero (campaign runs, all Danger levels)\n")
        print(hero_table(runs))
        wt, wins = weapon_table(runs)
        print(f"\n#### Per weapon (campaign, {len(wins)} winning runs of {len(runs)})\n")
        print(wt)
        print("\n#### Per Danger level (campaign runs: win rate, runs)\n")
        print(danger_table([(f"{s.title()} player", [r for c in camps if c['skill'] == s for r in c['runs']]) for s in ("typical", "good")]))
    if mats:
        groups = []
        for meta in ("fresh", "max"):
            for skill in ("typical", "good"):
                rs = [r for m in mats if m["meta"] == meta and m["skill"] == skill for r in m["runs"]]
                if rs:
                    groups.append((f"{skill.title()}, {'new save' if meta == 'fresh' else 'everything bought'}", rs))
        print("\n### Matrix: every hero on every Danger from a fixed save (win rate, runs)\n")
        print(danger_table(groups))
        allm = [r for _, rs in groups for r in rs]
        print("\n#### Per hero (matrix runs)\n")
        print(hero_table(allm))
        for label, rs in groups:
            if "everything" in label and "Good" in label:
                wt, wins = weapon_table(rs)
                print(f"\n#### Per weapon ({label}, {len(wins)} winning runs of {len(rs)})\n")
                print(wt)


if __name__ == "__main__":
    main()
