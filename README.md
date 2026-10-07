# Mèo Đọc

Ứng dụng riêng để đọc truyện trên meosss.com, cho Android (APK) và iPhone (IPA).

App mở chính trang meosss.com bên trong, nên đăng nhập, Thư viện, Lịch sử đọc, Mở khoá… đều hoạt động như trên web. Thêm vào đó:

- Thanh dưới: Trang chủ · Mới · Thư viện · Lịch sử · Tải lại (Android) / Quay lại (iPhone); tự ẩn khi cuộn xuống, hiện khi cuộn lên
- Mở trang chương → chế độ đọc: ẩn thanh trạng thái, giữ màn hình luôn sáng
- Nhớ trang đang đọc, mở lại app là quay về đúng chỗ
- Giữ đăng nhập (cookie)
- Link ngoài (Facebook, Discord) mở bằng trình duyệt/app tương ứng
- iPhone: vuốt từ mép trái để quay lại, kéo xuống để tải lại

## Cấu trúc

- `android/` — dự án Android (Java, không thư viện ngoài). Build: `gradle assembleRelease` trong thư mục `android`.
  Khoá ký `android/app/meodoc.jks` (mật khẩu `meodoc123`) — giữ nguyên file này để các bản sau cài đè được.
- `ios/` — dự án iOS (Swift/UIKit + WKWebView), sinh file Xcode bằng XcodeGen từ `project.yml`.
- `.github/workflows/build.yml` — GitHub Actions build cả APK và IPA chưa ký mỗi lần push lên `main`.

## Build IPA bằng GitHub

1. Tạo repo mới (ví dụ `meodoc-app`, để Private) và đẩy toàn bộ thư mục này lên nhánh `main`.
2. Vào tab **Actions** → workflow **Build APK + IPA** chạy tự động (hoặc bấm **Run workflow**).
3. Khi xong (~5–8 phút), mở lần chạy đó → mục **Artifacts** → tải `MeoDoc-ipa` (file `MeoDoc-unsigned.ipa`).
4. Ký IPA bằng tài khoản Apple Developer rồi cài lên iPhone. Bundle ID: `com.phong.meodoc`.
