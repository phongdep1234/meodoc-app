import Foundation
import WebKit

/// Chặn quảng cáo cho loigiaihay.com: chặn máy chủ quảng cáo, chỉ cho script/khung từ máy chủ tin cậy.
enum AdShield {

    /// Máy chủ được phép tải script/khung/dữ liệu (ngoài các máy chủ này chỉ cho tải ảnh, phông, CSS).
    static let allowed = ["loigiaihay.com", "googleapis.com", "gstatic.com", "cloudflare.com", "jsdelivr.net",
                          "quizlet.com", "youtube.com", "youtube-nocookie.com", "ytimg.com", "googlevideo.com",
                          "facebook.com", "facebook.net", "fbcdn.net", "firebaseio.com", "firebaseapp.com",
                          "recaptcha.net", "mathjax.org", "jquery.com", "google.com"]

    /// Máy chủ quảng cáo / theo dõi / quảng bá — chặn hoàn toàn, kể cả ảnh.
    static let blocked = ["tuyensinh247", "jupi.vn", "decumar", "ladicdn", "ladipage",
                          "adservingz", "zmedia", "admicro", "vcmedia", "vccorp", "eclick", "adtima", "zadn.vn",
                          "sp.zalo.me", "vliplatform", "yomedia", "ambientdsp", "clickmon", "novanet", "ants.vn",
                          "googlesyndication", "doubleclick", "googleadservices", "adservice.google",
                          "googletagmanager", "googletagservices", "google-analytics", "imasdk.googleapis",
                          "pagead", "adnxs", "adsrvr", "criteo", "pubmatic", "rubiconproject", "openx",
                          "taboola", "outbrain", "mgid", "amazon-adsystem", "dmca.com",
                          "shopee", "lazada", "tiki.vn", "tiktok"]

    static func isSite(_ host: String) -> Bool {
        host == "loigiaihay.com" || host.hasSuffix(".loigiaihay.com")
    }

    static func isLogin(_ host: String) -> Bool {
        host == "accounts.google.com" || host == "facebook.com" || host.hasSuffix(".facebook.com")
            || host == "appleid.apple.com"
    }

    static func isAllowedHost(_ host: String) -> Bool {
        isSite(host) || allowed.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func isAd(_ url: URL) -> Bool {
        let s = url.absoluteString.lowercased()
        return blocked.contains { s.contains($0) }
    }

    /// Script chạy sớm trên mọi trang (ẩn khung quảng cáo, gỡ link/ảnh/iframe quảng cáo, chặn popup).
    static let script: String? = {
        guard let u = Bundle.main.url(forResource: "adshield", withExtension: "js") else { return nil }
        return try? String(contentsOf: u, encoding: .utf8)
    }()

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: ".", with: "\\\\.")
    }

    /// Bộ lọc mạng của WebKit (Content Blocker), biên dịch một lần rồi gắn vào WebView.
    static func installRules(into ucc: WKUserContentController, then done: @escaping () -> Void) {
        var rules: [String] = []
        // 1) Chặn script / khung / XHR / popup / media từ máy chủ ngoài
        rules.append(#"{"trigger":{"url-filter":".*","load-type":["third-party"],"resource-type":["script","raw","document","popup","media"]},"action":{"type":"block"}}"#)
        // 2) …trừ các máy chủ tin cậy
        for h in allowed {
            rules.append(#"{"trigger":{"url-filter":"^https?://[^/]*"# + esc(h) + #"[:/]"},"action":{"type":"ignore-previous-rules"}}"#)
        }
        // 3) Máy chủ quảng cáo: chặn tất cả, kể cả ảnh
        for b in blocked {
            rules.append(#"{"trigger":{"url-filter":""# + esc(b) + #""},"action":{"type":"block"}}"#)
        }
        // 4) Ẩn khung quảng cáo ngay từ khi dựng trang
        let hide = ["#ad-stick-top-header", ".ad-top", "#banner_footer", "#countdown", "#wrap-ztop-banner",
                    "[id^='wrap-z']", "#lgh-ts247-btad", ".homepage-top-ads", ".homepage-bottom-ads",
                    ".ad_separator", ".adsbygoogle", ".decumar", ".cvi_banner_link", ".box-download-app",
                    ".dowloadApp", ".btn-download-top", "a[href*='tuyensinh247.com']", "a[href*='jupi.vn']",
                    "a[href*='decumar']"]
        let sel = hide.joined(separator: ", ").replacingOccurrences(of: "\"", with: "\\\"")
        rules.append(#"{"trigger":{"url-filter":".*"},"action":{"type":"css-display-none","selector":""# + sel + #""}}"#)
        let json = "[" + rules.joined(separator: ",") + "]"

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "loigiaihay-adshield-v1", encodedContentRuleList: json) { list, error in
            DispatchQueue.main.async {
                if let list = list { ucc.add(list) }
                if let error = error { NSLog("AdShield rules error: \(error)") }
                done()
            }
        }
    }
}
