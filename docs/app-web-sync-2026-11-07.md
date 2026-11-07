# Kiểm lỗi và đồng bộ web với app Android — 2026-11-07

Nhánh: `claude/bug-check-web-app-sync-b1ywz5`.

## Phạm vi đã đối chiếu

Từng endpoint web mà app Android (`mobile/android/.../AccountClient.kt`) và app Flutter (`mobile/lib/`) gọi, so với route tương ứng trong `src/app/api/`:

- Đăng nhập Google qua web: `GET/POST /api/mobile/auth/exchange`, `POST /api/mobile/auth/authorize`, trang `/mobile/sign-in`, deep link `app.bcmusic.personal://account/complete`. Khớp về PKCE, cookie phiên và định dạng JWT (NextAuth 4.24 dùng salt rỗng ở cả encode và decode).
- Tài khoản: `POST /api/auth/register`, `/api/auth/csrf`, `/api/auth/callback/credentials`, `/api/auth/session`, `POST /api/user/update`.
- Yêu thích và playlist: `GET/POST/DELETE /api/favorites`, `GET/POST/PATCH/DELETE /api/playlist`, `POST/DELETE /api/playlist/song`.
- Khám phá: `GET /api/explore`, `GET /api/search`, `GET /api/search/suggestions`, `GET /api/user/avatar`.

Khớp về tham số, tên trường và shape phản hồi. Phần còn lệch được sửa dưới đây.

## Thay đổi

| Vấn đề | Trước | Sau |
| --- | --- | --- |
| Title bài hát: app cho tới 500 ký tự, web chỉ nhận 300 | Lưu yêu thích hoặc thêm vào playlist thất bại với lỗi chung | `LIMITS.title = 500` dùng cho `/api/favorites` và `/api/playlist/song` |
| Username đăng ký trên Android không theo quy tắc của web (`[a-z0-9_.]`, 3–30 ký tự) | Server từ chối sau khi gửi, hiện lỗi chung | Android chuẩn hóa chữ thường và kiểm tra trước khi gửi; form Flutter báo lỗi ngay |
| Giới hạn id playlist song: app 512, web 128 | Lệch hợp đồng (thực tế không xảy ra với id YouTube/SoundCloud) | App dùng 128 như web |
| Thể loại Acoustic: web `nhạc acoustic nhẹ nhàng`, app `acoustic nhẹ nhàng` | Kết quả khác nhau giữa web và app | Web dùng `acoustic nhẹ nhàng`; link cũ được ánh xạ qua `legacyQueries` |
| `npm test` lỗi trên Node 22 (`--test-isolation` chỉ có trên Node 24); README ghi Node 20+ | Không chạy được test trên Node 22 | Dùng `--experimental-test-isolation=none` (chạy được trên 22 và 24); README yêu cầu Node 22+ |

Cũng sửa trong quá trình đọc code: tra cứu `legacyQueries` dùng `Object.hasOwn` để `?genre=constructor` không đọc thuộc tính của prototype.

## Kiểm chứng

| Kiểm tra | Kết quả |
| --- | --- |
| `npm test` trên Node 22.23 | 190/190 pass (trước khi sửa: 185 pass trên Node 24, không chạy được trên Node 22) |
| `npm test` trên Node 24.22 | 190/190 pass |
| Test mới đã thấy thất bại trước khi sửa | `tests/app-web-contract.test.mjs` (favorites và playlist song nhận 500 ký tự), `tests/home-genre.test.mjs` (acoustic) |
| `npm run lint` | Pass |
| `npm run build` | Pass (cần biến `MONGODB_URI` giả khi build; xem lưu ý dưới đây) |

**Chưa kiểm chứng:** mã Kotlin (`AccountClient.kt`) và Dart (`account_screen.dart`). Môi trường không có Android SDK và Flutter nên không compile hoặc chạy `bcmusic.ps1 check`. Hãy chạy `tool/bcmusic.ps1 check` trước khi phát hành.

Lưu ý: `next build` đòi `MONGODB_URI` ngay lúc thu thập dữ liệu trang (`src/lib/mongodb.js`). Đây là hành vi có chủ đích, không phải lỗi.

## Chưa làm

- **Đồng bộ lịch sử nghe** giữa web và app: app ghi lịch sử cục bộ (`RecentActivity.kt`), web lưu lịch sử trên tài khoản. Cần quyết định chính sách hợp nhất trước khi làm.
- Chưa thêm unit test Kotlin cho validation đăng ký (`AccountClient` phụ thuộc Android `Context` và `KeyStore`).
