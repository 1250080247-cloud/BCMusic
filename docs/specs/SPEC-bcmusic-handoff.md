# Đặc tả module bcmusic-handoff

Trạng thái: dự thảo. Phụ thuộc: android-shell, source-resolver. Quy ước chung: [SPEC-android.md](SPEC-android.md).

## Mục tiêu

Đưa một bài đang xem trên BCMusic/YouTube/SoundCloud vào app bằng chia sẻ hoặc dán link, đồng thời giữ khả năng mở BCMusic online tại địa chỉ Vercel hiện có.

## Hành vi và giao diện

- App đăng ký Android ACTION_SEND cho text/plain. Người dùng chia sẻ link từ trình duyệt hoặc app nguồn rồi chọn BCMusic.
- Trang chủ và Tìm kiếm đọc các endpoint công khai `/api/explore` và `/api/search` trên Vercel. Chọn một bài để nghe hoặc mở thông tin trước khi tải. Playlist cục bộ lưu trên điện thoại.
- App cũng có ô dán link với nút đọc clipboard do người dùng chủ động bấm. Không tự đọc clipboard khi mở app.
- Nội dung chia sẻ có title kèm một URL được hỗ trợ thì lấy URL đó. Input không có URL hoặc có nhiều bài phải yêu cầu chọn/dán một link; không tự tải hàng loạt.
- Nhận link khi app đã mở hoặc mở mới đều đưa về cùng luồng chuẩn hóa/resolve. Intent được coi là input không tin cậy; không cho intent chỉ định đường dẫn lưu, header, tên tệp hoặc URL stream trực tiếp.
- Sau khi resolve, hiển thị title/artist/nguồn và nút tải. Chỉ nút tải của người dùng mới tạo tác vụ; intent gửi lặp không tự tạo nhiều tải.
- “Mở BCMusic” mở đúng https://bc-music-gilt.vercel.app/ bằng Custom Tabs khi có trình duyệt hỗ trợ, có fallback mở trình duyệt. Đăng nhập Google và session web tiếp tục do trình duyệt quản lý.
- Nếu không có trình duyệt xử lý, báo thông báo có thể hiểu được; nếu không có mạng, thư viện đã tải vẫn dùng được.
- Luồng bản đầu dùng link nguồn đã có trong chi tiết bài của web. Việc thêm nút riêng trên web hoặc Android App Links có xác minh sẽ là thay đổi bổ sung khi cần; bản đầu không phụ thuộc deploy Vercel mới.

## Công nghệ và cấu trúc

Android intent, clipboard theo thao tác người dùng, Custom Tabs/AndroidX Browser phiên bản ghim khi triển khai; source-resolver chịu trách nhiệm kiểm tra URL. Mã ở `android/app/src/main/java/app/bcmusic/personal/handoff/`; intent filter ở Manifest; resource UI trong `res/`.

## Quy ước mã

Dùng Kotlin theo đặc tả chung. Tách phân tích text chia sẻ thành hàm thuần có test; Activity chỉ chuyển payload đã chuẩn hóa sang UI. Website URL là hằng số HTTPS cố định, không lấy từ EXTRA_TEXT.

```kotlin
fun sourceFromSharedText(text: String): SourceRef
```

## Lệnh và kiểm thử

Từ `D:\music\android`: `./gradlew.bat :app:testDebugUnitTest --tests "*Handoff*"`; `./gradlew.bat :app:connectedDebugAndroidTest`; `./gradlew.bat :app:assembleDebug`.

Test text có title/link, link youtu.be, SoundCloud, nhiều URL, URL không hỗ trợ, extra bị thiếu/sai kiểu và payload quá dài. Kiểm tra chia sẻ khi app chưa mở/đã mở, nhấn Back, intent lặp và fallback trình duyệt. Kiểm tra website online riêng không đồng nghĩa đã xác minh tài khoản hoặc đăng nhập Google trong app.

## Ranh giới

- Luôn: xác thực intent, preview trước tải, mở website cố định qua trình duyệt và tôn trọng thao tác clipboard.
- Cần trao đổi: bổ sung nút web, deep link/app link, đồng bộ session/tài khoản hoặc triển khai thay đổi lên Vercel.
- Không nhúng trang đăng nhập Google trong WebView, không chuyển cookie/NextAuth secret qua intent và không tự mở/tải URL tùy ý do app ngoài gửi.

## Tiêu chí hoàn thành

1. Chia sẻ hoặc dán một link bài hợp lệ mở preview và cho phép tải sau xác nhận; intent độc hại/không hợp lệ báo lỗi.
2. Chuyển link lặp không tạo tác vụ tải ngoài ý muốn; app đang mở và cold start cùng hoạt động.
3. Mở đúng website BCMusic khi có trình duyệt; mất mạng không chặn việc dùng thư viện offline.

## Điểm còn lại

Bản đầu dùng chia sẻ/dán link. Nút gửi trực tiếp từ giao diện web có thể bổ sung sau khi luồng app đã hoạt động và được yêu cầu triển khai.
