# 强制执行：硬性闸门如何工作

[English](../enforcement.md) · [Tiếng Việt](../vi/enforcement.md) · **简体中文**

claude-harness 相比 Codex 风格的 `AGENTS.md` 安装方式的关键，在于它的
规则是**由钩子强制执行的**，而不仅仅是写下来。三个钩子注册在
`hooks/hooks.json` 中；它们全部通过多语言的
`hooks/run-hook.cmd` 包装器运行。

每道闸门都是 **fail-open（失败时放行）**：没有数据库（项目未加入治理）、没有二进制，或一个
查询错误，都始终导致*允许*。harness 绝不能让一个仓库瘫痪。

## 1. SessionStart —— `hooks/session-start`

- 匹配器：`startup|resume|clear|compact`。
- 引导二进制 + `.harness/`，然后通过 `hookSpecificOutput.additionalContext` 注入
  `using-claude-harness` skill，使工作流在整个会话期间保持
  活跃。
- 降级：在引导失败时，它仍会注入 skill 外加一条 “ADVISORY
  mode” 提示。始终以退出码 0 退出。

## 2. PreToolUse —— `hooks/pretool-intake-gate`

把*“编辑前先分类”*变成一次阻断。

- 匹配器：`Edit|Write|MultiEdit`。
- 逻辑：如果项目已初始化（`.harness/harness.db` 存在）**且**
  `SELECT COUNT(*) FROM intake` 为 0 → **拒绝**：

  ```json
  { "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "...run /claude-harness:intake before editing code..." } }
  ```

- 豁免（始终允许）：`.harness/`、`docs/stories/` 或
  `docs/superpowers/` 之下的路径 —— 因此记录 intake 以及编写 story/spec 文档绝不会
  自我阻断。
- 它是一道**首次编辑闸门**：一条已记录的 intake 即可为本
  会话开放编辑。它不是按文件的。

## 3. Stop —— `hooks/stop-verify-gate`

把*“完成前先验证”*变成一次阻断。

- 逻辑：如果有任何 story 处于 `in_progress` 且其 `verify_command` 的
  `last_verified_result` 不是 `pass` → **阻断**结束回合：

  ```json
  { "decision": "block", "reason": "...run /claude-harness:verify (exit 0) and /claude-harness:trace..." }
  ```

- **循环安全：** 当钩子已经阻断过一次时，Claude Code 会在下一次 Stop 时设置
  `stop_hook_active: true`；此后钩子会放行，因此人类
  绝不会被困住。（Claude Code 默认还会把连续阻断上限设为 8，
  通过 `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` 覆盖。）
- 唯一越过它的办法是让 `story verify` 真正通过 —— 通过
  CLI 记录，而不是绕过去说。

## 解析说明

只有 `tool check` 和 `query tools` 会输出 JSON；因此各闸门依赖退出
码和 `query sql`。`query sql` 总是会在任何数据行之前打印一行表头
和一条虚线分隔符，所以各闸门在计数行时会跳过前两行
（`tail -n +3`）。见 `hooks/lib/harness-env`
（`he_sql_rows` / `he_sql_count`）。

## 测试

`tests/run-tests.sh` 针对真实的 `harness-cli`
二进制演练上述全部内容（intake 的 allow → deny → allow；verify 的
allow → block → loop-guard → allow；二进制缺失时的降级）。运行：`bash tests/run-tests.sh`。

## 哪些没有被强制执行（出于设计）

回合内的 agent 诚实性（例如设置一个它不该设置的证明轴）是由
skills 的约束性语言塑造的，而不是由钩子 —— 对此并没有可靠的机械
信号。各闸门强制的是两个*确有*信号的检查点：
编辑前的一条 intake 行，以及 stop 前一次通过的验证。
