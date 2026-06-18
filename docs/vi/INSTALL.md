# Cài đặt claude-harness

[English](../INSTALL.md) · **Tiếng Việt** · [简体中文](../zh/INSTALL.md)

## Yêu cầu

- **Claude Code v2.1+** (các hook: `permissionDecision`, `decision` của Stop, `${CLAUDE_PLUGIN_DATA}`).
- **curl** (để tải binary CLI) và một công cụ SHA-256 (`sha256sum`/`shasum`/`certutil`).
- **Windows:** **Git for Windows** — các hook chạy qua một lớp bọc đa hệ `run-hook.cmd` để định vị `bash.exe`. Không có bash, plugin vẫn nạp được nhưng các cổng trở nên vô hiệu (nó im lặng thoát với mã 0).

## Cài đặt (Claude Code)

```
/plugin marketplace add <owner>/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

Hoặc, cho phát triển cục bộ, trỏ marketplace vào một bản checkout:

```
/plugin marketplace add /path/to/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

Khởi động lại phiên (hoặc chạy `/clear`) để hook `SessionStart` chạy.

## Điều gì xảy ra ở phiên đầu tiên

Hook `SessionStart` chạy `scripts/bootstrap-binary`, nó:

1. Phát hiện nền tảng và tải đúng asset `harness-cli` từ bản GitHub release đã ghim (`scripts/harness-cli-release-tag`), kiểm tra file `.sha256` của nó, rồi cache tại
   `${CLAUDE_PLUGIN_DATA}/claude-harness/bin/<tag>/harness-cli[.exe]`.
2. Tạo `<project>/.harness/` gồm schema và một trình khởi chạy (`.harness/harness`) đã nối dây tới binary đó, rồi thêm `.harness/` vào `.gitignore` của project.
3. Inject skill `using-claude-harness` vào phiên.

Nếu bước nào thất bại (offline, nền tảng không hỗ trợ, project chỉ-đọc), phiên vẫn khởi động và các cổng **hạ xuống chế độ tư vấn (advisory)** — không có gì bị chặn.

## Bật quản trị cho một project

Một project chỉ được quản trị khi đã có `.harness/harness.db`. Tạo nó bằng cách chạy:

```
/claude-harness:intake "<điều bạn muốn làm>"
```

(hoặc `.harness/harness init`). Trước khi có nó, các cổng cho phép mọi thứ.

## Biến môi trường ghi đè

| Biến | Tác dụng |
|---|---|
| `HARNESS_CLI_RELEASE_TAG` | Dùng một release tag khác (hoặc `latest`). |
| `HARNESS_CLI_BASE_URL` | Tải từ một mirror / nguồn offline. |
| `HARNESS_CLI_BIN` | Dùng một binary cụ thể (bỏ qua bước tải). |
| `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` | Số lần Stop chặn liên tiếp tối đa trước khi Claude Code ghi đè (mặc định 8). |

## Gỡ cài đặt

```
/plugin uninstall claude-harness@claude-harness-marketplace
```

Trạng thái theo từng project nằm trong `.harness/` (đã gitignore); xóa nó để reset hoàn toàn một project. Binary đã cache nằm dưới thư mục dữ liệu của plugin.

## Phối hợp với superpowers (khuyến nghị)

Cài [superpowers](https://github.com/obra/superpowers) song song. claude-harness nhường phần thực thi kỹ thuật (brainstorming, lập kế hoạch, phát triển bằng subagent, TDD, gỡ lỗi, review code) cho nó; còn claude-harness tự lo trạng thái bền, làn rủi ro, và các cổng chặn cứng. Không bên nào bắt buộc bên kia phải có để hoạt động.
