package com.phong.loigiaihay;

import android.content.Context;
import android.net.Uri;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Map;

/** Chặn quảng cáo cho loigiaihay.com: chặn máy chủ quảng cáo, chỉ cho script/khung từ máy chủ tin cậy. */
final class AdShield {

    /** Máy chủ được phép tải script/khung/dữ liệu. Máy chủ khác chỉ được tải ảnh, phông, CSS. */
    private static final String[] ALLOWED = {
            "loigiaihay.com", "googleapis.com", "gstatic.com", "cloudflare.com", "jsdelivr.net",
            "quizlet.com", "youtube.com", "youtube-nocookie.com", "ytimg.com", "googlevideo.com",
            "facebook.com", "facebook.net", "fbcdn.net", "firebaseio.com", "firebaseapp.com",
            "recaptcha.net", "mathjax.org", "jquery.com",
    };

    /** Máy chủ quảng cáo / theo dõi / quảng bá — chặn hoàn toàn, kể cả ảnh. */
    private static final String[] BLOCKED = {
            "tuyensinh247", "jupi.vn", "decumar", "ladicdn", "ladipage",
            "adservingz", "zmedia", "admicro", "vcmedia", "vccorp", "eclick", "adtima", "zadn.vn",
            "sp.zalo.me", "vliplatform", "yomedia", "ambientdsp", "clickmon", "novanet", "ants.vn",
            "googlesyndication", "doubleclick", "googleadservices", "adservice.google", "googletagmanager",
            "googletagservices", "google-analytics", "imasdk.googleapis", "pagead", "adnxs", "adsrvr",
            "criteo", "pubmatic", "rubiconproject", "openx", "taboola", "outbrain", "mgid", "amazon-adsystem",
            "dmca.com", "connect.facebook.net/en_US/fbevents", "shopee", "lazada", "tiki.vn", "tiktok",
    };

    private AdShield() { }

    static boolean isSite(String host) {
        if (host == null) return false;
        String h = host.toLowerCase(Locale.ROOT);
        return h.equals("loigiaihay.com") || h.endsWith(".loigiaihay.com");
    }

    private static boolean isAllowedHost(String host) {
        if (host == null) return false;
        String h = host.toLowerCase(Locale.ROOT);
        for (String a : ALLOWED) if (h.equals(a) || h.endsWith("." + a)) return true;
        return false;
    }

    static boolean isAd(Uri u) {
        if (u == null) return false;
        String s = u.toString().toLowerCase(Locale.ROOT);
        for (String b : BLOCKED) if (s.contains(b)) return true;
        return false;
    }

    /** Trang đăng nhập Google/Facebook/Apple được mở ngay trong app. */
    static boolean isLogin(String host) {
        if (host == null) return false;
        String h = host.toLowerCase(Locale.ROOT);
        return h.equals("accounts.google.com") || h.endsWith(".facebook.com") || h.equals("facebook.com")
                || h.equals("appleid.apple.com");
    }

    static boolean shouldBlock(WebResourceRequest req) {
        Uri u = req.getUrl();
        String scheme = u.getScheme();
        if (!"http".equals(scheme) && !"https".equals(scheme)) return false;
        if (isAd(u)) return true;
        String host = u.getHost();
        if (isSite(host) || isAllowedHost(host)) return false;
        if (req.isForMainFrame()) return false;   // điều hướng trang đã xử lý ở shouldOverrideUrlLoading
        // Ngoài danh sách tin cậy: chỉ cho ảnh/phông/CSS, chặn script, iframe, XHR, video…
        return !isPassive(req);
    }

    private static boolean isPassive(WebResourceRequest req) {
        String path = req.getUrl().getPath();
        if (path != null && path.toLowerCase(Locale.ROOT)
                .matches(".*\\.(jpe?g|png|gif|webp|avif|bmp|svg|ico|woff2?|ttf|otf|eot|css)$")) return true;
        Map<String, String> h = req.getRequestHeaders();
        if (h != null) {
            for (Map.Entry<String, String> e : h.entrySet()) {
                if ("accept".equalsIgnoreCase(e.getKey()) && e.getValue() != null
                        && (e.getValue().startsWith("image/") || e.getValue().startsWith("text/css"))) return true;
            }
        }
        return false;
    }

    static WebResourceResponse empty() {
        return new WebResourceResponse("text/plain", "utf-8",
                new ByteArrayInputStream(new byte[0]));
    }

    static String loadScript(Context c) {
        try (InputStream in = c.getAssets().open("adshield.js")) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            return out.toString(StandardCharsets.UTF_8.name());
        } catch (Exception e) {
            return "";
        }
    }
}
