#!/bin/bash
# statusline-tasks.sh
# Parse Claude Code transcript JSONL to compute last 3 completed task durations.
# Usage: statusline-tasks.sh <transcript_path>
# Output: e.g. [⏱ 10m/2m/45s]
#
# A "task" is one user-prompt-to-completion cycle:
#   start = timestamp of a "user" type message
#   end   = timestamp of the last "assistant" type message before the next user message
#
# Actual Claude Code transcript schema (verified from ~/.claude/projects/*/*.jsonl):
#   Top-level field for role: .type  ("user" | "assistant" | "file-history-snapshot" | ...)
#   Top-level field for time: .timestamp  (ISO 8601 string, e.g. "2026-04-01T11:38:55.447Z")
#
# Strategy: read only the last 500 lines for performance (recent tasks are at the end).

TRANSCRIPT="$1"
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Convert an ISO 8601 timestamp string to Unix epoch seconds (integer).
# Uses macOS `date -j -f` format.  Strip sub-seconds and Z/+offset first.
iso_to_epoch() {
  local ts="$1"
  # Strip fractional seconds and timezone designator, keep YYYY-MM-DDTHH:MM:SS
  local bare
  bare=$(echo "$ts" | sed 's/\.[0-9]*//; s/Z$//; s/+[0-9:]*$//')
  date -j -f "%Y-%m-%dT%H:%M:%S" "$bare" "+%s" 2>/dev/null
}

# Read last 500 lines, extract lines where .type is "user" or "assistant".
# Emit: "H <epoch_secs>" for user messages, "A <epoch_secs>" for assistant messages.
durations=$(tail -n 500 "$TRANSCRIPT" 2>/dev/null \
  | jq -r --raw-input '
      . as $raw
      | try fromjson catch null
      | select(. != null and type == "object")
      | select(
          (.type == "assistant")
          or (
            .type == "user"
            and ((.message.content | type) == "string")
            and (
              .message.content | (
                startswith("<task-notification>") or
                startswith("<local-command-") or
                startswith("<system-reminder>") or
                startswith("<command-")
              ) | not
            )
          )
        )
      | select(.timestamp != null)
      | [ (.type | if . == "user" then "H" else "A" end), .timestamp ]
      | join(" ")
    ' 2>/dev/null)

if [ -z "$durations" ]; then
  exit 0
fi

# Now parse the H/A timestamp stream to compute task durations.
# A task starts at H and ends at the last A before the next H (or end of stream).
# We collect completed tasks only (i.e. a subsequent H or end of stream confirms completion).
# Timestamps are ISO 8601 strings; convert each to epoch seconds via iso_to_epoch().

format_duration() {
  local secs="$1"
  # Minimum 5 seconds
  if [ "$secs" -lt 5 ]; then secs=5; fi
  if [ "$secs" -ge 3600 ]; then
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    if [ "$m" -gt 0 ]; then
      printf "%dh%dm" "$h" "$m"
    else
      printf "%dh" "$h"
    fi
  elif [ "$secs" -ge 60 ]; then
    local m=$(( secs / 60 ))
    local s=$(( secs % 60 ))
    if [ "$s" -gt 0 ]; then
      printf "%dm%ds" "$m" "$s"
    else
      printf "%dm" "$m"
    fi
  else
    printf "%ds" "$secs"
  fi
}

# First convert all ISO timestamps in the stream to epoch seconds.
# Input lines: "H 2026-04-01T11:38:55.447Z" or "A 2026-04-01T11:39:00.486Z"
# Output lines: "H 1743508735" or "A 1743508740"
epoch_stream=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  role=$(echo "$line" | awk '{print $1}')
  iso=$(echo "$line" | awk '{print $2}')
  epoch=$(iso_to_epoch "$iso")
  [ -z "$epoch" ] && continue
  epoch_stream="${epoch_stream}${role} ${epoch}"$'\n'
done <<< "$durations"

if [ -z "$epoch_stream" ]; then
  exit 0
fi

# Parse the epoch stream using awk, emitting one line per completed task: "start_epoch end_epoch"
task_pairs=$(echo "$epoch_stream" | awk '
BEGIN { state="idle"; start_ts=0; last_a_ts=0 }
{
  role=$1; ts=$2
  if (role == "H") {
    # If we were in a task and saw at least one assistant reply, emit it as completed
    if (state == "in_task" && last_a_ts > 0) {
      print start_ts " " last_a_ts
    }
    # Start new task
    state = "in_task"
    start_ts = ts
    last_a_ts = 0
  } else if (role == "A") {
    if (state == "in_task") {
      last_a_ts = ts
    }
  }
}
END {
  # Do NOT emit in-progress task (no subsequent H confirms it is done)
}
')

if [ -z "$task_pairs" ]; then
  exit 0
fi

# Collect last 3 completed tasks, newest first
last3=$(echo "$task_pairs" | tail -n 3 | tac)

parts=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  start_ts=$(echo "$line" | awk '{print $1}')
  end_ts=$(echo "$line" | awk '{print $2}')
  # Integer epoch seconds — simple arithmetic
  secs=$(( end_ts - start_ts ))
  [ "$secs" -lt 0 ] && secs=0
  parts+=( "$(format_duration "$secs")" )
done <<< "$last3"

if [ ${#parts[@]} -eq 0 ]; then
  exit 0
fi

# Join with /
joined=$(IFS='/'; echo "${parts[*]}")
printf '[⏱ %s]' "$joined"
