# Sử dụng claude-harness

[English](../USAGE.md) · **Tiếng Việt** · [简体中文](../zh/USAGE.md)

Hướng dẫn thực hành đầu-cuối để vận hành harness hằng ngày. Về cài đặt xem [INSTALL.md](INSTALL.md); về việc các cổng chặn chính xác ra sao xem [enforcement.md](enforcement.md).

---

## 1. Mô hình tư duy

claude-harness làm cho một repository **quản trị agent** thay vì tin tưởng nó. Nó cưỡng chế một vòng lặp quy trình duy nhất và **chặn cứng** tại hai điểm kiểm soát:

- **Trước khi sửa code** — công việc phải được *phân loại* (đã ghi một intake).
- **Trước khi tuyên bố "xong"** — phần *xác minh của story phải thực sự pass*.

Hai nguyên tắc thiết kế chi phối mọi thứ:

- **Phương pháp là toàn cục, trạng thái là theo từng project.** Plugin (skills + hooks + trình khởi chạy binary) được cài một lần cho user của bạn. Mỗi project chỉ giữ trạng thái riêng trong `.harness/harness.db` (SQLite) — vốn được tự động git-ignore.
- **Bật theo từng project (opt-in).** Một project chỉ được quản trị sau khi có `.harness/harness.db`. Trước khi bạn tạo nó (qua `/claude-harness:intake` hoặc `.harness/harness init`), các cổng cho phép mọi thứ. Harness không bao giờ gây vướng cho một repo không dùng nó.

Bản ghi bền (intake, các story, ma trận kiểm thử, trace, quyết định) nằm trong DB và được vận hành qua `harness-cli` — gọi thông qua trình khởi chạy theo từng project `.harness/harness`.

---

## 2. Cài đặt & kích hoạt

Việc cài đặt đã hoàn tất trên máy này (phạm vi user), cùng với `superpowers`:

```
claude plugin list
# > claude-harness@claude-harness-marketplace   enabled
# > superpowers@claude-plugins-official          enabled
```

Để cài ở nơi khác, xem [INSTALL.md](INSTALL.md). Tóm gọn:

```bash
claude plugin marketplace add RegularGuy1998/claude-harness   # hoặc một đường dẫn cục bộ
claude plugin install claude-harness@claude-harness-marketplace
```

### Kích hoạt theo từng phiên

Các hook nạp **khi một phiên bắt đầu**. Sau khi cài (hoặc sau khi sửa plugin), **mở một phiên Claude Code mới** (hoặc `/clear`). Ở phiên đầu tiên trong một project, hook `SessionStart` sẽ:

1. Tải đúng binary `harness-cli`, kiểm tra SHA-256, và cache dưới thư mục dữ liệu của plugin (một lần cho mỗi máy/phiên bản).
2. Tạo `.harness/` trong project hiện tại: trình khởi chạy `harness` (đã nối dây env) + schema, và thêm `.harness/` vào `.gitignore` của project.
3. Inject quy trình `using-claude-harness` vào phiên.

**Dấu hiệu đã chạy:** một thư mục `.harness/` xuất hiện trong project. Nếu không, xem phần Xử lý sự cố.

> Bước session-start tạo trình khởi chạy và schema nhưng **không** tạo database. DB được tạo lần đầu tiên bạn ghi một intake — đó là khoảnh khắc opt-in.

### Onboard ngữ cảnh của một project (repo mới / clone mới)

Một project mới cho agent *phương pháp* của harness nhưng không hiểu biết gì về *repo này*. Chạy **một lần** trên project mới để thu thập một context-pack bền, được commit:

```
/claude-harness:onboard
```

Agent đọc các manifest/README/bố cục rồi ghi `docs/context/PROJECT_CONTEXT.md` (stack, đường dẫn chính, lệnh build/test/run, quy ước), sau đó ghi một con trỏ + hash nội dung vào harness. Lưu trữ là **lai (hybrid)**: nội dung đọc được là file markdown đã commit (chia sẻ qua git); dòng DB (bảng `project_context`) chỉ là tín hiệu quản trị để hook session-start biết khi nào pack **thiếu hoặc đã cũ** và nhắc bạn.

- Ở các phiên sau, hook nói *"đọc docs/context/PROJECT_CONTEXT.md"* — nên pack đã commit của đồng đội sẽ onboard bạn ngay cả trước khi bạn opt-in.
- Onboarding **không ghi intake** — lần sửa code đầu tiên vẫn phải đi qua cổng intake.
- Làm mới bằng `/claude-harness:onboard` khi stack/đường dẫn/lệnh thay đổi (hook đánh dấu một pack bị trôi dạt là cũ).

---

## 3. Vòng lặp hằng ngày

Thường bạn không gõ lệnh — các skill tự kích hoạt từ những gì bạn yêu cầu (ví dụ yêu cầu thêm hoặc sửa thứ gì đó sẽ kích hoạt `harness-intake` trước mọi chỉnh sửa). Các slash command dưới đây là phiên bản tường minh nếu bạn muốn tự vận hành.

| Bạn muốn… | Slash command | Cổng liên quan |
|---|---|---|
| Onboard ngữ cảnh project mới (stack, đường dẫn, lệnh) | `/claude-harness:onboard` | — (ghi vào `docs/context/`, được miễn khỏi cổng sửa) |
| Bắt đầu một thay đổi (thêm / sửa / build / refactor) | `/claude-harness:intake "điều bạn muốn"` | **PreToolUse** chặn lần sửa đầu tiên nếu chưa có intake |
| Biến công việc bình thường/rủi ro cao thành một story được theo dõi | `/claude-harness:story US-001 "title"` | — |
| Chứng minh trước khi nói "xong" | `/claude-harness:verify US-001` | **Stop** chặn kết thúc lượt cho đến khi verify pass |
| Khép lại một tác vụ | `/claude-harness:trace` | — |
| Rà soát sức khỏe harness / friction lặp lại | `/claude-harness:audit` | — |
| Chẩn đoán (binary, DB, schema, trạng thái khởi tạo) | `/claude-harness:harness-status` | — |

Tên có namespace `/claude-harness:<name>`; dạng ngắn (`/intake`) cũng dùng được khi không trùng tên.

---

## 4. Ví dụ thực tế

Trong một **phiên mới**, bên trong project của bạn, bạn nói:

> "Add rate limiting to login."

Từng bước:

**1. Intake (tự động).** Agent gọi `harness-intake`, chạy checklist rủi ro, thấy *auth* — một cổng cứng — và gán làn **high-risk**, ghi lại (việc này cũng tạo DB):

```bash
.harness/harness init
.harness/harness intake --type change_request --summary "Add rate limiting to login" \
  --lane high-risk --flags '["auth","existing_behavior"]'
```

> Nếu agent cố `Edit`/`Write` *trước* bước này, **cổng PreToolUse từ chối** với thông báo "no feature intake recorded… run /claude-harness:intake before editing code."

**2. Story.** high-risk ⇒ `harness-story` tạo một story được theo dõi kèm lệnh xác minh:

```bash
.harness/harness story add --id US-001 --title "Login rate limiting" --lane high-risk \
  --verify "npm test -- rate-limit"
.harness/harness story update --id US-001 --status in_progress
```

**3. Thiết kế & xây dựng.** Phần kỹ thuật được ủy thác cho **superpowers** (đã cài): thiết kế với `brainstorming` → `writing-plans`, hiện thực với `subagent-driven-development` + TDD.

**4. Verify (có cổng chặn).** Trước khi tuyên bố xong, `harness-verification-before-completion` chạy:

```bash
.harness/harness story verify US-001     # chạy lệnh verify; exit 0 = pass
```

> Nếu story vẫn `in_progress` và xác minh chưa pass mà bạn cố kết thúc lượt, **cổng Stop chặn** nó: "story US-001 … unmet verification gate." Nó chặn một lần; ở lần stop kế tiếp nó cho qua (an toàn với vòng lặp) nên bạn không bao giờ bị kẹt.

Khi pass, bằng chứng + trạng thái được ghi lại:

```bash
.harness/harness story update --id US-001 --status implemented --unit 1 --integration 1 --e2e 1 --platform 0
```

**5. Trace.** `harness-trace-and-friction` ghi lại điều đã xảy ra + chỗ harness gây vướng (friction là bắt buộc — đó là thứ thúc đẩy cải tiến):

```bash
.harness/harness trace --summary "Login throttles after 5 attempts/min (429)" --story US-001 \
  --outcome completed --changed '["src/auth/rateLimit.ts"]' \
  --friction "TEST_MATRIX had no throttling row; inferred the proof shape"
```

---

## 5. Hai cổng chặn cứng (thứ thực sự chặn)

Cả hai cổng đều **fail-open**: không có DB (project chưa opt-in), không có binary, thiếu Git Bash, hoặc lỗi truy vấn đều dẫn tới *cho phép*. Harness không bao giờ làm hỏng một repo. Chi tiết đầy đủ ở [enforcement.md](enforcement.md).

- **PreToolUse** (`Edit|Write|MultiEdit`): nếu project đã khởi tạo và có **0 intake**, lần sửa bị từ chối. Đây là cổng *lần-sửa-đầu-tiên* — một intake đã ghi sẽ mở quyền sửa cho cả phiên. Các đường dẫn dưới `.harness/`, `docs/stories/`, `docs/superpowers/`, và `docs/context/` được miễn để việc ghi intake / viết tài liệu story, spec, và context-pack không tự chặn chính mình.
- **Stop**: nếu có bất kỳ story nào `in_progress` với `verify_command` mà kết quả gần nhất không phải `pass`, việc kết thúc lượt bị chặn. An toàn với vòng lặp nhờ `stop_hook_active` (chặn một lần, rồi cho qua). Cách duy nhất để qua thực sự là làm cho `story verify` thực sự pass.

---

## 6. Phối hợp với superpowers

| Lớp | Chủ sở hữu |
|---|---|
| Trạng thái bền, làn rủi ro, intake, story/ma-trận-kiểm-thử, trace, audit, các cổng chặn cứng | **claude-harness** |
| Kỷ luật kỹ thuật: brainstorming, kế hoạch, phát triển bằng subagent, TDD, gỡ lỗi, review code | **superpowers** |

Chúng nối nhau tự động: `harness-intake` (high-risk) → `superpowers:brainstorming`/`writing-plans`; `harness-story` → `superpowers:subagent-driven-development`; bất kỳ tuyên bố "xong" nào → `harness-verification-before-completion`. claude-harness ghi *điều đã xảy ra và liệu nó đã được chứng minh*; superpowers quản trị *cách code được viết ra*. Không bên nào bắt buộc bên kia mới chạy được.

---

## 7. Cheat-sheet CLI

Luôn gọi qua trình khởi chạy (env đã nối dây sẵn). Trên Windows, chạy qua Git Bash. Các làn dùng dạng có gạch nối `high-risk`; các boolean bằng chứng là số `1`/`0` (không bao giờ `yes`/`no`); `--outcome` của trace là một trong `completed|blocked|partial|failed`.

```bash
.harness/harness query matrix         # ma trận bằng chứng trên các story
.harness/harness query stats          # số liệu tổng hợp
.harness/harness query traces         # các trace gần đây
.harness/harness query friction       # các trace có mang friction
.harness/harness story verify-all     # chạy lệnh verify của mọi story (trước khi merge)
.harness/harness audit                # các nhóm trôi dạt + điểm entropy
.harness/harness propose              # các đề xuất cải tiến từ friction/can thiệp
```

Tham chiếu lệnh đầy đủ (từng flag): xem [skills/using-claude-harness/references/cli-reference.md](../../skills/using-claude-harness/references/cli-reference.md).

---

## 8. Xử lý sự cố / FAQ

**Không có gì xảy ra / không thấy `.harness/` xuất hiện.**
Bạn vẫn đang ở phiên đã mở từ trước khi cài. Các hook nạp lúc phiên bắt đầu — mở một phiên mới (hoặc `/clear`).

**Các chỉnh sửa không bị chặn.**
Hoặc project chưa opt-in (chưa có `.harness/harness.db` — chạy `/claude-harness:intake`), hoặc harness đang ở **chế độ tư vấn (advisory)** (thiếu binary hoặc Git Bash). Chạy `/claude-harness:harness-status` để xem phiên bản binary, schema, và trạng thái khởi tạo.

**Windows.** Các hook chạy qua một lớp bọc đa hệ cần **Git for Windows** trên PATH. Không có bash, plugin vẫn nạp được nhưng các cổng vô hiệu (im lặng thoát mã 0). Nếu một Stop block có vẻ bị kẹt, nó tự giải phóng sau một lần chặn (`stop_hook_active`); Claude Code cũng giới hạn số lần Stop chặn liên tiếp ở 8 (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`).

**Tôi đã sửa plugin — làm sao để áp dụng thay đổi?**
Bản cài cục bộ trỏ vào thư mục `<your-local-checkout>`, nên các chỉnh sửa file được phản ánh ở phiên kế tiếp. Nếu bạn cài từ GitHub thay vào đó:
```bash
claude plugin marketplace update claude-harness-marketplace
claude plugin update claude-harness@claude-harness-marketplace   # khởi động lại để áp dụng
```

**Thư mục cục bộ so với nguồn GitHub.** Marketplace của máy này trỏ vào thư mục cục bộ (rất hợp cho phát triển). Repo GitHub (`RegularGuy1998/claude-harness`, public) dùng để cài trên máy khác. Binary `harness-cli` được build và phát hành từ GitHub Releases của repo này; vì repo là public nên việc tải ở phiên đầu chạy ẩn danh — không cần xác thực. Nếu có sẵn `gh` hoặc `GH_TOKEN`/`GITHUB_TOKEN` thì vẫn được dùng tự động (tiện để tránh giới hạn API rate limit). Ghi đè nguồn bằng `HARNESS_CLI_RELEASE_REPO` / `HARNESS_CLI_BASE_URL`, hoặc trỏ `HARNESS_CLI_BIN` vào một bản build cục bộ.

**Reset một project.** Xóa thư mục `.harness/` của nó (đã git-ignore). Cache binary nằm dưới thư mục dữ liệu của plugin và được chia sẻ giữa các project.

**Tắt tạm các cổng.** Vô hiệu hóa plugin cho một phiên: `claude plugin disable claude-harness@claude-harness-marketplace` (bật lại bằng `enable`). Hoặc đơn giản là đừng opt-in project đó.
