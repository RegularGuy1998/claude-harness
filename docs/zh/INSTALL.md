# 安装 claude-harness

[English](../INSTALL.md) · [Tiếng Việt](../vi/INSTALL.md) · **简体中文**

## 要求

- **Claude Code v2.1+**（钩子：`permissionDecision`、Stop 的 `decision`、`${CLAUDE_PLUGIN_DATA}`）。
- **curl**（用于下载 CLI 二进制）以及一个 SHA-256 工具（`sha256sum`/`shasum`/`certutil`）。
- **Windows：** **Git for Windows** —— 钩子通过一个多语言的 `run-hook.cmd` 运行，它会定位 `bash.exe`。没有 bash，插件仍能加载，但闸门会失效（它会静默地以退出码 0 退出）。

## 安装（Claude Code）

```
/plugin marketplace add <owner>/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

或者，用于本地开发时，让 marketplace 指向一个本地检出：

```
/plugin marketplace add /path/to/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

重启会话（或运行 `/clear`），以便 `SessionStart` 钩子触发。

## 首次会话时会发生什么

`SessionStart` 钩子会运行 `scripts/bootstrap-binary`，它会：

1. 检测平台并从固定的 GitHub release（`scripts/harness-cli-release-tag`）下载匹配的 `harness-cli` 资产，校验它的 `.sha256`，并缓存到
   `${CLAUDE_PLUGIN_DATA}/claude-harness/bin/<tag>/harness-cli[.exe]`。
2. 在 `<project>/.harness/` 中物化 schema 与一个启动器（`.harness/harness`），后者已接线到那个二进制，并把 `.harness/` 追加到项目的 `.gitignore`。
3. 把 `using-claude-harness` skill 注入到会话中。

如果任何一步失败（离线、不受支持的平台、只读项目），会话仍会启动，并且闸门会**降级为咨询模式（advisory）** —— 什么都不会被阻断。

## 让一个项目加入治理

只有当项目拥有 `.harness/harness.db` 时它才会被治理。通过运行以下命令创建它：

```
/claude-harness:intake "<你想做的事>"
```

（或 `.harness/harness init`）。在此之前，闸门允许一切。

## 环境变量覆盖

| 变量 | 作用 |
|---|---|
| `HARNESS_CLI_RELEASE_TAG` | 使用不同的 release 标签（或 `latest`）。 |
| `HARNESS_CLI_BASE_URL` | 从镜像 / 离线位置下载。 |
| `HARNESS_CLI_BIN` | 使用指定的二进制（跳过下载）。 |
| `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` | 在 Claude Code 强制放行前，连续 Stop 阻断的最大次数（默认 8）。 |

## 卸载

```
/plugin uninstall claude-harness@claude-harness-marketplace
```

按项目的状态保存在 `.harness/`（已 gitignore）；删除它即可彻底重置一个项目。缓存的二进制位于插件数据目录下。

## 与 superpowers 组合（推荐）

将 [superpowers](https://github.com/obra/superpowers) 一并安装。claude-harness 把工程执行（头脑风暴、计划、subagent 驱动开发、TDD、调试、代码评审）交给它；claude-harness 自身负责持久化状态、风险通道与硬性闸门。两者都不需要对方即可运行。
