package com.phong.cuuam;

import android.content.Context;
import android.net.Uri;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Map;

/** Chặn quảng cáo: chỉ cho điều hướng trong truyenqq.com.vn và chặn tải tài nguyên từ máy chủ quảng cáo. */
final class AdShield {

    /** Máy chủ được phép tải script/khung/dữ liệu (ngoài các máy chủ này chỉ cho tải ảnh). */
    private static final String[] ALLOWED = {
            "truyenqq.com.vn", "gravatar.com", "wp.com", "cloudflare.com",
            "googleapis.com", "gstatic.com", "jsdelivr.net",
    };

    /** Máy chủ quảng cáo / tiếp thị liên kết — chặn hoàn toàn, kể cả ảnh. */
    private static final String[] BLOCKED = {
            "shopee", "shope.ee", "tiktok", "lazada", "lzd.co", "tiki.vn",
            "doubleclick", "googlesyndication", "googleadservices", "adservice", "adnxs",
            "popads", "popcash", "propellerads", "adsterra", "exoclick", "juicyads",
            "trafficjunky", "hilltopads", "onclick", "clickadu", "adcash", "admaven",
            "monetag", "a-ads", "taboola", "outbrain", "mgid", "revcontent", "yllix",
            "galaksion", "richpartners", "pushground", "ad-maven", "zeropark", "bidvertiser",
            "adsco.re", "pubfuture", "highperformanceformat", "profitablecpmrate",
            "bit.ly", "tinyurl", "cutt.ly", "shorten", "linkvertise",
    };

    private AdShield() { }

    static boolean isSite(String host) {
        if (host == null) return false;
        String h = host.toLowerCase(Locale.ROOT);
        return h.equals("truyenqq.com.vn") || h.endsWith(".truyenqq.com.vn");
    }

    private static boolean isAllowedHost(String host) {
        if (host == null) return false;
        String h = host.toLowerCase(Locale.ROOT);
        for (String a : ALLOWED) if (h.equals(a) || h.endsWith("." + a)) return true;
        return false;
    }

    private static boolean isAdHost(String host) {
        if (host == null) return false;
        String h = host.toLowerCase(Locale.ROOT);
        for (String b : BLOCKED) if (h.contains(b)) return true;
        return false;
    }

    /** Điều hướng trang (link, chuyển hướng, window.open) chỉ được ở lại truyenqq.com.vn. */
    static boolean isAllowedNavigation(Uri u) {
        String scheme = u.getScheme();
        if (!"http".equals(scheme) && !"https".equals(scheme)) return false;   // intent://, tiktok://, market://…
        return isSite(u.getHost()) || "challenges.cloudflare.com".equals(u.getHost());
    }

    static boolean shouldBlock(WebResourceRequest req) {
        Uri u = req.getUrl();
        String host = u.getHost();
        String scheme = u.getScheme();
        if (!"http".equals(scheme) && !"https".equals(scheme)) return false;
        if (isAdHost(host)) return true;
        if (isAllowedHost(host)) return false;
        // Khung con hoặc trang chính trỏ ra ngoài → chặn (iframe quảng cáo)
        if (req.isForMainFrame()) return false;   // đã xử lý ở shouldOverrideUrlLoading
        // Ngoài danh sách cho phép: chỉ để ảnh/phông đi qua, chặn script, iframe, XHR…
        return !isImageOrFont(req);
    }

    private static boolean isImageOrFont(WebResourceRequest req) {
        String path = req.getUrl().getPath();
        if (path != null && path.toLowerCase(Locale.ROOT)
                .matches(".*\\.(jpe?g|png|gif|webp|avif|bmp|svg|ico|woff2?|ttf|otf)$")) return true;
        Map<String, String> h = req.getRequestHeaders();
        if (h != null) {
            for (Map.Entry<String, String> e : h.entrySet()) {
                if ("accept".equalsIgnoreCase(e.getKey()) && e.getValue() != null
                        && e.getValue().startsWith("image/")) return true;
            }
        }
        return false;
    }

    static WebResourceResponse empty() {
        return new WebResourceResponse("text/plain", "utf-8",
                new ByteArrayInputStream(new byte[0]));
    }

    static String loadScript(Context c, String name) {
        try (InputStream in = c.getAssets().open(name)) {
            byte[] b = new byte[in.available()];
            int n = in.read(b);
            return new String(b, 0, Math.max(n, 0), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "";
        }
    }
}
