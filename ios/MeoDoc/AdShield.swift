import Foundation
import WebKit

/// Chặn quảng cáo: chỉ cho điều hướng trong meosss.com, chặn script/khung/popup từ máy chủ ngoài.
enum AdShield {

    /// Máy chủ được phép tải script/khung/dữ liệu (ngoài các máy chủ này chỉ cho tải ảnh, phông, CSS).
    static let allowed = ["meosss.com", "gravatar.com", "wp.com", "cloudflare.com",
                          "googleapis.com", "gstatic.com", "jsdelivr.net"]

    /// Từ khoá máy chủ quảng cáo / tiếp thị liên kết — chặn hoàn toàn.
    static let blocked = ["shopee", "shope.ee", "tiktok", "lazada", "lzd.co", "tiki.vn",
                          "doubleclick", "googlesyndication", "googleadservices", "adservice", "adnxs",
                          "popads", "popcash", "propellerads", "adsterra", "exoclick", "juicyads",
                          "trafficjunky", "hilltopads", "onclick", "clickadu", "adcash", "admaven",
                          "monetag", "a-ads", "taboola", "outbrain", "mgid", "revcontent", "yllix",
                          "galaksion", "richpartners", "pushground", "ad-maven", "zeropark", "bidvertiser",
                          "adsco.re", "pubfuture", "highperformanceformat", "profitablecpmrate",
                          "bit.ly", "tinyurl", "cutt.ly", "linkvertise"]

    static func isSite(_ host: String) -> Bool {
        host == "meosss.com" || host.hasSuffix(".meosss.com")
    }

    static func isAllowedHost(_ host: String) -> Bool {
        allowed.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Script chạy sớm trên mọi trang (chặn window.open, link ngoài, iframe quảng cáo).
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
        // 1) Chặn mọi script / khung / XHR / popup / media từ máy chủ ngoài
        rules.append(#"{"trigger":{"url-filter":".*","load-type":["third-party"],"resource-type":["script","raw","document","popup","media"]},"action":{"type":"block"}}"#)
        // 2) …trừ các máy chủ được phép
        for h in allowed {
            rules.append(#"{"trigger":{"url-filter":"^https?://[^/]*"# + esc(h) + #"[:/]"},"action":{"type":"ignore-previous-rules"}}"#)
        }
        // 3) Máy chủ quảng cáo: chặn tất cả, kể cả ảnh
        for b in blocked {
            rules.append(#"{"trigger":{"url-filter":"^https?://[^/]*"# + esc(b)
                         + #""},"action":{"type":"block"}}"#)
        }
        let json = "[" + rules.joined(separator: ",") + "]"

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "meodoc-adshield-v1", encodedContentRuleList: json) { list, error in
            DispatchQueue.main.async {
                if let list = list { ucc.add(list) }
                if let error = error { NSLog("AdShield rules error: \(error)") }
                done()
            }
        }
    }
}
