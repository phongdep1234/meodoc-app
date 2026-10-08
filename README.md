# Cửu Âm Chân Kinh

Ứng dụng riêng để đọc truyện tranh trên truyenqq.com.vn, cho Android (APK) và iPhone (IPA).

App mở chính trang truyenqq.com.vn bên trong (đăng nhập, theo dõi… vẫn do web xử lý) và thêm:

- Chặn quảng cáo: không cho chuyển hướng ra ngoài trang (TikTok, Shopee…), chặn popup, script và iframe quảng cáo
- Thanh dưới: Trang chủ · Chương trước · Chọn chương · Chương sau — tự ẩn khi cuộn xuống, tự hiện khi cuộn lên hoặc tới cuối chương
- Mở chương → toàn màn hình, giữ màn hình sáng
- Nhớ trang đang đọc, giữ đăng nhập

## Cấu trúc
- `android/` — Java + WebView. Khoá ký `android/app/cuuam.jks` (mật khẩu `cuuam123`), giữ nguyên để cài đè bản sau.
- `ios/` — Swift + WKWebView, sinh dự án bằng XcodeGen từ `project.yml`. Bundle ID `com.phong.cuuam`.
- `shared/adshield.js` — script chặn quảng cáo dùng chung.
- `.github/workflows/build.yml` — GitHub Actions build APK + IPA chưa ký.
