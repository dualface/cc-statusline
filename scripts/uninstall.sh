#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "错误：未找到 jq，请先安装 jq 后再运行。" >&2
  exit 1
fi

target_dir="${HOME}/.claude"
target_command="${target_dir}/statusline-command.sh"
target_tasks="${target_dir}/statusline-tasks.sh"
settings_file="${target_dir}/settings.json"

timestamp="$(date '+%Y%m%d-%H%M%S')"
backup_file="${settings_file}.bak-${timestamp}"
tmp_file="$(mktemp "${TMPDIR:-/tmp}/cc-statusline-uninstall.XXXXXX")"

cleanup() {
  rm -f "${tmp_file}"
}

trap cleanup EXIT

settings_summary="未找到 settings.json，跳过"
backup_summary="无"

if [ -f "${settings_file}" ]; then
  cp "${settings_file}" "${backup_file}"

  if jq -e 'has("statusLine")' "${settings_file}" >/dev/null 2>&1; then
    settings_summary="已删除 statusLine"
  else
    settings_summary="statusLine 原本不存在，已保持不变"
  fi

  jq 'del(.statusLine)' "${settings_file}" > "${tmp_file}"
  mv "${tmp_file}" "${settings_file}"
  backup_summary="${backup_file}"
fi

command_summary="未找到"
tasks_summary="未找到"

if [ -f "${target_command}" ]; then
  command_summary="已删除"
fi

if [ -f "${target_tasks}" ]; then
  tasks_summary="已删除"
fi

rm -f "${target_command}" "${target_tasks}"

echo "卸载完成"
echo "目标目录：${target_dir}"
echo "settings.json：${settings_summary}"
echo "settings.json 备份：${backup_summary}"
echo "statusline-command.sh：${command_summary}"
echo "statusline-tasks.sh：${tasks_summary}"
