#!/bin/bash
# SessionStart 钩子：把 cc-statusline 插件的 statusLine 配置写入 ~/.claude/settings.json。
# 插件级 settings.json 目前只支持 agent 字段（见 Claude Code 文档），所以用钩子注入。
# 每次 session 启动刷新一次 command，使得插件更新后 cache 路径变化也能自动跟进。
set -e

if ! command -v jq >/dev/null 2>&1; then
  echo "cc-statusline: 未安装 jq，跳过 statusLine 注入" >&2
  exit 0
fi

if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  echo "cc-statusline: CLAUDE_PLUGIN_ROOT 未设置，跳过" >&2
  exit 0
fi

settings="${HOME}/.claude/settings.json"
mkdir -p "$(dirname "${settings}")"
[ -f "${settings}" ] || echo '{}' > "${settings}"

desired_cmd="bash ${CLAUDE_PLUGIN_ROOT}/scripts/statusline-command.sh"

current_cmd=$(jq -r '.statusLine.command // empty' "${settings}" 2>/dev/null || true)
if [ "${current_cmd}" = "${desired_cmd}" ]; then
  exit 0
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/cc-statusline.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT

jq --arg cmd "${desired_cmd}" \
  '.statusLine = {type: "command", command: $cmd, padding: 0}' \
  "${settings}" > "${tmp}"

mv "${tmp}" "${settings}"
trap - EXIT
