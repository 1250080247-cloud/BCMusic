# BCMusic

Ứng dụng nghe nhạc YouTube và SoundCloud, dùng Next.js App Router, NextAuth và MongoDB/Mongoose.

## Chạy dự án

Dùng Node.js 24 và npm 11.19.0 (được ghim trong `packageManager`; repo có `package-lock.json`).

```sh
npm ci
npm run dev
```

`.npmrc` tắt lifecycle scripts của dependency mặc định. Dùng `npm ci` để cài đúng lockfile; `npm run dev`, `npm test` và `npm run build` vẫn chạy bình thường. Khi thêm dependency cần install script, phải xem nội dung script và chỉ chạy bước cần thiết sau khi rà soát.

Mở http://localhost:3000. Cấu hình `.env.local` bằng các giá trị riêng của môi trường:

```dotenv
MONGODB_URI=mongodb://localhost:27017/bcmusic
# Tuỳ chọn khi DNS SRV của Node gặp lỗi; để trống nếu DNS hệ thống hoạt động.
MONGODB_DNS_SERVERS=
NEXTAUTH_SECRET=replace-with-a-long-random-secret
NEXTAUTH_URL=http://localhost:3000
YOUTUBE_API_KEY=your-youtube-data-api-key
GOOGLE_CLIENT_ID=your-google-oauth-client-id
GOOGLE_CLIENT_SECRET=your-google-oauth-client-secret
```

Google OAuth cần cấu hình callback `/api/auth/callback/google`. Không commit `.env.local` hoặc bí mật vào Git.

```sh
npm test
npm run lint
npm audit
npm run build
npm start
```

Test dùng `node:test`, VM và SWC có sẵn, chạy độc lập với database và dịch vụ ngoài. Build cần truy cập Google Fonts để tải Geist và Geist Mono.

## DNS và kiểm tra MongoDB thật

Nếu Node trên Windows báo `querySrv ECONNREFUSED` dù DNS của Windows hoạt động, thêm `MONGODB_DNS_SERVERS=1.1.1.1,8.8.8.8` vào `.env.local`, rồi khởi động lại app. Cấu hình chỉ đổi resolver trong tiến trình Node cho URI `mongodb+srv://`; không sửa DNS Windows hoặc đổi database. Trên Vercel, để biến này trống nếu DNS mặc định hoạt động.

Ứng dụng cấu hình cả DNS callback và Promise. Điều này cần cho production Next.js: nếu `node:dns/promises` được nạp trước, chỉ gọi `dns.setServers()` có thể vẫn để MongoDB dùng resolver cũ. Sau khi đổi mã, chạy lại `npm run build` rồi khởi động lại production bằng `npm start`.

```sh
npm run verify:db
npm run verify:db:crud
```

Lệnh đầu chỉ kết nối và ping. Lệnh CRUD tạo/đọc/sửa/xóa bản ghi tạm với `_id` và danh tính riêng trong các collection ứng dụng đã tồn tại, tắt autoIndex/autoCreate, rồi xác minh số lượng bản ghi và index không đổi. Cleanup chỉ xóa đúng bản ghi do lần kiểm tra tạo; không chạy migration. Hoạt động ghi khác hoặc TTL đồng thời có thể làm kiểm tra số lượng không khớp.

## Animation

GSAP Core, React `useGSAP` và ScrollTrigger điều khiển hiệu ứng xuất hiện tiêu đề, danh sách và các phần trang chủ khi cuộn. Animation dùng scope theo component, được dọn khi điều hướng và tắt với `prefers-reduced-motion`. Nội dung vẫn hiện khi JavaScript chưa chạy. Hai dependency `gsap` và `@gsap/react` được ghim phiên bản; không thay luồng phát nhạc hoặc cuộn của trình duyệt.

## Player và lời bài hát

Bấm ảnh bìa hoặc nút lời ở thanh phát để mở player toàn màn hình. Player dùng ảnh bìa làm nền, giữ các điều khiển YouTube/SoundCloud hiện có và có tab lời, hàng đợi, thông tin. Escape thu gọn giao diện và tiếp tục phát nhạc.

Lời được tra qua LRCLIB miễn phí, với lyrics.ovh làm nguồn dự phòng khi LRCLIB không có lời dùng được hoặc gặp lỗi. Hai nguồn không cần API key và không ghi lời vào MongoDB. Bản LRCLIB có timestamp LRC sẽ chạy theo từng dòng nếu thời lượng khớp bản ghi; bấm câu để tua. lyrics.ovh chỉ cung cấp lời văn bản, hiển thị tĩnh và có ghi nguồn; không tạo timestamp giả. Chi tiết hợp đồng và trạng thái lỗi: `docs/player-lyrics.md`.

Trang playlist dùng khung rộng hơn và ảnh ghép từ bốn bài được thêm gần nhất vào từng playlist. Playlist một bài dùng một ảnh; nếu thiếu bài hoặc ảnh lỗi, ô tương ứng dùng biểu tượng nhạc. Ảnh ghép chỉ được tính khi hiển thị, không sửa thứ tự phát hay bản ghi MongoDB.

Tìm kiếm và gợi ý không còn giới hạn `videoDuration=medium`: giữ cả bài thường ngắn hơn 2:30 và bài dài. Ứng dụng kiểm tra routing của URL Shorts công khai để loại bản xác định là Shorts, có timeout và cache giới hạn. YouTube Data API không cung cấp cờ `isShort`; khi không xác minh được, ứng dụng giữ video để tránh loại nhầm bài nhạc. Cache MongoDB cũ được giữ nguyên, không xóa hàng loạt.

Trên trang chủ, cả Top Thịnh Hành, Xem nhiều nhất và Mới nhất đều lấy theo thể loại đang chọn. Top dùng tìm kiếm nổi bật theo thể loại, Xem nhiều nhất sắp xếp theo lượt xem, Mới nhất theo ngày đăng; đây không phải bảng xếp hạng thịnh hành chính thức của YouTube. Nhãn thể loại hiện trên cả ba phần. TikTok Remix dùng truy vấn `tiktok remix`, không ghép thêm `ncs`.

Khi đổi thể loại, phần đầu trang và khung tải hiện trước; ba danh sách được gửi xuống độc lập khi có kết quả. Cache YouTube lưu thời lượng và trạng thái đã lọc Shorts, không gọi lại YouTube trên mỗi lần đọc cache còn hạn. Cache cũ được kiểm tra một lần khi đọc và bổ sung metadata, giữ mốc hết hạn cũ. Kết quả rỗng hợp lệ cũng được cache, còn lỗi dịch vụ không được lưu như kết quả rỗng. Các yêu cầu trùng nhau dùng chung một lượt tải trong cùng tiến trình; việc này không phải khóa giữa các instance Vercel. Chi tiết đo tốc độ: `docs/category-performance.md`.

## Quyền truy cập và dữ liệu

- API hồ sơ và yêu thích bắt buộc đăng nhập. Chủ sở hữu lấy từ session server; `userId` do client gửi không được dùng để cấp quyền.
- Playlist, SoundCloud và lịch sử hỗ trợ khách bằng cookie `bcmusic-guest`, do Proxy cấp và ký bằng `NEXTAUTH_SECRET`. Cookie là HttpOnly, SameSite=Lax, Secure trong production. HTTPS và secret ổn định giữa các instance là bắt buộc khi triển khai.
- Đổi `NEXTAUTH_SECRET` sẽ làm mất hiệu lực session và cookie khách hiện có. Xóa cookie cũng mất quyền truy cập thư viện khách trên thiết bị đó.
- ID khách cũ trong localStorage và lịch sử cũ có `userId: null` không còn được dùng làm danh tính. Các bản ghi vẫn được giữ trong database; không tự nhận quyền sở hữu hay gán dữ liệu này sang tài khoản/cookie khác.

## Thay đổi schema tương thích dữ liệu cũ

`Favorite` thêm `sourceUrl`; `History` thêm `embedUrl` và `sourceUrl`. Cache YouTube thêm `songs.durationSeconds` và `shortsFiltered`. Các trường đều tương thích với bản ghi cũ; giữ nguyên collection, ID và index hiện có. Không cần migration ghi hàng loạt để chạy phiên bản này.

Bản ghi SoundCloud cũ thiếu URL phát được bổ sung khi đọc từ thư viện cùng chủ sở hữu. Nếu không tìm thấy metadata, ID track dạng `sc_<số>` được dùng để dựng URL phát. ID playlist cũ không có metadata và không còn trong thư viện gốc cần import lại URL SoundCloud vì ID cũ không phân biệt track/playlist.

Ảnh đại diện cũ đã bị ghi đè bằng URL proxy không thể phục hồi ảnh gốc từ URL đó; ứng dụng hiển thị ảnh mặc định để người dùng tải ảnh mới. Đổi tên hồ sơ không gửi trường ảnh và không ghi đè ảnh đang lưu.

Các thay đổi schema nằm trong source; giữ nguyên chuỗi kết nối và dữ liệu hiện có. Khi cần đổi database/nhà cung cấp, sao lưu dữ liệu và lập kế hoạch chuyển đổi riêng.
