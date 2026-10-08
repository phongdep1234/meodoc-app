/* Lời giải hay — lá chắn quảng cáo, chạy sớm nhất có thể trên mọi trang loigiaihay.com.
 * 1) Ẩn ngay các khung quảng cáo bằng CSS (banner dính đầu trang, popup, đồng hồ đếm ngược,
 *    khung ZMedia/Admicro/Google, nút "Tải app"…).
 * 2) Gỡ link/ảnh/iframe/video trỏ tới máy chủ quảng cáo khi trang tải và khi trang chèn thêm.
 * 3) Chặn window.open / popup quảng cáo. */
(function () {
  if (window.__lghShield) return;
  window.__lghShield = true;

  var AD = /(tuyensinh247|jupi\.vn|decumar|ladicdn|ladipage|adservingz|zmedia|admicro|vcmedia\.vn\/ads|googlesyndication|doubleclick|googleadservices|adservice\.google|imasdk|adnxs|taboola|outbrain|mgid|eclick|vliplatform|adtima|yomedia|ambientdsp|clickmon|criteo|pubmatic|apple\.co\/|apps\.apple\.com|play\.google\.com\/store|shopee|lazada|tiki\.vn|tiktok)/i;
  var SITE = /(^|\.)loigiaihay\.com$/i;

  // ---------- 1) CSS ẩn quảng cáo ----------
  var CSS = [
    "#ad-stick-top-header", ".ad-top", "#banner_footer", "#countdown", "#wrap-ztop-banner",
    "[id^='wrap-z']", "[id*='loigiaihaycom-']", "[id*='ts247']", "[class*='ts247']",
    ".homepage-top-ads", ".homepage-bottom-ads", ".ad_separator", "ins.adsbygoogle", ".adsbygoogle",
    ".decumar", ".cvi_banner_link", "[data-tp-cat*='banner']", ".box-download-app", ".dowloadApp",
    ".btn-download-top", "#btn-close-ad",
    "a[href*='tuyensinh247.com']", "a[href*='jupi.vn']", "a[href*='decumar']", "a[href*='apple.co/']",
    "a[href*='apps.apple.com']", "a[href*='play.google.com/store']",
    "iframe[src*='googletagmanager']", "iframe[src*='doubleclick']", "iframe[src*='adservingz']",
    "iframe[src*='admicro']", "iframe[id^='google_ads']", "div[id^='google_ads']",
    "div[id^='admzone']", "div[id^='adm-slot']", "zone", "[id^='zone-']",
    "img[src*='tuyensinh247']", "img[src*='ladicdn']"
  ].join(",") + "{display:none!important;visibility:hidden!important;height:0!important;min-height:0!important;margin:0!important;padding:0!important}" +
    "header.sticky{top:0!important}" +
    "#ad-stick-top-header~header.sticky{top:0!important}" +
    "body{padding-top:0!important}" +
    "html,body{overflow-x:hidden}" +
    // :has() để riêng — trình duyệt cũ không hiểu thì chỉ bỏ qua dòng này
    "li:has(> .btn-download-top),p:has(> a[href*='tuyensinh247.com']),div:has(> a[href*='tuyensinh247.com'] > img){display:none!important}";

  function addStyle() {
    var root = document.head || document.documentElement;
    if (!root || document.getElementById("lgh-shield-css")) return;
    var st = document.createElement("style");
    st.id = "lgh-shield-css";
    st.textContent = CSS;
    root.appendChild(st);
  }
  addStyle();

  // Trang tự kiểm tra cookie trước khi hiện đồng hồ đếm ngược / banner → đặt sẵn "đã đóng"
  try {
    var exp = "; path=/; max-age=31536000";
    document.cookie = "close_countdown=1" + exp;
    document.cookie = "close_top_banner=1" + exp;
    document.cookie = "showTopBanner=1" + exp;
  } catch (e) {}

  // ---------- 2) Chặn popup ----------
  function hostOf(u) {
    try { return new URL(u, location.href).hostname; } catch (e) { return ""; }
  }
  function isAd(u) {
    if (!u) return false;
    return AD.test(String(u));
  }
  window.open = function (u) {
    if (u && SITE.test(hostOf(u))) location.href = new URL(u, location.href).href;
    return null;
  };

  // Click vào link quảng cáo → bỏ qua; link trong trang mở ngay trong app
  function guard(ev) {
    var a = ev.target && ev.target.closest ? ev.target.closest("a[href]") : null;
    if (!a) return;
    var href = a.getAttribute("href") || "";
    if (isAd(href) || /^(intent|market|itms|itms-apps|zalo|fb):/i.test(href)) {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      return false;
    }
    if (a.target && a.target !== "_self" && SITE.test(hostOf(href))) a.target = "_self";
  }
  ["click", "auxclick", "touchend"].forEach(function (t) {
    window.addEventListener(t, guard, true);
  });

  // ---------- 3) Gỡ phần tử quảng cáo ----------
  function kill(el) {
    if (!el || !el.parentNode) return;
    // Gỡ luôn khung bọc nếu khung chỉ chứa quảng cáo
    var p = el.parentNode;
    el.remove();
    if (p && p !== document.body && p.nodeType === 1 && !p.textContent.trim() &&
        !p.querySelector("img,video,iframe,canvas,svg,input,button")) {
      p.style.display = "none";
    }
  }
  function clean(root) {
    if (!root || !root.querySelectorAll) return;
    addStyle();
    root.querySelectorAll("iframe, frame, embed, object, video, source, script[src]").forEach(function (f) {
      var src = f.getAttribute("src") || f.getAttribute("data") || "";
      if (isAd(src)) kill(f.tagName === "SOURCE" ? f.parentNode : f);
    });
    root.querySelectorAll("a[href]").forEach(function (a) {
      if (isAd(a.getAttribute("href"))) {
        var box = a.closest("p, li, figure") || a;
        kill(box.textContent.trim().length > 200 ? a : box);
      }
    });
    root.querySelectorAll("img[src]").forEach(function (img) {
      if (isAd(img.getAttribute("src"))) kill(img);
    });
    root.querySelectorAll("ins.adsbygoogle, [id*='loigiaihaycom-'], #lgh-ts247-btad, #countdown, #banner_footer, #ad-stick-top-header").forEach(kill);
  }

  var pending = false;
  function schedule() {
    if (pending) return;
    pending = true;
    (window.requestAnimationFrame || setTimeout)(function () { pending = false; clean(document); });
  }
  try {
    // Theo dõi cả document (lúc chạy có thể chưa có thẻ <html>) để gắn CSS sớm nhất
    new MutationObserver(function () { addStyle(); schedule(); }).observe(document, {
      childList: true, subtree: true, attributes: true, attributeFilter: ["href", "src"]
    });
  } catch (e) {}
  document.addEventListener("DOMContentLoaded", function () { clean(document); });
  window.addEventListener("load", function () { clean(document); });
  clean(document);
})();
