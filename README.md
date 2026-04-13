# cc-statusline

Claude Code statusline 扩展，以 Claude Code Plugin 形式分发。显示模型、effort、最近 3 次任务时长和 caveman 标记。

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

本仓库既是 plugin，又自带一个单插件 marketplace（`.claude-plugin/marketplace.json`）。
`claude plugin install` 必须通过 marketplace 走，不能直接指向 plugin 目录。

### 方式 1：从 GitHub 仓库安装（推荐）

在 Claude Code 会话内：

```shell
/plugin marketplace add dualface/cc-statusline
/plugin install cc-statusline@cc-statusline
```

或用 CLI：

```bash
claude plugin marketplace add dualface/cc-statusline
claude plugin install cc-statusline@cc-statusline
```

### 方式 2：从本地目录安装（开发调试）

```bash
claude plugin marketplace add /Users/dualface/Desktop/Works/cc-statusline
claude plugin install cc-statusline@cc-statusline
```

### 启用后生效的配置

插件级 `settings.json` 会把下列配置注入会话：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/statusline-command.sh",
    "padding": 0
  }
}
```

无需手工编辑 `~/.claude/settings.json`。

## 卸载

```shell
/plugin uninstall cc-statusline@cc-statusline
/plugin marketplace remove cc-statusline
```

## 更新

```shell
/plugin marketplace update cc-statusline
```

## 依赖

- macOS 自带 `bash`
- `jq`

## 文件布局

- `.claude-plugin/marketplace.json`：单插件 marketplace 目录，让仓库可被 `/plugin marketplace add` 识别。
- `plugins/cc-statusline/.claude-plugin/plugin.json`：插件 manifest。
- `plugins/cc-statusline/settings.json`：插件级设置，注入 `statusLine` 配置。
- `plugins/cc-statusline/scripts/statusline-command.sh`：主 statusline 脚本。
- `plugins/cc-statusline/scripts/statusline-tasks.sh`：任务时长解析器。

## 自定义

改颜色或输出格式，直接编辑仓库内 `plugins/cc-statusline/scripts/statusline-command.sh`，下次插件加载生效。无需复制到 `~/.claude/`。
