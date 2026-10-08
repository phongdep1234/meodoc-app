# Lời giải hay

Ứng dụng riêng để đọc [loigiaihay.com](https://loigiaihay.com) không quảng cáo — Android (APK) và iPhone (IPA).

- Chặn máy chủ quảng cáo (Google Ads, ZMedia/adservingz, Admicro, Tuyensinh247, Jupi, Decumar…)
- Ẩn banner dính đầu trang, popup, đồng hồ đếm ngược, video quảng cáo, nút "Tải app"
- Link quảng cáo bị bỏ qua; link ngoài khác chỉ mở bằng trình duyệt khi bấm vào
- Thanh dưới: Quay lại · Trang chủ · Tải lại · Lên đầu · Tiến (tự ẩn khi cuộn đọc bài)
- Nhớ trang đang xem, giữ đăng nhập

Cấu trúc: `shared/adshield.js` (script chặn dùng chung), `android/` (WebView, Java), `ios/` (WKWebView, Swift + XcodeGen).
GitHub Actions build APK đã ký và IPA chưa ký (tự ký bằng tài khoản Apple Developer).
