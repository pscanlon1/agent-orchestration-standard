# omp bridge

Run the AOS dashboard against an [omp](https://oh-my-pi) orchestration session instead of
Claude Code. Two pieces:

- `omp-bridge.sh` — appends AOS-format records to `live/hook-events.ndjson` from omp
  agent state. omp resolves its internal `agent://`/`history://` URIs only inside the
  orchestrator's own session shell, so the bridge has two modes:
  - `./omp-bridge.sh loop` — standalone polling loop (works in any shell that resolves
    the URIs; not the common case).
  - `source omp-bridge.sh tick` — one polling pass, executed in the omp session shell
    (the orchestrator calls this once per turn). Tick mode uses `return`, never `exit`.
- `agents.ndjson` — registry lines `agent-id|label` for the subagents to poll.

Completion detection reads the first line of `history://<id>` (`(idle)` vs `(running)`).

## State the dashboard reads

- Hook events: `<AOS repo>/live/hook-events.ndjson` (this bridge appends).
- Goal/tasks/events for the GOALS panel: `~/.aos/orch/goals/<gid>/{goal.json,tasks.json,events.ndjson}`
  per [docs/orch-state-contract.md](../docs/orch-state-contract.md). The orchestrator
  writes these directly at each phase transition.

## Run

```sh
node monitor.mjs            # dashboard on http://127.0.0.1:4318
# in the omp session shell, once per turn:
source ../aos/omp/omp-bridge.sh tick
```

`omp/bridge-state/` holds poll state (never committed). Privacy matches the Claude Code
hooks: labels and output line deltas only, no prompts or file contents.
