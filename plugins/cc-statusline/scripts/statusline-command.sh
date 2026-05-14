#!/bin/bash
# Claude Code statusline script
# Displays: model | effort | output_style | context% | rate limits | git branch/worktree | task durations | caveman badge

input=$(cat)

# Model: 单字母缩写 (O/S/H), 去版本号与 "(1M context)"
model=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model" ]; then
  compact=$(
    echo "$model" | sed \
      -e 's/Claude //' \
      -e 's/claude //' \
      -e 's/Sonnet/S/' \
      -e 's/Haiku/H/' \
      -e 's/Opus/O/' \
      -e 's/[0-9]\.[0-9]//' \
      -e 's/ (1M context)//' \
      -e 's/ //'
  )
  printf '\033[38;5;75m%s\033[0m' "$compact"
fi

# Effort: 单字母标签 (MAX/XH/H/M/L)
settings_file="$HOME/.claude/settings.json"
effort=""
if [ -f "$settings_file" ]; then
  effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
fi
if [ -n "$effort" ]; then
  case "$effort" in
    max)    effort_label="MAX" ;;
    xhigh)  effort_label="XH"  ;;
    high)   effort_label="H"   ;;
    medium) effort_label="M"   ;;
    low)    effort_label="L"   ;;
    *)      effort_label="$effort" ;;
  esac
  printf ' \033[38;5;179m%s\033[0m' "$effort_label"
fi

# output_style: 非 default 时显示
style=$(echo "$input" | jq -r '.output_style.name // empty')
if [ -n "$style" ] && [ "$style" != "default" ] && [ "$style" != "null" ]; then
  printf ' \033[38;5;183m[%s]\033[0m' "$style"
fi

# Usage helpers: 按百分比上色 (绿 <50, 黄 50-80, 红 ≥80)
usage_color() {
  local pct="$1"
  local int_pct
  int_pct=$(printf '%.0f' "$pct" 2>/dev/null)
  if [ "$int_pct" -ge 80 ] 2>/dev/null; then
    printf '\033[38;5;203m'
  elif [ "$int_pct" -ge 50 ] 2>/dev/null; then
    printf '\033[38;5;221m'
  else
    printf '\033[38;5;114m'
  fi
}

# 剩余时间格式化: Unix 时间戳 → 45m / 3h / 5d
fmt_remaining() {
  local ts="$1"
  local now delta
  now=$(date +%s)
  delta=$((ts - now))
  if [ "$delta" -le 0 ]; then
    printf '0'
  elif [ "$delta" -lt 3600 ]; then
    printf '%dm' $((delta / 60))
  elif [ "$delta" -lt 86400 ]; then
    printf '%dh' $((delta / 3600))
  else
    printf '%dd' $((delta / 86400))
  fi
}

# Usage: 上下文窗口 + 5h/7d rate limits
usage_parts=""

ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx_used" ]; then
  col=$(usage_color "$ctx_used")
  usage_parts="${usage_parts}${col}$(printf '%.0f' "$ctx_used")%\033[0m"
fi

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
if [ -n "$five_pct" ]; then
  col=$(usage_color "$five_pct")
  [ -n "$usage_parts" ] && usage_parts="${usage_parts} "
  usage_parts="${usage_parts}${col}$(printf '%.0f' "$five_pct")%\033[0m"
  if [ -n "$five_reset" ]; then
    usage_parts="${usage_parts}\033[38;5;244m/$(fmt_remaining "$five_reset")\033[0m"
  fi
fi

week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
if [ -n "$week_pct" ]; then
  col=$(usage_color "$week_pct")
  [ -n "$usage_parts" ] && usage_parts="${usage_parts} "
  usage_parts="${usage_parts}${col}$(printf '%.0f' "$week_pct")%\033[0m"
  if [ -n "$week_reset" ]; then
    usage_parts="${usage_parts}\033[38;5;244m/$(fmt_remaining "$week_reset")\033[0m"
  fi
fi

if [ -n "$usage_parts" ]; then
  printf ' '
  printf "%b" "$usage_parts"
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

# Caveman badge
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
