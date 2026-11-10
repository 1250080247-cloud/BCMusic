# BÁO CÁO KIỂM THỬ VÀ NGHIỆM THU TÍNH NĂNG & HOÀN THIỆN HỆ THỐNG (TEST REPORT)

**Dự án:** BCMusic Personal App & Web Ecosystem<br>
**Nền tảng:** Android 1.2.7 (VersionCode: 2012) & Next.js 16.4.3 (Turbopack)<br>
**Thời gian cập nhật:** 10/11/2026<br>
**Trạng thái nghiệm thu:** ✅ **Pass toàn bộ bài test được bật; 2 test live-source được skip theo cấu hình.**<br>
- **Flutter Tests:** **65/65 passed** (100%)
- **Android Native Tests:** **54 test cases** trên 15 test classes; **52 passed, 0 failed, 2 skipped** (hai bài live-source cần bật cờ chạy nguồn trực tiếp).
- **Web Tests:** **204/204 passed** (100%)
- **Web Production Build:** **28/28 routes thành công**
- **Tính toàn vẹn hệ sinh thái:** ✅ **Giữ nguyên `OfflineCache.kt` và `SourceNetwork.kt`; `MusicPlaybackService.kt` được cập nhật có chủ đích để triển khai crossfade nền.**

---

## 1. TỔNG HỢP CÁC HẠNG MỤC NÂNG CẤP VÀ SỬA LỖI MỚI NHẤT

### 1.1. Khắc phục triệt để lỗi Hydration Mismatch trên Web (Next.js 16.4.3 Turbopack)
- **Vấn đề:**
  - GSAP trong [`PageMotion.js`](file:///d:/music/src/components/PageMotion.js) quét các phần tử `h1`, `[data-motion-intro]`, và `[data-motion-section]` ngay khi load trang và gán trực tiếp thuộc tính `opacity`, `transform` vào inline style của DOM node.
  - Khi React client hydrate các component (`HomeHeader`, `RankingSection`, `DualViewSection`, `GenreExplorer`), DOM thực tế đã bị GSAP chỉnh sửa dẫn đến hydration mismatch (đặc biệt là `GenreExplorer.js` tại line 295 với inline style shorthand `style={section}`).
- **Giải pháp:**
  - Áp dụng pattern `mounted` cho toàn bộ các section và header:
    - Trong [`src/components/HomeHeader.js`](file:///d:/music/src/components/HomeHeader.js): Giữ markup render SSR và lần render đầu tiên trên client đồng nhất tiếng Việt (`'vi'`), chỉ cập nhật theo `localStorage` (tiếng Anh) và giờ địa phương sau khi mount.
    - Trong [`src/components/RankingSection.js`](file:///d:/music/src/components/RankingSection.js) & [`src/components/DualViewSection.js`](file:///d:/music/src/components/DualViewSection.js): Chỉ gán `data-motion-section` khi `mounted && !isLoading`.
    - Trong [`src/components/GenreExplorer.js`](file:///d:/music/src/components/GenreExplorer.js): Bổ sung `mounted` state; chỉ gán `data-motion-section` sau khi mount, đồng thời chuyển style shorthand sang class Tailwind chuẩn `className="genre-explorer mx-auto max-w-[80rem] px-6 pb-10"`.
    - Trong [`src/components/PageMotion.js`](file:///d:/music/src/components/PageMotion.js): Cấu hình `immediateRender: false` và `clearProps: 'opacity,transform'` để sau khi hoàn thành animation, GSAP xóa sạch inline style trên DOM.
- **Kiểm chứng:**
  - Bộ test [`tests/hydration-regressions.test.mjs`](file:///d:/music/tests/hydration-regressions.test.mjs): Kiểm tra SSR, lần render đầu tiên và sau khi mount của `HomeHeader`, `RankingSection`, `DualViewSection`, và `GenreExplorer` -> **4/4 tests PASS**.

### 1.2. Nâng cao độ ổn định & Xử lý Timeout YouTube Data API trên Web
- **Vấn đề:** Mức timeout 6 giây cho search và 2.5 giây cho video stats quá sát khi mạng có độ trễ cao hoặc kết nối lạnh. Nếu timeout xảy ra trong lúc chưa có cache (cache miss), trang web báo "nguồn tạm thời không khả dụng", đồng thời `console.error` kích hoạt Console Error trên Next Dev Overlay.
- **Giải pháp:**
  - Trong [`src/lib/youtube.js`](file:///d:/music/src/lib/youtube.js): Nâng timeout tìm kiếm lên **10 giây** (`SEARCH_TIMEOUT_MS = 10000`) và metadata stats lên **4.5 giây** (`STATS_TIMEOUT_MS = 4500`), hỗ trợ ghi đè linh hoạt qua biến môi trường.
  - Đổi log sang `console.warn` có kiểm soát cho các lỗi timeout/mạng thông thường.
  - Tích hợp cơ chế fallback an toàn: nếu provider bị timeout/lỗi nhưng có bản cache cũ trong MongoDB (stale cache), trả về dữ liệu cũ có gắn cờ `stale: true` để người dùng tiếp tục nghe nhạc mà không bị gián đoạn; tuyệt đối không ghi cache lỗi thành danh sách rỗng.
- **Kiểm chứng:**
  - Bộ test [`tests/youtube-cache-performance.test.mjs`](file:///d:/music/tests/youtube-cache-performance.test.mjs): Kiểm tra request deadlines với AbortSignal, fallback stale cache, và xử lý unavailable khi không có cache -> **11/11 tests PASS**.

### 1.3. Tính năng Lời chào theo thời gian thực trên App Mobile
- **Tính năng:** Hiển thị lời chào động dựa theo thời gian thực tế kèm tên người dùng:
  - 05:00 - 11:00: *"Chào buổi sáng"*
  - 11:00 - 13:00: *"Chào buổi trưa"*
  - 13:00 - 18:00: *"Chào buổi chiều"*
  - 18:00 - 05:00: *"Chào buổi tối"*
  - Ghép với tên tài khoản đang đăng nhập hoặc mặc định *"Người nghe nhạc"*.
- **Triển khai:** Trong [`mobile/lib/app_shell.dart`](file:///d:/music/mobile/lib/app_shell.dart) bổ sung `getGreetingTimeOfDay(DateTime now)` và `getHeaderGreeting(AccountProfile? account, {DateTime? now})`.
- **Kiểm chứng:** Bộ test [`mobile/test/header_greeting_test.dart`](file:///d:/music/mobile/test/header_greeting_test.dart) -> **2/2 tests PASS**.

### 1.4. Playlist tài khoản trên Android & Khắc phục kẹt Repeat All với bài Cached
- **Tính năng:** Trang chi tiết Playlist tài khoản (`AccountPlaylistDetail`) với ảnh bìa tổng hợp 4 ô, tên playlist, số lượng bài, nút "Phát tất cả" và "Trộn bài". Nút phát nhanh trên thẻ playlist.
- **Hàng đợi nguồn Hybrid:** Nạp toàn bộ danh sách vào `_sourceQueue` phía Dart. Khi phát qua `MainActivity.kt` (`playSource`), ưu tiên file cache offline nếu bài đã tải, stream online nếu chưa tải.
- **Sửa lỗi kẹt Repeat All:** Khi phát hàng đợi nguồn do Dart điều khiển, Android ép `REPEAT_MODE_OFF` cho ExoPlayer (kể cả khi bài đang phát là file cache và `onlineTrack == null`). Khi bài kết thúc, ExoPlayer phát sinh `STATE_ENDED` để Dart chủ động chuyển bài tiếp theo hoặc quay về đầu hàng đợi nếu Repeat All. Repeat All nhiều bài của playlist offline thuần ExoPlayer vẫn hoạt động nguyên vẹn.
- **Kiểm chứng:** Các bài test [`mobile/test/account_playlist_test.dart`](file:///d:/music/mobile/test/account_playlist_test.dart) và [`QueueRepeatModeTest.kt`](file:///d:/music/mobile/android/app/src/test/kotlin/app/bcmusic/personal/QueueRepeatModeTest.kt) -> **PASS**.

### 1.5. Thêm bài vào Playlist với hai lựa chọn & Đồng bộ ID SoundCloud chuẩn
- **Tính năng:** Menu bài hát cung cấp 2 lựa chọn:
  1. *"Tải và thêm vào playlist offline"*: Chọn playlist có sẵn hoặc tạo mới, tải và lưu liên kết chờ vào `PendingPlaylistStore`. Khi `Download.STATE_COMPLETED`, tự động thêm vào playlist.
  2. *"Thêm ngay vào playlist có sẵn"*: Thêm trực tiếp vào playlist tài khoản (nếu online) hoặc playlist offline (nếu đã tải).
- **Đồng bộ ID SoundCloud:** Chuẩn hóa khóa lưu trữ hàng chờ, `DownloadManager` và playlist bằng ID chuẩn `ResolvedTrack.metadata.id` (`soundcloud_<id>`), khắc phục lỗi hash ID tạm thời của Flutter làm mất liên kết khi tải xong.
- **Kiểm chứng:** [`mobile/test/playlist_add_flow_test.dart`](file:///d:/music/mobile/test/playlist_add_flow_test.dart) và [`SoundCloudPendingPlaylistTest.kt`](file:///d:/music/mobile/android/app/src/test/kotlin/app/bcmusic/personal/SoundCloudPendingPlaylistTest.kt) -> **PASS**.

### 1.6. Hủy bỏ Crossfade toàn diện trên mọi đường điều khiển
- **Tính năng:** Chuyển bài mượt mà (Fade-out 5s cuối bài, Fade-in 5s đầu bài mới) trên cả Android và Web.
- **Độ ổn định:** Hủy fade job ngay lập tức khi:
  - Người dùng bấm Pause, Seek, Skip thủ công từ ứng dụng hoặc qua MediaSession (Notification, Lockscreen, tai nghe/Bluetooth).
  - Người dùng tắt Crossfade trong Cài đặt, điều chỉnh thanh âm lượng, hoặc chuyển sang chế độ Repeat One.
  - Đồng bộ âm lượng về giá trị cài đặt chính xác, không để coroutine cũ ghi đè âm lượng.
- **Kiểm chứng:** [`CrossfadeCancellationTest.kt`](file:///d:/music/mobile/android/app/src/test/kotlin/app/bcmusic/personal/CrossfadeCancellationTest.kt), [`CrossfadeRampTest.kt`](file:///d:/music/mobile/android/app/src/test/kotlin/app/bcmusic/personal/CrossfadeRampTest.kt) và [`tests/web-crossfade.test.mjs`](file:///d:/music/tests/web-crossfade.test.mjs) -> **PASS**.

---

## 2. BẢNG TỔNG HỢP KẾT QUẢ KIỂM THỬ TOÀN BỘ HỆ THỐNG

| Hạng mục kiểm thử | Công cụ / Lệnh | Kết quả chi tiết | Đánh giá |
| :--- | :--- | :--- | :---: |
| **Phân tích tĩnh Dart** | `flutter analyze` | `No issues found! (ran in 3.9s)` | ✅ PASS (0 lỗi, 0 cảnh báo) |
| **Kiểm thử tầng Flutter** | `flutter test` | **65/65 tests passed** | ✅ PASS (100%) |
| **Kiểm thử Native Android** | `:app:testDebugUnitTest --rerun-tasks` (JDK 17) | **52 passed, 0 failed, 2 skipped** trên 15 test classes | ✅ PASS các test được bật |
| **Kiểm thử tầng Web** | `npm test` | **204/204 tests passed** | ✅ PASS (100%) |
| **Biên dịch Production Web** | `npm run build` | **28/28 routes compiled thành công** (Turbopack) | ✅ PASS (100%) |

---

## 3. BẢNG ĐỐI CHIẾU VÙNG CẤM & QUY TẮC BẢO VỆ (MỤC E & F)

| Quy tắc bảo vệ | Trạng thái thực tế | Đánh giá |
| :--- | :--- | :---: |
| **Không sửa `OfflineCache.kt`** | File giữ nguyên 100%, không nằm trong git diff. | ✅ TUÂN THỦ |
| **Không sửa `SourceNetwork.kt`** | File giữ nguyên 100%, không nằm trong git diff. | ✅ TUÂN THỦ |
| **Crossfade playback** | `MusicPlaybackService.kt` được sửa có chủ đích để quản lý fade theo vòng đời phát nền. | ✅ ĐÚNG PHẠM VI |
| **Không đổi `applicationId` / package** | Giữ nguyên `app.bcmusic.personal`. | ✅ TUÂN THỦ TUYỆT ĐỐI |
| **Định danh bản phát hành** | `applicationId` giữ nguyên; `versionCode = 2012`, `versionName = 1.2.7`. | ✅ CẬP NHẬT |
| **Không sửa keystore / signing config** | Giữ nguyên cấu hình release. | ✅ TUÂN THỦ TUYỆT ĐỐI |
| **Không thêm dependency bên ngoài** | Giữ nguyên dependencies hiện có của Gradle, Flutter, NPM. | ✅ TUÂN THỦ TUYỆT ĐỐI |
| **Bảo toàn SharedPreferences cũ** | Dữ liệu `"bcmusic-preferences"`, `"bcmusic-playlists"` nguyên vẹn. | ✅ TUÂN THỦ TUYỆT ĐỐI |
