# homelab-scans

Nmap port baselines for the lab, and a script that checks each node against its baseline.

**Keep this repo private.** The baselines list every open port and service version in the lab.

## Why

Scanning from another machine shows what is actually reachable on the LAN, which is not always what the compose files or the wiki say (Docker publishes ports around ufw, and old containers get forgotten). Each baseline is the accepted state of one node. A later scan that differs is drift: either something to investigate, or a deliberate change to accept.

## Layout

```
baselines/<node>.xml   Accepted baseline per node (committed; git holds the history)
scan.sh                Scan a node and diff it against its baseline
.last/                 Most recent scan and diff per node (ignored by git)
```

Baseline files use fixed names. Git history and commit messages record when and why a baseline changed.

## Requirements

Run from `silver-2603` (WSL2 Ubuntu):

```
sudo apt install nmap ndiff
```

## Usage

```
./scan.sh pi5            # scan pi5 and compare with baselines/pi5.xml
./scan.sh all            # scan every node that has a baseline
./scan.sh pi5 --accept   # promote the last pi5 scan to the baseline
```

Exit codes: `0` matches baseline, `1` drift (or no baseline yet), `2` error.

## Workflow

1. Run `./scan.sh <node>` (or `all`).
2. Clean result: nothing to do.
3. Drift: read the diff.
   - Unexpected: investigate and fix, then scan again.
   - Expected (new service, removed port, version upgrade): `./scan.sh <node> --accept`, then commit with a message that says what changed and why.

## Notes

- Scans are full TCP (`-sV -p-`), run **without sudo** so they stay TCP connect scans, matching the existing baselines.
- `-sV` records service versions, so a routine image or package update (OpenSSH, nginx) shows up as drift. That is useful, but expect it after update days.
- Firewalla's IDS may flag a full scan as an attack. Expect an alert, or allow `silver-2603`.
- Accepted risks that will always appear: Glances (61208) on `plume` and `pi5` is published without auth.

## Coverage

| Node    | Baseline   | Notes                                   |
|---------|------------|-----------------------------------------|
| `plume` | 2026-11-07 |                                         |
| `ozone` | 2026-11-07 |                                         |
| `pi5`   | 2026-11-08 |                                         |
| `tape`  | Not yet    |                                         |
| `pi4`   | Not yet    | Discovery only (`-sn`) may be enough     |