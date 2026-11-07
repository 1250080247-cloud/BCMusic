# BCMusic

BCMusic là ứng dụng web nghe nhạc từ YouTube và SoundCloud. Người dùng tìm bài hát, khám phá nhạc theo thể loại, xem lời bài hát đồng bộ và quản lý playlist ngay trên trình duyệt.

**Demo:** [bc-music-gilt.vercel.app](https://bc-music-gilt.vercel.app/)

Ứng dụng Android đi kèm nằm trong thư mục [`mobile/`](mobile/README.md).

## Tính năng

**Khám phá và tìm kiếm**
- Khám phá theo **Top Thịnh Hành**, **Xem nhiều nhất** và **Mới nhất**, lọc theo thể loại.
- Tìm bài theo tên bài hát hoặc nghệ sĩ, có gợi ý khi gõ.
- **Dành cho bạn**: gợi ý bài hát từ hai nghệ sĩ bạn nghe nhiều nhất.

**Nghe nhạc**
- Trình phát toàn màn hình với hàng đợi, lời bài hát và thông tin chi tiết.
- Lời đồng bộ theo dòng: bấm vào một câu để tua đến đoạn đó.
- Phát ngẫu nhiên (shuffle), lặp lại, phát tiếp theo, và hẹn giờ tắt nhạc (15/30/60 phút).
- Tự chuyển bài khi video không phát được.
- Nhập bài từ SoundCloud bằng link.

**Tài khoản và thư viện**
- Đăng ký bằng tên đăng nhập hoặc đăng nhập bằng Google.
- Lưu bài yêu thích, playlist và lịch sử nghe.
- Playlist: đổi tên, sắp xếp bài, và chia sẻ công khai qua liên kết chỉ đọc.
- Khi đăng nhập, playlist và lịch sử đã nghe khi chưa đăng nhập sẽ được chuyển vào tài khoản.

## Công nghệ

- **Frontend:** Next.js 16 (App Router), React 19, Tailwind CSS 4, Zustand, Framer Motion, GSAP.
- **Backend:** Route Handlers của Next.js, MongoDB với Mongoose, NextAuth v4 (JWT).
- **Nguồn dữ liệu:** YouTube Data API v3, SoundCloud oEmbed, LRCLIB và lyrics.ovh (lời bài hát).

## Yêu cầu

- Node.js 22 trở lên và npm (đã kiểm thử với Node 22.23 và 24.22; `npm test` dùng flag `--experimental-test-isolation`).
- Cơ sở dữ liệu MongoDB (Atlas hoặc tự host).
- YouTube Data API v3 key để tìm kiếm, khám phá và gợi ý.
- (Tùy chọn) Google OAuth client để đăng nhập bằng Google.

## Cài đặt

```bash
git clone https://github.com/1250080247-cloud/BCMusic.git
cd BCMusic
npm ci --ignore-scripts
```

Dự án tắt script cài đặt của dependency qua `.npmrc`. Luôn dùng `npm ci` để giữ đúng phiên bản trong `package-lock.json`.

Tạo file `.env.local` ở thư mục gốc:

```bash
MONGODB_URI=mongodb+srv://<user>:<password>@<cluster>/<database>
NEXTAUTH_SECRET=<chuỗi ngẫu nhiên, ví dụ: openssl rand -base64 32>
NEXTAUTH_URL=http://localhost:3000
YOUTUBE_API_KEY=<YouTube Data API v3 key>
GOOGLE_CLIENT_ID=<tùy chọn>
GOOGLE_CLIENT_SECRET=<tùy chọn>
MONGODB_DNS_SERVERS=<tùy chọn, ví dụ: 8.8.8.8,1.1.1.1>
```

| Biến | Bắt buộc | Mô tả |
| --- | --- | --- |
| `MONGODB_URI` | Có | Chuỗi kết nối MongoDB. Thiếu biến này ứng dụng không khởi động. |
| `NEXTAUTH_SECRET` | Có | Khóa ký phiên đăng nhập và cookie khách. Không được thiếu khi chạy production. |
| `NEXTAUTH_URL` | Có khi deploy | URL công khai của ứng dụng. |
| `YOUTUBE_API_KEY` | Có cho tìm kiếm | Thiếu key thì tìm kiếm, khám phá và gợi ý báo lỗi tạm thời. |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Không | Chỉ cần khi bật đăng nhập Google. |
| `MONGODB_DNS_SERVERS` | Không | DNS thay thế cho chuỗi `mongodb+srv://` trên một số máy Windows. |

Không commit `.env.local`. File này đã nằm trong `.gitignore`.

## Chạy

```bash
npm run dev      # Môi trường phát triển tại http://localhost:3000
npm run build    # Build production
npm run start    # Chạy bản build
```

## Kiểm thử

```bash
npm test         # Chạy toàn bộ test trong tests/
npm run lint     # ESLint
npm run verify:db        # Kiểm tra kết nối MongoDB (chỉ đọc)
npm run verify:db:crud   # Kiểm tra CRUD trên dữ liệu tạm, sau đó xóa
```

Test tự động dùng mock cho các dịch vụ bên ngoài. Kiểm thử end-to-end với MongoDB và YouTube key thật cần được chạy riêng.

## Cấu trúc thư mục

```
src/
  app/            Trang (App Router) và API routes (app/api/*)
  components/     Giao diện: trình phát, tìm kiếm, playlist, cài đặt
  lib/            Xác thực, kết nối DB, YouTube, lời bài hát, giới hạn tần suất
  models/         Schema Mongoose
tests/            Test node:test (có mock)
mobile/           Ứng dụng Android (Flutter + Kotlin)
docs/             Ghi chú kỹ thuật và kết quả kiểm chứng
```

## Đóng góp

1. Tạo nhánh từ `main`.
2. Viết test cho thay đổi và chạy `npm test` và `npm run lint`.
3. Mở pull request mô tả rõ thay đổi và cách kiểm thử.

## Giấy phép

Repo hiện chưa có file LICENSE. Mọi quyền được bảo lưu cho chủ dự án cho đến khi có giấy phép được công bố.
