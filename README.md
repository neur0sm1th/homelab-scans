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
- Drift is decided on **open ports only**. `-sV` version guesses for unrecognized services vary between runs (for example, Apprise on `pi5` showed up as blank once and `nginx` the next), so version differences are reported as a note, with the full `ndiff` in `.last/<node>.diff`. Accept a new baseline after updates if you want the version details current.
- Firewalla's IDS may flag a full scan as an attack. Expect an alert, or allow `silver-2603`.
- Accepted risks that will always appear: Glances (61208) is published without auth on `plume`, `ozone`, and `pi5`.

## Coverage

| Node    | Baseline   | Notes                                                                   |
|---------|------------|-------------------------------------------------------------------------|
| `plume` | 2026-11-07 | Glances (61208) open without auth, accepted                             |
| `ozone` | 2026-11-07 | Frigate go2rtc/RTSP/WebRTC ports (1984, 8554, 8555) kept as-is          |
| `pi5`   | 2026-11-08 | Homepage 3000 kept (NPM forwards to it); Glances without auth, accepted |
| `tape`  | 2026-11-08 | ABB stopped; NFS, Drive, UPS server, WSD, and SAN Manager left on       |
| `pi4`   | 2026-11-08 | SSH only                                                                |
