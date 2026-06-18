# claude-harness

[English](../../README.md) · **Tiếng Việt** · [简体中文](../zh/README.md)

Một **plugin** cho Claude Code, biến mọi repository thành không gian làm việc do agent quản trị với **các cổng chặn cứng (hard gates)**.

Nó bọc quanh `harness-cli` viết bằng Rust (feature intake — tiếp nhận yêu cầu, risk lanes — phân làn rủi ro, story packet + ma trận kiểm thử, bản ghi quyết định, trace thực thi, kiểm toán trôi dạt) và bổ sung thứ mà một bản cài kiểu `AGENTS.md` của Codex không làm được: một hook `SessionStart` tự nạp quy trình, cùng các hook `PreToolUse` / `Stop` **chặn thẳng** thay vì chỉ cảnh báo.

App là thứ người dùng chạm vào. Harness là thứ agent chạm vào.

## Plugin mang lại gì cho agent

- **Tiếp nhận trước khi sửa (intake before edits)** — mọi thay đổi đều được phân loại (loại đầu vào + làn rủi ro) trước khi đụng vào bất kỳ dòng code nào. Một hook `PreToolUse` sẽ chặn lần sửa đầu tiên trong một project đã khởi tạo mà chưa có intake.
- **Một feature đang hoạt động duy nhất** — công việc mức bình thường/rủi ro cao trở thành một story kèm ma trận kiểm thử.
- **Xác minh trước khi "xong" (verification before "done")** — một hook `Stop` chặn việc kết thúc lượt khi lệnh xác minh của một story đang dở chưa pass.
- **Trace kèm friction** — mỗi tác vụ ghi lại điều đã xảy ra và chỗ harness gây vướng, làm dữ liệu cho `audit` và `propose`.

## Thiết kế

- **Phương pháp là toàn cục, trạng thái là theo từng project.** Plugin (skills + hooks + trình khởi chạy binary) cài một lần; mỗi project chỉ mang theo `.harness/harness.db` + schema của riêng nó. Không phải sao chép 42 file vào từng repo.
- **Binary tải theo nhu cầu.** Ở phiên đầu tiên, hook `SessionStart` tải đúng bản `harness-cli` từ GitHub Releases, kiểm tra SHA-256, rồi cache dưới thư mục dữ liệu của plugin. Tải thiếu/lỗi → các cổng tự hạ xuống chế độ tư vấn (advisory), không bao giờ làm hỏng phiên.
- **Phối hợp với [superpowers](https://github.com/obra/superpowers).** claude-harness sở hữu trạng thái bền, quản trị rủi ro và việc cưỡng chế; superpowers sở hữu kỷ luật kỹ thuật (brainstorming, lập kế hoạch, phát triển bằng subagent, TDD, gỡ lỗi, review code). Cài cả hai để có quy trình đầy đủ; claude-harness vẫn dùng độc lập được.

## Cài đặt (Claude Code)

```
/plugin marketplace add <owner>/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

Sau đó mở một project và chạy `/claude-harness:intake "<yêu cầu của bạn>"` để bật quản trị cho project đó.

**Windows:** cần Git for Windows (các hook chạy qua một lớp bọc bash đa hệ). Xem [docs/INSTALL.md](INSTALL.md).

## Sử dụng

Mở một phiên mới trong một project. Với repo mới (hoặc bản clone mới), chạy `/claude-harness:onboard` một lần để thu thập một context-pack bền, rồi vận hành vòng lặp với `/claude-harness:intake` → `:story` → `:verify` → `:trace`. Hướng dẫn đầy đủ (mô hình tư duy, ví dụ thực tế, các cổng chặn, cheat-sheet CLI, và xử lý sự cố) nằm ở **[docs/USAGE.md](USAGE.md)**.

## Skills

| Skill | Khi nào |
|---|---|
| `using-claude-harness` | Tự nạp mỗi phiên; vòng lặp intake → làm → verify → trace. |
| `harness-onboard-context` | Repo mới / clone mới / pack đã cũ: thu thập context-pack bền cho project. |
| `harness-intake` | Trước khi sửa code: phân loại đầu vào + làn rủi ro. |
| `harness-story` | Công việc bình thường/rủi ro cao cần story + ma trận kiểm thử. |
| `harness-verification-before-completion` | Trước khi tuyên bố xong/đã sửa/đã pass. |
| `harness-trace-and-friction` | Kết thúc một tác vụ; ghi trace + friction. |
| `harness-audit-and-propose` | Rà soát sức khỏe harness / friction lặp lại. |

## Slash command

`/claude-harness:onboard`, `:intake`, `:story`, `:verify`, `:trace`, `:audit`, `:harness-status`.

## Trạng thái

v0.1.0. CLI bền (`harness-cli`) được vendor trong [crates/harness-cli/](../../crates/harness-cli/) và được build + phát hành từ GitHub Releases của chính repo này (ghim trong `scripts/harness-cli-release-tag`); plugin tải nó ở phiên đầu tiên. Xem [docs/enforcement.md](enforcement.md) để biết các cổng hoạt động ra sao và hạ cấp thế nào.

`harness-cli` bắt nguồn từ mã nguồn bên thứ ba theo giấy phép MIT; bản quyền gốc được giữ nguyên trong [crates/harness-cli/LICENSE](../../crates/harness-cli/LICENSE).
