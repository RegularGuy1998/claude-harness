# claude-harness

[English](../../README.md) · [Tiếng Việt](../vi/README.md) · **简体中文**

一个 Claude Code **插件**，通过**硬性闸门（hard gates）**把任意仓库变成由 agent 治理的工作区。

它封装了持久化的 Rust `harness-cli`（功能受理、风险通道、story 包 + 测试矩阵、决策记录、执行轨迹、漂移审计），并提供了 Codex 风格的 `AGENTS.md` 安装方式无法做到的能力：一个在会话开始时自动加载工作流的 `SessionStart` 钩子，以及会**直接阻断**而不仅仅是提醒的 `PreToolUse` / `Stop` 钩子。

应用（app）是用户接触的东西。harness 是 agent 接触的东西。

## 它给 agent 带来什么

- **编辑前先受理（intake）** —— 在改动任何代码之前，每次变更都要先被分类（输入类型 + 风险通道）。在已初始化但尚无受理记录的项目中，`PreToolUse` 钩子会阻断第一次编辑。
- **同一时间只有一个进行中的功能** —— normal/high-risk 的工作会变成一个带测试矩阵的 story。
- **声明“完成”前先验证** —— 当某个进行中的 story 的验证命令尚未通过时，`Stop` 钩子会阻止结束当前回合。
- **带摩擦（friction）的轨迹** —— 每个任务都会记录发生了什么以及 harness 在哪里造成了阻碍，作为 `audit` 与 `propose` 的输入。

## 设计

- **方法是全局的，状态是按项目的。** 插件（skills + 钩子 + 二进制启动器）只安装一次；每个项目只携带自己的 `.harness/harness.db` + schema。不会往每个仓库里塞 42 个文件。
- **二进制按需下载。** 首次会话时，`SessionStart` 钩子会从 GitHub Releases 下载匹配的 `harness-cli`，校验它的 SHA-256，并缓存到插件数据目录下。下载缺失/失败时 → 闸门降级为咨询模式（advisory），绝不会让会话瘫痪。
- **可与 [superpowers](https://github.com/obra/superpowers) 组合使用。** claude-harness 负责持久化状态、风险治理与强制执行；superpowers 负责工程纪律（头脑风暴、计划、subagent 驱动开发、TDD、调试、代码评审）。两者都装上即可获得完整工作流；claude-harness 也能独立使用。

## 安装（Claude Code）

```
/plugin marketplace add <owner>/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

然后打开一个项目并运行 `/claude-harness:intake "<你的请求>"`，让该项目加入治理。

**Windows：** 需要 Git for Windows（钩子通过一个多语言 bash 包装器运行）。参见 `docs/INSTALL.md`。

## 用法

在项目中开启一个新会话。在新仓库（或全新克隆）上，先运行一次
`/claude-harness:onboard` 以捕获持久的上下文包（context-pack），然后用
`/claude-harness:intake` → `:story` → `:verify` → `:trace` 驱动循环。完整指南（心智模型、
实战示例、各闸门、CLI 速查表与故障排查）见
**[docs/USAGE.md](../USAGE.md)**。

## Skills

| Skill | 何时使用 |
|---|---|
| `using-claude-harness` | 每次会话自动加载；intake → work → verify → trace 循环。 |
| `harness-onboard-context` | 新仓库 / 全新克隆 / 上下文包过期：捕获持久的项目上下文包。 |
| `harness-intake` | 编辑代码前：分类输入 + 风险通道。 |
| `harness-story` | normal/high-risk 工作需要 story + 测试矩阵时。 |
| `harness-verification-before-completion` | 声明完成/已修复/已通过之前。 |
| `harness-trace-and-friction` | 任务收尾时；记录轨迹 + 摩擦。 |
| `harness-audit-and-propose` | 审视 harness 健康度 / 反复出现的摩擦时。 |

## 斜杠命令

`/claude-harness:onboard`、`:intake`、`:story`、`:verify`、`:trace`、`:audit`、`:harness-status`。

## 状态

v0.1.0。持久化 CLI（`harness-cli`）被内置在 [crates/harness-cli/](../../crates/harness-cli/)，并由本仓库自己的 GitHub Releases 构建与发布（版本固定在 `scripts/harness-cli-release-tag`）；插件会在首次会话时下载它。关于各闸门如何工作以及如何降级，参见 `docs/enforcement.md`。

`harness-cli` 派生自第三方 MIT 许可的代码；原始版权信息保留在 [crates/harness-cli/LICENSE](../../crates/harness-cli/LICENSE)。
