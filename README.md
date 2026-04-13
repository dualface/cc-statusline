# cc-statusline

Claude Code statusline 扩展，显示模型、effort、最近 3 次任务时长和 caveman 标记。

## 显示格式示例

`[Opus 4.6] [effort:high] [⏱ 23s/4m18s/3m21s] [CAVEMAN:ULTRA]`

## 每个段落的含义

- 模型名：蓝色，例如 `[Opus 4.6]`。
- output_style：淡紫色，仅在非 `default` 时显示，直接使用当前会话的 `output_style` 名称。
- effort 级别：淡紫色，例如 `[effort:high]`，来自 `~/.claude/settings.json` 的 `effortLevel`。
- 最近 3 次任务时长：绿色，例如 `[⏱ 23s/4m18s/3m21s]`，左侧最新。
- 任务定义：从用户 prompt 开始，到 Claude 最终回复结束；会过滤 tool result 和系统注入消息。
- 时长单位：`<5s` 显示 `5s`，`<60s` 显示 `Ns`，`<3600s` 显示 `NmNs`，更长显示 `NhNm`。
- caveman 标记：橙色，激活时显示，例如 `[CAVEMAN:ULTRA]`。

## 安装

```bash
bash scripts/install.sh
```

安装脚本会把 `scripts/statusline-command.sh` 和 `scripts/statusline-tasks.sh` 复制到 `~/.claude/`，并用 `jq` 更新 `~/.claude/settings.json` 的 `statusLine` 字段；如果原文件已存在，会先备份为 `~/.claude/settings.json.bak-<timestamp>`。

## 卸载

```bash
bash scripts/uninstall.sh
```

卸载脚本会从 `~/.claude/settings.json` 删除 `statusLine` 字段，并删除安装到 `~/.claude/` 的两个脚本副本。

## 依赖

- macOS 自带 `bash`
- `jq`

## 文件布局

- `scripts/statusline-command.sh`：主 statusline 脚本。
- `scripts/statusline-tasks.sh`：任务时长解析器。

## 自定义

如果要改颜色或输出格式，直接编辑 `~/.claude/statusline-command.sh`。修改安装后的副本，不是仓库里的源文件。
