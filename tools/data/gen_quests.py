#!/usr/bin/env python3
"""Writes data/quests/*.json (15 daily, 15 weekly, 116 milestones), data/rules/quests.json and the
"coins" of data/challenges/*.json (phase 12, docs/BRIEF.md "Update 1", Quests).

The files are the content; this only keeps the reward budget in one place. Hand edits to
data/quests/ are fine (the game reads only the JSON), but a re-run rewrites data/quests/ from
scratch. Rewards were tuned with the quest sim (scenes/debug/quest_sim.tscn, --replay): about 35%
of a regular player's coins over 20 runs. QCFG='{"ms_mult": 0.8, ...}' overrides the budget for a
tuning replay (keys: T, ms_mult, daily.mult, weekly.mult, chests, challenge, challenge_special).

Usage:  python3 tools/data/gen_quests.py .
"""
import json, os, sys
REPO = sys.argv[1]
OUT = os.path.join(REPO, "data", "quests")
os.makedirs(OUT, exist_ok=True)
files = {}

def n(x):
    return f"{x:,}"

def q(id, kind, desc, stat, target, coins, scope="total", points=None, **extra):
    e = {"id": id, "kind": kind, "desc": desc, "stat": stat, "scope": scope, "target": target,
         "requires": extra.pop("requires", ""), "reward": {"coins": coins}, "repeat": kind != "milestone"}
    if kind == "daily":
        e["reward"]["points"] = 20 if points is None else points
    e.update(extra)
    assert id not in files, id
    files[id] = e

# Budget (tuned with scenes/debug/quest_sim.tscn): see TASKS.md phase 12.
import os as _os
CFG = json.loads(_os.environ.get("QCFG", "{}"))
T = CFG.get("T", [3, 5, 8, 12, 18, 25, 35, 50, 75, 100])
DC = CFG.get("daily", {})
WC = CFG.get("weekly", {})

# Daily pool (3 drawn at local midnight), 20 points each.
D = [
    ("kills_300", "Defeat 300 critters", "kills", 300, 5, "total"),
    ("kills_1000", "Defeat 1,000 critters", "kills", 1000, 8, "total"),
    ("kills_run_1500", "Defeat 1,500 critters in one run", "kills", 1500, 8, "run"),
    ("chests_3", "Open 3 chests", "chests_opened", 3, 5, "total"),
    ("swarm_unhurt", "Survive a swarm without a hit", "swarm_survived_no_damage", 1, 8, "total"),
    ("runs_3", "Finish 3 runs", "runs_finished", 3, 5, "total"),
    ("pots_10", "Break 10 pots", "pots_broken", 10, 5, "total"),
    ("gems_1000", "Collect 1,000 XP gems", "gems_collected", 1000, 5, "total"),
    ("elites_2", "Defeat 2 elites", "elites_killed", 2, 5, "total"),
    ("beacons_2", "Activate 2 beacons", "shrines_activated", 2, 5, "total"),
    ("level_15", "Reach level 15 in one run", "level", 15, 8, "run"),
    ("boss_summon", "Summon Mega Mole", "boss_summoned", 1, 5, "total"),
    ("challenge_win", "Win a Challenge Beacon", "challenges_won", 1, 8, "total"),
    ("merchant_2", "Buy 2 wares from the Merchant", "items_bought", 2, 5, "total"),
    ("swarms_2", "Face 2 swarms", "swarms_started", 2, 5, "total"),
]
for id, desc, stat, t, c, sc in D:
    q("daily_" + id, "daily", desc, stat, t, round(c * DC.get("mult", 1.0)), sc)

# Weekly pool (5 drawn on Monday).
W = [
    ("kills_5000", "Defeat 5,000 critters", "kills", 5000, 20, "total"),
    ("kills_15000", "Defeat 15,000 critters", "kills", 15000, 30, "total"),
    ("runs_10", "Finish 10 runs", "runs_finished", 10, 20, "total"),
    ("chests_20", "Open 20 chests", "chests_opened", 20, 20, "total"),
    ("boss_2", "Defeat Mega Mole twice", "boss_defeated", 2, 40, "total"),
    ("elites_15", "Defeat 15 elites", "elites_killed", 15, 25, "total"),
    ("pots_60", "Break 60 pots", "pots_broken", 60, 20, "total"),
    ("beacons_12", "Activate 12 beacons", "shrines_activated", 12, 20, "total"),
    ("gems_8000", "Collect 8,000 XP gems", "gems_collected", 8000, 20, "total"),
    ("portal", "Escape through the portal", "escaped", 1, 40, "total"),
    ("swarm_unhurt_3", "Survive 3 swarms without a hit", "swarm_survived_no_damage", 3, 30, "total"),
    ("level_20", "Reach level 20 in one run", "level", 20, 25, "run"),
    ("final_swarm", "Reach the Final Swarm", "final_swarm_reached", 1, 40, "total"),
    ("challenges_4", "Win 4 Challenge Beacons", "challenges_won", 4, 25, "total"),
    ("merchant_8", "Buy 8 wares from the Merchant", "items_bought", 8, 20, "total"),
]
for id, desc, stat, t, c, sc in W:
    q("weekly_" + id, "weekly", desc, stat, t, round(c * WC.get("mult", 1.0)), sc)

# Milestones: chains of tiers; tier i pays T[i + skip] x mult coins.
def chain(key, stat, targets, desc, scope="total", mult=1.0, skip=0, **extra):
    for i, t in enumerate(targets):
        c = max(1, int(round(T[min(i + skip, len(T) - 1)] * mult * CFG.get("ms_mult", 0.7))))
        q("ms_%s_%s" % (key, t), "milestone", desc(t), stat, t, c, scope, **extra)

chain("bonk", "kills", [100, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000, 250000],
      lambda t: "Bonk %s critters" % n(t))
chain("runs", "runs_finished", [1, 5, 10, 25, 50, 100, 250],
      lambda t: "Finish your first run" if t == 1 else "Finish %s runs" % n(t))
chain("chests", "chests_opened", [10, 25, 50, 100, 250, 500], lambda t: "Open %s chests" % n(t))
chain("gems", "gems_collected", [1000, 5000, 20000, 50000, 100000, 250000], lambda t: "Collect %s XP gems" % n(t))
chain("pots", "pots_broken", [25, 100, 250, 500, 1000], lambda t: "Break %s pots" % n(t))
chain("beacons", "shrines_activated", [10, 25, 100, 250], lambda t: "Activate %s beacons" % n(t))
chain("elites", "elites_killed", [25, 50, 150, 400], lambda t: "Defeat %s elites" % n(t))
chain("boss", "boss_defeated", [3, 10, 25, 50], lambda t: "Defeat Mega Mole %s times" % n(t), mult=2.0)
chain("portal", "escaped", [1, 5, 20],
      lambda t: "Escape through the portal" if t == 1 else "Escape through the portal %s times" % n(t), mult=2.0)
chain("final", "final_swarm_reached", [1, 10, 30],
      lambda t: "Reach the Final Swarm" if t == 1 else "Reach the Final Swarm %s times" % n(t), mult=2.0)
chain("merchant", "items_bought", [5, 25, 100], lambda t: "Buy %s wares from the Merchant" % n(t))
chain("challenges", "challenges_won", [5, 25, 75], lambda t: "Win %s Challenge Beacons" % n(t))
chain("unhurt", "swarm_survived_no_damage", [3, 10, 30], lambda t: "Survive %s swarms without a hit" % n(t))
chain("swarms", "swarms_started", [10, 50, 200], lambda t: "Face %s swarms" % n(t))
chain("level", "level", [10, 15, 25, 30], lambda t: "Reach level %d in one run" % t, "run")
chain("final_time", "final_swarm_seconds", [30, 90, 120, 180],
      lambda t: "Last %d:%02d in the Final Swarm" % (t // 60, t % 60), "run", mult=2.0)
chain("bonk_run", "kills", [1000, 2500, 5000], lambda t: "Bonk %s critters in one run" % n(t), "run")

weapons = {}
for f in sorted(os.listdir(os.path.join(REPO, "data", "weapons"))):
    w = json.load(open(os.path.join(REPO, "data", "weapons", f)))
    weapons[w["id"]] = w["name"]
for wid, name in weapons.items():
    chain("bonk_" + wid, "kills", [500, 5000], lambda t, name=name: "Bonk %s with %s" % (n(t), name), skip=1, weapon=wid)

heroes = {}
for f in sorted(os.listdir(os.path.join(REPO, "data", "characters"))):
    c = json.load(open(os.path.join(REPO, "data", "characters", f)))
    heroes[c["id"]] = c["name"]
short = {"gary": "Gary"}
for hid, name in heroes.items():
    nm = short.get(hid, name)
    chain("bonk_" + hid, "kills", [1000, 10000], lambda t, nm=nm: "Bonk %s as %s" % (n(t), nm), skip=1, character=hid)
    for d in range(1, 6):
        desc = "Beat Mega Mole as %s" % nm + ("" if d == 1 else " on Danger %d" % d)
        e = dict(danger=d, character=hid)
        c = max(1, int(round(T[min(d + 1, len(T) - 1)] * CFG.get("ms_mult", 0.7))))
        q("ms_beat_%s_d%d" % (hid, d), "milestone", desc, "boss_defeated", 1, c, "run", **e)

old = [f for f in os.listdir(OUT) if f.endswith(".json")]
for f in old:
    os.remove(os.path.join(OUT, f))
for id, e in files.items():
    with open(os.path.join(OUT, id + ".json"), "w") as fh:
        json.dump(e, fh, indent="\t")
        fh.write("\n")

rules = {
    "id": "quests",
    "daily_count": 3,
    "weekly_count": 5,
    "chests": [{"points": p, "coins": c} for p, c in zip((20, 40, 60), CFG.get("chests", [5, 5, 10]))],
    "icons": {
        "kills": "enemies/blob", "runs_finished": "ui/kit/play", "chests_opened": "interactables/paid_chest",
        "gems_collected": "ui/kit/gem", "pots_broken": "interactables/pot", "shrines_activated": "interactables/charge_shrine",
        "elites_killed": "ui/hud_skull", "boss_defeated": "enemies/mega_mole", "boss_summoned": "interactables/boss_altar",
        "escaped": "interactables/portal", "final_swarm_reached": "ui/alert", "final_swarm_seconds": "ui/hud_clock",
        "items_bought": "interactables/merchant", "challenges_won": "interactables/challenge_shrine",
        "swarm_survived_no_damage": "enemies/gnat", "swarms_started": "enemies/skitter", "level": "ui/star",
        "keys_found": "interactables/cage_key"
    }
}
with open(os.path.join(REPO, "data", "rules", "quests.json"), "w") as fh:
    json.dump(rules, fh, indent="\t")
    fh.write("\n")

coins = CFG.get("challenge", {"early": 5, "mid": 15, "hard": 25})
special = CFG.get("challenge_special", {"turbo_pigeon": 20, "gary": 35})
cdir = os.path.join(REPO, "data", "challenges")
for f in sorted(os.listdir(cdir)):
    p = os.path.join(cdir, f)
    e = json.load(open(p))
    e["coins"] = special.get(e["id"], coins[e["tier"]])
    with open(p, "w") as fh:
        json.dump(e, fh, indent="\t", ensure_ascii=False)
        fh.write("\n")

kinds = {}
for e in files.values():
    kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
print(kinds, "longest desc:", max((len(e["desc"]), e["desc"]) for e in files.values()))
