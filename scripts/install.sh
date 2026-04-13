#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "错误：未找到 jq，请先安装 jq 后再运行。" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

source_command="${repo_root}/scripts/statusline-command.sh"
source_tasks="${repo_root}/scripts/statusline-tasks.sh"

target_dir="${HOME}/.claude"
target_command="${target_dir}/statusline-command.sh"
target_tasks="${target_dir}/statusline-tasks.sh"
settings_file="${target_dir}/settings.json"

timestamp="$(date '+%Y%m%d-%H%M%S')"
backup_file="${settings_file}.bak-${timestamp}"
tmp_file="$(mktemp "${TMPDIR:-/tmp}/cc-statusline-install.XXXXXX")"

cleanup() {
  rm -f "${tmp_file}"
}

trap cleanup EXIT

for src in "${source_command}" "${source_tasks}"; do
  if [ ! -f "${src}" ]; then
    echo "错误：未找到源文件：${src}" >&2
    exit 1
  fi
done

mkdir -p "${target_dir}"

cp "${source_command}" "${target_command}"
cp "${source_tasks}" "${target_tasks}"
chmod +x "${target_command}" "${target_tasks}"

statusline_command="bash \"${target_command}\""
settings_action="已创建"
backup_summary="无（首次创建）"

if [ -f "${settings_file}" ]; then
  cp "${settings_file}" "${backup_file}"
  jq --arg command "${statusline_command}" \
    '. + {statusLine: {type: "command", command: $command}}' \
    "${settings_file}" > "${tmp_file}"
  settings_action="已更新"
  backup_summary="${backup_file}"
else
  jq -n --arg command "${statusline_command}" \
    '{statusLine: {type: "command", command: $command}}' \
    > "${tmp_file}"
fi

mv "${tmp_file}" "${settings_file}"

echo "安装完成"
echo "仓库根目录：${repo_root}"
echo "目标目录：${target_dir}"
echo "已复制：${target_command}"
echo "已复制：${target_tasks}"
echo "settings.json：${settings_action}"
echo "settings.json 备份：${backup_summary}"
echo "statusLine 命令：${statusline_command}"
