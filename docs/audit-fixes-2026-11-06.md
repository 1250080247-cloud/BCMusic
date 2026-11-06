# Sửa lỗi theo báo cáo phân tích và tính năng mới — 2026-11-06

Nhánh: `fix/audit-fixes-and-features` (chưa commit). Báo cáo gốc: phân tích chỉ đọc trên commit `ad62773`.

## Trạng thái kiểm chứng

- `npm ci --ignore-scripts` chạy được.
- `npm test`, `npm run lint`, `npm run build`: **chưa chạy được** trong phiên này (lệnh bị chặn bởi bộ phân loại quyền). Thay đổi chưa được kiểm chứng bằng test. Chạy lại trước khi merge.
- Test mới: `tests/audit-fixes.test.mjs` (hàm thuần: URL, body JSON, giới hạn số, gợi ý).

## Bảo mật và dữ liệu đầu vào

- `src/lib/url-policy.js` (mới): `embedUrl` chỉ nhận `https://w.soundcloud.com`; `sourceUrl` chỉ nhận trang SoundCloud/YouTube. Áp dụng khi ghi `favorites`, `history`, `playlist/song` và khi render iframe, link `SongModal` và `SoundCloudLibrary`.
- `src/lib/input.js` (mới): giới hạn độ dài chuỗi, lyrics ≤ 80.000 ký tự, playlist ≤ 500 bài, `Content-Type: application/json` bắt buộc với route ghi (chặn form CSRF).
- YouTube: tham số được encode bằng `URLSearchParams`; `order` nằm trong whitelist; `maxResults` giới hạn 1–50; `pageToken` theo regex.
- Avatar ngoài: chỉ chấp nhận host Google (`googleusercontent.com`, `ggpht.com`). Avatar ngoài từ host khác sẽ quay về ảnh mặc định.
- Đăng ký: username `[a-z0-9_.]`, mật khẩu ≤ 72 byte (bcrypt), chống trùng khi đồng thời.

## Giới hạn tần suất

- `src/lib/rate-limit.js` + `src/models/RateLimit.js`: cửa sổ cố định trong MongoDB, fail-open khi DB lỗi.
- Áp dụng: đăng ký (5/giờ/IP), đăng nhập (10/15 phút/username), search và explore (60/phút/IP), lyrics (120/phút/IP), gợi ý tìm kiếm (120/phút/IP), gợi ý cá nhân (30/giờ/người dùng).
- Giới hạn đăng nhập theo username: kẻ tấn công có thể khóa tạm một tài khoản 15 phút.

## Lỗi chức năng

- Lỗi provider YouTube trả `503` (không còn trả danh sách rỗng); `SearchView` đã hiển thị lỗi cho `!ok`.
- Playlist: thêm bài là một lệnh `updateOne` có điều kiện (không trùng, không quá 500 bài).
- Favorites và SoundCloud import: lỗi E11000 đồng thời trả thành công hoặc 409.
- Player: Next tự bỏ qua video lỗi; Previous tua về đầu khi đã phát > 3 giây; nút Shuffle hoạt động; lịch sử chỉ ghi khi bài thực sự phát; iframe và `opts` YouTube không tạo lại mỗi render; nhãn hard-code chuyển sang i18n.
- Mongoose: `returnDocument` thay cho `new`; bỏ khai báo index trùng trong `SongCache`.
- Đăng nhập: so sánh bcrypt với hash giả khi username không tồn tại (không lộ tài khoản qua thời gian phản hồi).
- Khách → tài khoản: `POST /api/user/merge-guest` chuyển playlist và lịch sử khách sang tài khoản khi đăng nhập; cookie khách được xoay sau khi gộp.

## Tính năng

- Trang playlist: đổi tên, chuyển công khai/riêng tư, sao chép liên kết, đổi thứ tự bài (lên/xuống), thêm vào hàng đợi.
- `GET /api/playlist` trả `isPublic`; `PATCH /api/playlist` nhận `name`, `isPublic`, `songOrder`.
- Trang công khai `/shared/[id]`: chỉ đọc, không lộ chủ sở hữu.
- Hàng đợi: "Phát tiếp theo" và "Thêm vào hàng đợi" trong `SongModal`; Next phát hàng đợi trước danh sách.
- Phát ngẫu nhiên (Shuffle): mỗi vòng phát đủ một lần, không lặp trong vòng.
- Hẹn giờ tắt nhạc: 15/30/60 phút.
- Gợi ý "Dành cho bạn" (`/for-you`, `GET /api/recommendations`): hai nghệ sĩ nghe nhiều nhất, loại bài đã nghe.
- Lịch sử: `GET /api/history?limit=&before=` trả `nextBefore` để phân trang.

## Chưa làm

- Đồng bộ playlist/yêu thích giữa web và Android: cần quyết định chính sách xung đột và sửa mã Kotlin/Dart (không build được trong phiên này).
- Khôi phục mật khẩu và liên kết Google với tài khoản username: cần nhà cung cấp email.
- Giám sát quota YouTube: chưa làm.
- Mã Android/Dart: không đổi.
- LICENSE: cần quyết định của chủ dự án.
- Cache phân loại Shorts vẫn là `Map` trong bộ nhớ: kết quả cuối cùng đã cache 1 giờ trong Mongo, nên ảnh hưởng bị giới hạn.
