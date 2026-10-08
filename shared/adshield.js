/* Cửu Âm Chân Kinh — lá chắn quảng cáo, chạy sớm nhất có thể trên mọi trang.
 * Chỉ giữ truyenqq.com.vn: chặn popup/redirect sang trang ngoài, link "phủ trong suốt",
 * iframe quảng cáo và các link/banner trỏ ra ngoài. */
(function () {
  if (window.__meoShield) return;
  window.__meoShield = true;

  var OK = /(^|\.)(truyenqq\.com\.vn|gravatar\.com|wp\.com|cloudflare\.com|googleapis\.com|gstatic\.com|jsdelivr\.net)$/i;

  function hostOf(u) {
    try { return new URL(u, location.href).hostname; } catch (e) { return ""; }
  }
  function isSite(u) {
    if (!u) return true;
    var s = String(u).trim();
    if (/^(javascript:|#|data:|blob:|about:)/i.test(s)) return true;
    if (!/^https?:|^\/\//i.test(s) && !/^[a-z][a-z0-9+.-]*:/i.test(s)) return true; // đường dẫn tương đối
    if (!/^https?:|^\/\//i.test(s)) return false;                                   // tiktok://, intent:, shopee://…
    return OK.test(hostOf(s));
  }

  // 1) window.open: chỉ cho mở trang trong truyenqq.com.vn (mở ngay trong app)
  var realOpen = window.open;
  window.open = function (u) {
    if (u && isSite(u)) { location.href = new URL(u, location.href).href; }
    return null;
  };
  try { Object.defineProperty(window, "open", { value: window.open, writable: false, configurable: false }); } catch (e) {}

  // 2) Click vào link ngoài (kể cả lớp link phủ trong suốt) → bỏ qua
  function guard(ev) {
    var a = ev.target && ev.target.closest ? ev.target.closest("a[href]") : null;
    if (a && !isSite(a.getAttribute("href"))) {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      return false;
    }
    if (a && a.target && a.target !== "_self") a.target = "_self";
  }
  ["click", "auxclick", "mousedown", "touchend", "pointerup"].forEach(function (t) {
    window.addEventListener(t, guard, true);
  });

  // 3) Dọn phần tử quảng cáo: iframe ngoài, link ngoài, lớp phủ toàn màn hình trỏ ra ngoài
  function clean(root) {
    if (!root || !root.querySelectorAll) return;
    root.querySelectorAll("iframe, frame, embed, object").forEach(function (f) {
      var src = f.getAttribute("src") || f.getAttribute("data") || "";
      if (src && !isSite(src)) f.remove();
    });
    root.querySelectorAll("a[href]").forEach(function (a) {
      if (!isSite(a.getAttribute("href"))) {
        a.removeAttribute("href");
        a.style.pointerEvents = "none";
        if (a.querySelector("img, video, iframe") || /fixed|absolute/.test(getComputedStyle(a).position)) {
          a.style.display = "none";
        }
      }
    });
    root.querySelectorAll("form[action]").forEach(function (f) {
      if (!isSite(f.getAttribute("action"))) f.remove();
    });
  }
  new MutationObserver(function (ms) {
    ms.forEach(function (m) {
      m.addedNodes.forEach(function (n) {
        if (n.nodeType !== 1) return;
        if (/^(IFRAME|FRAME|EMBED|OBJECT|A|FORM)$/.test(n.tagName)) clean(n.parentNode || document);
        else clean(n);
      });
      if (m.type === "attributes") clean(m.target.parentNode || document);
    });
  }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["href", "src"] });
  document.addEventListener("DOMContentLoaded", function () { clean(document); });
  clean(document);
})();
