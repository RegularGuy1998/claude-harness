# 使用 claude-harness

[English](../USAGE.md) · [Tiếng Việt](../vi/USAGE.md) · **简体中文**

一份实用的、端到端的指南，教你如何日常驱动 harness。关于安装
见 [INSTALL.md](INSTALL.md)；关于各闸门究竟如何阻断见 [enforcement.md](enforcement.md)。

---

## 1. 心智模型

claude-harness 让仓库**治理 agent**，而不是信任它。它
强制一条工作流循环，并在两个检查点**硬性阻断**：

- **编辑代码之前** —— 该工作必须被*分类*（记录一次 intake）。
- **声明“完成”之前** —— story 的*验证必须真正通过*。

两条设计规则塑造了一切：

- **方法是全局的，状态是按项目的。** 插件（skills + 钩子 + 一个二进制
  启动器）只为你的用户安装一次。每个项目只在
  `.harness/harness.db`（SQLite）中保存自己的状态 —— 它会被自动 gitignore。
- **按项目选择加入（opt-in）。** 只有当项目拥有 `.harness/harness.db` 后它才会被治理。
  在你创建它之前（通过 `/claude-harness:intake` 或 `.harness/harness init`），各
  闸门允许一切。harness 绝不会妨碍一个不使用它的仓库。

持久化记录（intake、stories、测试矩阵、轨迹、决策）存放在数据库中，并
通过 `harness-cli` 驱动 —— 经由按项目的启动器 `.harness/harness` 调用。

---

## 2. 安装与激活

本机上的安装已经完成（用户作用域），与 `superpowers` 并存：

```
claude plugin list
# > claude-harness@claude-harness-marketplace   enabled
# > superpowers@claude-plugins-official          enabled
```

要在其他地方安装，见 [INSTALL.md](INSTALL.md)。简短版本：

```bash
claude plugin marketplace add RegularGuy1998/claude-harness   # 或一个本地路径
claude plugin install claude-harness@claude-harness-marketplace
```

### 激活是按会话进行的

钩子在**会话开始时**加载。安装之后（或编辑插件之后），
**打开一个新的 Claude Code 会话**（或 `/clear`）。在某个项目的首次会话中，
`SessionStart` 钩子会：

1. 下载匹配的 `harness-cli` 二进制，校验它的 SHA-256，并缓存到
   插件数据目录下（每台机器/每个版本一次）。
2. 在当前项目中创建 `.harness/`：`harness` 启动器（环境已预接线）+
   schema，并把 `.harness/` 追加到项目的 `.gitignore`。
3. 把 `using-claude-harness` 工作流注入到会话中。

**成功的信号：** 你的项目中出现了一个 `.harness/` 目录。如果没有出现，
见“故障排查”。

> 会话开始这一步会创建启动器和 schema，但**不会**创建数据库。数据库
> 是在你第一次记录 intake 时创建的 —— 那正是加入治理的时刻。

### 为项目的上下文做 onboard（新仓库 / 全新克隆）

一个全新项目给了 agent harness 的*方法*，但对*这个*仓库一无所知。在新项目上
**运行一次**，以捕获一个持久的、已提交的上下文包：

```
/claude-harness:onboard
```

agent 会读取清单/README/目录布局，并写入 `docs/context/PROJECT_CONTEXT.md`
（技术栈、关键路径、build/test/run 命令、约定），然后在 harness 中记录一个指针 + 内容
哈希。存储是**混合的**：可读内容是已提交的 markdown（通过 git 共享）；数据库行
（`project_context` 表）只是治理信号，好让会话开始钩子能判断上下文包何时
**缺失或过期**并提醒你。

- 在之后的会话中，钩子会说 *“read docs/context/PROJECT_CONTEXT.md”* —— 因此哪怕你
  还没加入治理，队友提交的上下文包也能为你 onboard。
- onboarding **不会**记录 intake —— 第一次代码编辑仍然要经过 intake 闸门。
- 当技术栈/路径/命令变化时，用 `/claude-harness:onboard` 刷新（钩子会把漂移的
  上下文包标记为过期）。

---

## 3. 日常循环

你通常不需要手动输入命令 —— skills 会从你的请求中自动触发（例如请求
添加或修复某些东西会在任何编辑之前触发 `harness-intake`）。下面的斜杠命令
是显式等价物，供你想自己驱动时使用。

| 你想… | 斜杠命令 | 涉及的闸门 |
|---|---|---|
| 为新项目的上下文做 onboard（技术栈、路径、命令） | `/claude-harness:onboard` | —（写入 `docs/context/`，豁免编辑闸门） |
| 开始任何变更（添加 / 修复 / 构建 / 重构） | `/claude-harness:intake "你想做的事"` | **PreToolUse** 在没有 intake 时阻断第一次编辑 |
| 把 normal/high-risk 工作变成被跟踪的 story | `/claude-harness:story US-001 "title"` | — |
| 在说“完成”前先证明它 | `/claude-harness:verify US-001` | **Stop** 在验证通过前阻止结束回合 |
| 收尾一个任务 | `/claude-harness:trace` | — |
| 审视 harness 健康度 / 反复出现的摩擦 | `/claude-harness:audit` | — |
| 诊断（二进制、数据库、schema、init 状态） | `/claude-harness:harness-status` | — |

命名带命名空间 `/claude-harness:<name>`；当不存在冲突时简写形式（`/intake`）也可用。

---

## 4. 实战示例

在一个**新会话**中，在你的项目内，你说：

> “给登录加上限流。”

逐步进行：

**1. Intake（自动）。** agent 调用 `harness-intake`，运行风险清单，看到
*auth* —— 一个硬性闸门 —— 并分配通道 **high-risk**，记录它（这也会创建数据库）：

```bash
.harness/harness init
.harness/harness intake --type change_request --summary "Add rate limiting to login" \
  --lane high-risk --flags '["auth","existing_behavior"]'
```

> 如果 agent 在这之前就尝试 `Edit`/`Write`，**PreToolUse 闸门会拒绝它**，并提示
> “no feature intake recorded… run /claude-harness:intake before editing code.”

**2. Story。** high-risk ⇒ `harness-story` 创建一个带验证命令的被跟踪 story：

```bash
.harness/harness story add --id US-001 --title "Login rate limiting" --lane high-risk \
  --verify "npm test -- rate-limit"
.harness/harness story update --id US-001 --status in_progress
```

**3. 设计与构建。** 工程被委托给 **superpowers**（已安装）：用
`brainstorming` → `writing-plans` 设计，用 `subagent-driven-development` + TDD 实现。

**4. 验证（受闸门把守）。** 在声明完成之前，`harness-verification-before-completion` 运行：

```bash
.harness/harness story verify US-001     # 运行验证命令；退出码 0 = 通过
```

> 如果 story 仍为 `in_progress` 且验证尚未通过，而你试图结束
> 回合，**Stop 闸门会阻断**它：“story US-001 … unmet verification gate.” 它只阻断一次；
> 在下一次 stop 时会放你出去（循环安全），所以你绝不会被困住。

通过后，证明 + 状态会被记录：

```bash
.harness/harness story update --id US-001 --status implemented --unit 1 --integration 1 --e2e 1 --platform 0
```

**5. Trace。** `harness-trace-and-friction` 记录发生了什么 + harness 在哪里造成了
阻碍（摩擦是必填的 —— 它正是驱动改进的东西）：

```bash
.harness/harness trace --summary "Login throttles after 5 attempts/min (429)" --story US-001 \
  --outcome completed --changed '["src/auth/rateLimit.ts"]' \
  --friction "TEST_MATRIX had no throttling row; inferred the proof shape"
```

---

## 5. 两道硬性闸门（实际会阻断什么）

两道闸门都是 **fail-open（失败时放行）**：没有数据库（项目未加入治理）、没有二进制、缺少 Git Bash，
或一个查询错误，都会导致*允许*。harness 绝不会让一个仓库瘫痪。完整细节见
[enforcement.md](enforcement.md)。

- **PreToolUse**（`Edit|Write|MultiEdit`）：如果项目已初始化且拥有**零条
  intake**，编辑被拒绝。这是一道*首次编辑*闸门 —— 一条已记录的 intake 即可为本会话
  开放编辑。`.harness/`、`docs/stories/`、`docs/superpowers/` 和
  `docs/context/` 之下的路径被豁免，因此记录 intake / 编写 story、spec、上下文包
  文档绝不会自我阻断。
- **Stop**：如果有任何 story 处于 `in_progress` 且其 `verify_command` 的上次结果不是
  `pass`，结束回合会被阻断。通过 `stop_hook_active` 保持循环安全（只阻断一次，然后
  放行）。唯一真正越过它的办法是让 `story verify` 真正通过。

---

## 6. 与 superpowers 组合

| 层 | 负责方 |
|---|---|
| 持久化状态、风险通道、intake、stories/测试矩阵、轨迹、审计、硬性闸门 | **claude-harness** |
| 工程纪律：头脑风暴、计划、subagent 驱动开发、TDD、调试、代码评审 | **superpowers** |

它们会自动衔接：`harness-intake`（high-risk）→ `superpowers:brainstorming`/`writing-plans`；
`harness-story` → `superpowers:subagent-driven-development`；任何“完成”声明 →
`harness-verification-before-completion`。claude-harness 记录*发生了什么以及是否被
证明*；superpowers 治理*代码是如何写出来的*。两者都不需要对方即可运行。

---

## 7. CLI 速查表

始终通过启动器调用（环境已预接线）。在 Windows 上，经由 Git Bash 运行。通道使用
连字符形式 `high-risk`；证明布尔值是数字 `1`/`0`（绝不用 `yes`/`no`）；trace
的 `--outcome` 取值之一为 `completed|blocked|partial|failed`。

```bash
.harness/harness query matrix         # 跨 story 的证明矩阵
.harness/harness query stats          # 概要计数
.harness/harness query traces         # 近期轨迹
.harness/harness query friction       # 带摩擦的轨迹
.harness/harness story verify-all     # 运行每个 story 的验证命令（合并前）
.harness/harness audit                # 漂移类别 + 熵分值
.harness/harness propose              # 来自摩擦/干预的改进提案
```

完整命令参考（每个标志）：见
[skills/using-claude-harness/references/cli-reference.md](../../skills/using-claude-harness/references/cli-reference.md)。

---

## 8. 故障排查 / 常见问题

**什么都没发生 / 没有出现 `.harness/`。**
你还在安装之前打开的那个会话里。钩子在会话开始时加载 —— 打开一个
新会话（或 `/clear`）。

**编辑没有被阻断。**
要么项目未加入治理（还没有 `.harness/harness.db` —— 运行 `/claude-harness:intake`），
要么 harness 处于**咨询模式（advisory）**（二进制或 Git Bash 不可用）。运行
`/claude-harness:harness-status` 查看二进制版本、schema 和 init 状态。

**Windows。** 钩子通过一个多语言包装器运行，它需要 PATH 上有 **Git for Windows**。没有
bash，插件仍会加载，但闸门会失效（它们会静默地以退出码 0 退出）。如果某个 Stop 阻断曾让你
感觉卡住，它会在一次阻断后自我释放（`stop_hook_active`）；Claude Code 默认还会把
连续 Stop 阻断上限设为 8（`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`）。

**我编辑了插件 —— 如何让改动生效？**
本地安装指向目录 `<your-local-checkout>`，所以文件编辑会在下个会话中
体现出来。如果你是从 GitHub 安装的：
```bash
claude plugin marketplace update claude-harness-marketplace
claude plugin update claude-harness@claude-harness-marketplace   # 重启以应用
```

**本地目录 vs GitHub 源。** 本机的 marketplace 指向本地目录（非常适合
开发）。GitHub 仓库（`RegularGuy1998/claude-harness`，私有）用于在其他
机器上安装 —— 那些机器需要拥有该仓库访问权限的 `gh`/git 认证。`harness-cli` 二进制由
同一个私有仓库的 GitHub Releases 构建与发布，因此首次会话的下载需要拥有访问权限的 `gh`（或
一个 `GH_TOKEN`/`GITHUB_TOKEN`）；没有它，闸门会降级为咨询模式。用
`HARNESS_CLI_RELEASE_REPO` / `HARNESS_CLI_BASE_URL` 覆盖源，或让 `HARNESS_CLI_BIN` 指向一个
本地构建。

**重置一个项目。** 删除它的 `.harness/` 目录（它已被 gitignore）。二进制缓存位于
插件数据目录下，并在各项目间共享。

**临时关闭闸门。** 为本会话禁用插件：`claude plugin disable
claude-harness@claude-harness-marketplace`（用 `enable` 重新启用）。或者干脆不让某个项目加入治理。
