#!/usr/bin/env bash
# omp bridge for the AOS dashboard: polls omp agent state (agent://<id> internal URIs,
# readable from the omp shell) and appends AOS hook-event records to live/hook-events.ndjson.
#
# Usage: AOS_REPO=... OMP_WORKDIR=... AGENTS_FILE=... omp-bridge.sh
#   AGENTS_FILE: ndjson lines "<agent-id>|<label>"
# The bridge never writes anything else; it is read-only over agent state.
set -u

AOS_REPO="${AOS_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
OMP_WORKDIR="${OMP_WORKDIR:-$PWD}"
AGENTS_FILE="${AGENTS_FILE:-$AOS_REPO/omp/agents.ndjson}"
LIVE="$AOS_REPO/live"
STATE="$AOS_REPO/omp/bridge-state"
mkdir -p "$LIVE" "$STATE"

SLOT="omporch"

MODE="${1:-loop}"
case "$MODE" in tick|loop) ;; *) echo "usage: omp-bridge.sh [tick|loop]" >&2; exit 2;; esac
# One-time orchestrator session record.
if [ ! -f "$STATE/session.emitted" ]; then
  printf '{"ts":"%s","ev":"SessionStart","sid":"%s","cwd":"task-queue","cwdp":"C:\\\\Users\\\\pscan\\\\projects\\\\task-queue","agent_type":"orchestrator","sum":"omp orchestration session"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" "$SLOT" >> "$LIVE/hook-events.ndjson"
  touch "$STATE/session.emitted"
fi

emit() { # emit <agent_id> <label> <event> <sum>
  printf '{"ts":"%s","ev":"%s","sid":"%s","agent_id":"%s","agent_type":"subagent","gid":"speckit-converge","tool":"omp-agent","sum":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" "$3" "$SLOT" "$1" "$4" >> "$LIVE/hook-events.ndjson"
}

while true; do
  if [ -f "$AGENTS_FILE" ]; then
    while IFS='|' read -r id label; do
      [ -z "$id" ] && continue
      case "$id" in \#*) continue;; esac
      out="$(cat "agent://$id" 2>/dev/null < /dev/null)" || out=""
      lines=$(printf '%s\n' "$out" | wc -l)
      prev_file="$STATE/$id.lines"
      prev=0; [ -f "$prev_file" ] && prev="$(cat "$prev_file" < /dev/null)"
      if [ ! -f "$prev_file" ]; then
        emit "$id" "$label" "SessionStart" "$label started"
        echo "$lines" > "$prev_file"
      elif [ "$lines" -gt "$prev" ]; then
        emit "$id" "$label" "PostToolUse" "$label: output +$((lines - prev)) lines"
        echo "$lines" > "$prev_file"
      fi
      status="$(head -c 120 "history://$id" 2>/dev/null < /dev/null)"
      case "$status" in
        *"(idle)"*)
          if [ ! -f "$STATE/$id.stopped" ]; then
            emit "$id" "$label" "SubagentStop" "$label finished"
            touch "$STATE/$id.stopped"
          fi
          ;;
      esac
    done < "$AGENTS_FILE"
  fi
if [ "$MODE" = "tick" ]; then return 0 2>/dev/null || exit 0; fi
sleep 5
done
