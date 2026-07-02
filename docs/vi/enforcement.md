# Cưỡng chế: các cổng chặn cứng hoạt động ra sao

[English](../enforcement.md) · **Tiếng Việt** · [简体中文](../zh/enforcement.md)

Điểm khác biệt của claude-harness so với một bản cài kiểu `AGENTS.md` của Codex là các quy tắc của nó được **cưỡng chế bằng hook**, không chỉ viết ra cho có. Ba hook được đăng ký trong `hooks/hooks.json`; tất cả chạy qua lớp bọc đa hệ `hooks/run-hook.cmd`.

Mọi cổng đều **fail-open**: không có database (project chưa opt-in), không có binary, hoặc lỗi truy vấn luôn dẫn tới *cho phép*. Một harness không bao giờ được làm hỏng một repo.

## 1. SessionStart — `hooks/session-start`

- Matcher: `startup|resume|clear|compact`.
- Khởi tạo (bootstrap) binary + `.harness/`, rồi inject skill `using-claude-harness` qua `hookSpecificOutput.additionalContext` để quy trình sống trong suốt phiên.
- Hạ cấp: khi bootstrap thất bại, nó vẫn inject skill kèm một ghi chú "ADVISORY mode". Luôn thoát với mã 0.

## 2. PreToolUse — `hooks/pretool-intake-gate`

Biến *"phân loại trước khi sửa"* thành một lệnh chặn.

- Matcher: `Edit|Write|MultiEdit`.
- Logic: nếu project đã khởi tạo (tồn tại `.harness/harness.db`) **và** `SELECT COUNT(*) FROM intake` bằng 0 → **deny**:

  ```json
  { "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "...run /claude-harness:intake before editing code..." } }
  ```

- Miễn trừ (luôn cho phép): các đường dẫn dưới `.harness/`, `docs/stories/`, hoặc `docs/superpowers/` — để việc ghi intake và viết tài liệu story/spec không tự chặn chính mình.
- Đây là **cổng lần-sửa-đầu-tiên**: một intake đã ghi sẽ mở quyền sửa cho cả phiên. Nó không xét theo từng file.

## 3. Stop — `hooks/stop-verify-gate`

Biến *"verify trước khi xong"* thành một lệnh chặn.

- Logic: nếu có bất kỳ story nào `in_progress` với `verify_command` mà `last_verified_result` không phải `pass` → **block** việc kết thúc lượt:

  ```json
  { "decision": "block", "reason": "...run /claude-harness:verify (exit 0) and /claude-harness:trace..." }
  ```

- **An toàn với vòng lặp:** khi hook đã chặn một lần, Claude Code đặt `stop_hook_active: true` ở lần Stop kế tiếp; lúc đó hook cho qua, nên con người không bao giờ bị kẹt. (Claude Code cũng giới hạn số lần chặn liên tiếp ở 8 theo mặc định, ghi đè qua `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`.)
- Cách duy nhất để qua là làm cho `story verify` thực sự pass — được ghi nhận qua CLI, không phải nói vòng cho xong.

## Worktree và phiên (session)

- **Các worktree Git liên kết dùng chung `.harness/` của repository chính.** Các hook phân giải một worktree liên kết về root chính (`git rev-parse --git-common-dir`), session-start chỉ ghi một launcher `.harness/harness` mỏng bên trong worktree (được ẩn qua exclude riêng của worktree), và mọi cổng cùng mọi lệnh CLI đều đọc/ghi vào DUY NHẤT một `harness.db` ở root.
- **Cổng Stop giới hạn theo phiên.** Khi một phiên được khởi động với `HARNESS_SESSION_ID=<id>` và các story của phiên đó được ghi bằng `story add --session` (hoặc bằng biến môi trường), cổng Stop chỉ chặn trên các story chưa xong của đúng phiên đó. Không có biến môi trường thì cổng vẫn giữ nguyên hành vi toàn repo như trước. Các orchestrator (ví dụ claude-team-harness) đặt biến này cho mỗi phiên worktree mà nó sinh ra. Chỉ `story add` mới dùng biến môi trường làm phương án dự phòng; `story update` chỉ đổi phiên phụ trách khi có `--session` tường minh, nên việc cập nhật story của phiên khác không bao giờ chiếm quyền sở hữu của nó.

## Ghi chú về phân tích cú pháp (parsing)

Chỉ `tool check` và `query tools` xuất JSON; do đó các cổng dựa vào mã thoát (exit code) và `query sql`. `query sql` luôn in một dòng tiêu đề và một dòng gạch ngang phân cách trước mọi dòng dữ liệu, nên các cổng bỏ qua hai dòng đầu (`tail -n +3`) khi đếm dòng. Xem `hooks/lib/harness-env` (`he_sql_rows` / `he_sql_count`).

## Kiểm thử

`tests/run-tests.sh` kiểm tra tất cả những điều trên với binary `harness-cli` thật (allow → deny → allow cho intake; allow → block → loop-guard → allow cho verify; hạ cấp khi thiếu binary). Chạy: `bash tests/run-tests.sh`.

## Điều KHÔNG được cưỡng chế (theo thiết kế)

Sự trung thực của agent bên trong một lượt (ví dụ đặt một trục bằng chứng mà lẽ ra không nên) được định hình bởi ngôn ngữ ràng buộc của các skill, chứ không phải bằng hook — không có tín hiệu cơ học đáng tin cậy nào cho việc đó. Các cổng chỉ cưỡng chế hai điểm kiểm soát *có* tín hiệu: một dòng intake trước khi sửa, và một lần xác minh pass trước khi stop.
