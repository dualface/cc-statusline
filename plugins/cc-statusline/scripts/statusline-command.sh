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

# Git branch / worktree indicator
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  fi
  git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
  common_dir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
  abs_git_dir=$(cd "$cwd" && cd "$git_dir" 2>/dev/null && pwd)
  abs_common_dir=$(cd "$cwd" && cd "$common_dir" 2>/dev/null && pwd)
  if [ -n "$branch" ]; then
    if [ -n "$abs_git_dir" ] && [ -n "$abs_common_dir" ] && [ "$abs_git_dir" != "$abs_common_dir" ]; then
      wt=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
      printf ' \033[38;5;220m[wt:%s@%s]\033[0m' "$wt" "$branch"
    else
      printf ' \033[38;5;108m[%s]\033[0m' "$branch"
    fi
  fi
fi

# Task durations from transcript
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  task_durations=$(bash "${script_dir}/statusline-tasks.sh" "$transcript_path" 2>/dev/null)
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
