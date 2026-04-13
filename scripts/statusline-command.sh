#!/bin/bash
# Claude Code statusline script
# Displays: model name | effort level | task durations | caveman badge

input=$(cat)

# Extract model display name and shorten it
model=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model" ]; then
  # Compact model name: strip "Claude " prefix, shorten known names
  compact=$(echo "$model" | sed \
    -e 's/Claude //' \
    -e 's/claude //' \
    -e 's/ Sonnet/ Snnt/' \
    -e 's/ Haiku/ Hku/' \
    -e 's/ Opus/ Ops/')
  printf '\033[38;5;75m[%s]\033[0m' "$compact"
fi

# Extract effort level from settings (passed via env or read from settings.json)
effort=$(echo "$input" | jq -r '.output_style.name // empty')
if [ -n "$effort" ] && [ "$effort" != "default" ] && [ "$effort" != "null" ]; then
  printf ' \033[38;5;183m[%s]\033[0m' "$effort"
fi

# Also show effortLevel from settings.json if available
settings_effort=""
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
  settings_effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
fi
if [ -n "$settings_effort" ]; then
  printf ' \033[38;5;183m[effort:%s]\033[0m' "$settings_effort"
fi

# Task durations from transcript
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  task_durations=$(bash /Users/dualface/.claude/statusline-tasks.sh "$transcript_path" 2>/dev/null)
  if [ -n "$task_durations" ]; then
    printf ' \033[38;5;114m%s\033[0m' "$task_durations"
  fi
fi

# Caveman badge (preserve existing functionality)
FLAG="$HOME/.claude/.caveman-active"
if [ -f "$FLAG" ]; then
  MODE=$(cat "$FLAG" 2>/dev/null)
  if [ "$MODE" = "full" ] || [ -z "$MODE" ]; then
    printf ' \033[38;5;172m[CAVEMAN]\033[0m'
  else
    SUFFIX=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
    printf ' \033[38;5;172m[CAVEMAN:%s]\033[0m' "$SUFFIX"
  fi
fi
