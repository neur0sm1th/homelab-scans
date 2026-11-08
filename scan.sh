#!/usr/bin/env bash
# scan.sh: compare a lab node's open TCP ports against its committed Nmap baseline.
#
#   ./scan.sh <node>            Scan <node> and diff against baselines/<node>.xml
#   ./scan.sh <node> --accept   Promote the last scan of <node> to its baseline
#   ./scan.sh all               Scan every node that has a baseline
#
# Exit codes: 0 = matches baseline, 1 = drift found (or no baseline yet), 2 = error

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$REPO_DIR/baselines"
LAST_DIR="$REPO_DIR/.last"

usage() {
  sed -n '4,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,3\}//'
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' not found (sudo apt install $2)" >&2
    exit 2
  }
}

scan_node() {
  local node="$1"
  local base="$BASE_DIR/$node.xml"
  local last="$LAST_DIR/$node.xml"
  local diff="$LAST_DIR/$node.diff"

  mkdir -p "$LAST_DIR"
  echo "== $node: scanning all TCP ports (a few minutes)..."

  # Run without sudo on purpose: the baselines are TCP connect scans,
  # and a SYN scan (root) can report slightly differently.
  if ! nmap -sV -p- -oX "$last" "$node" >/dev/null; then
    echo "error: nmap failed for $node" >&2
    return 2
  fi

  if [[ ! -f "$base" ]]; then
    echo "== $node: no baseline yet."
    echo "   Review $last, then run: ./scan.sh $node --accept"
    return 1
  fi

  # Full ndiff (ports and service versions), kept for reference.
  local nd_rc=0
  ndiff "$base" "$last" > "$diff" || nd_rc=$?
  if (( nd_rc > 1 )); then
    echo "error: ndiff failed for $node" >&2
    return 2
  fi

  # Drift is decided on open ports only. -sV version guesses for
  # unrecognized services vary between runs, so they are reported
  # as information, not drift.
  local port_diff
  port_diff="$(diff <(open_ports "$base") <(open_ports "$last") | grep '^[<>]' || true)"

  if [[ -n "$port_diff" ]]; then
    echo "== $node: DRIFT from baseline (open ports changed)"
    echo "$port_diff" | sed 's/^< /   closed: /; s/^> /   opened: /'
    echo "== Full diff: $diff"
    echo "== If this is expected: ./scan.sh $node --accept, then commit."
    return 1
  fi

  echo "== $node: matches baseline"
  if (( nd_rc == 1 )); then
    echo "   (service version details differ; see $diff)"
  fi
  return 0
}

# Print one "port/proto" line per open port in an Nmap XML file, sorted.
open_ports() {
  python3 - "$1" <<'PY' | sort -t/ -k1,1n
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
for port in root.iter("port"):
    state = port.find("state")
    if state is not None and state.get("state") == "open":
        print(f"{port.get('portid')}/{port.get('protocol')}")
PY
}

accept_node() {
  local node="$1"
  local last="$LAST_DIR/$node.xml"

  if [[ ! -f "$last" ]]; then
    echo "error: no scan of $node to accept. Run ./scan.sh $node first." >&2
    exit 2
  fi

  mkdir -p "$BASE_DIR"
  cp "$last" "$BASE_DIR/$node.xml"
  echo "== $node: baseline updated. Commit it, for example:"
  echo "   git add baselines/$node.xml && git commit -m \"$node: <what changed and why>\""
}

main() {
  if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
  fi

  need nmap nmap
  need ndiff ndiff
  need python3 python3

  local target="$1"
  local mode="${2:-}"

  if [[ "$mode" == "--accept" ]]; then
    accept_node "$target"
    exit 0
  elif [[ -n "$mode" ]]; then
    echo "error: unknown option '$mode'" >&2
    usage
    exit 2
  fi

  if [[ "$target" == "all" ]]; then
    local worst=0 rc node
    shopt -s nullglob
    local files=("$BASE_DIR"/*.xml)
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "error: no baselines found in $BASE_DIR" >&2
      exit 2
    fi
    for f in "${files[@]}"; do
      node="$(basename "$f" .xml)"
      rc=0
      scan_node "$node" || rc=$?
      (( rc > worst )) && worst=$rc
      echo
    done
    exit $worst
  fi

  local rc=0
  scan_node "$target" || rc=$?
  exit $rc
}

main "$@"
