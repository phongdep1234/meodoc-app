/* Mèo Đọc — điều hướng chương cho thanh dưới (Chương trước / Chọn chương / Chương sau).
 * Lấy danh sách chương từ trang hiện tại + trang giới thiệu truyện, sắp theo số chương,
 * rồi chuyển chương hoặc gửi danh sách về app để hiện bảng chọn. */
(function () {
  if (window.__cuuam) return;
  var ORIGIN = "https://meosss.com/";
  var RE = /^https?:\/\/(?:www\.)?meosss\.com\/truyen\/([^\/?#]+)(?:\/(chap-[^\/?#]+))?\/?(?:[?#].*)?$/i;
  var cache = {};

  function parse(u) {
    var m = RE.exec(u || "");
    return m ? { slug: m[1].toLowerCase(), chap: m[2] ? m[2].toLowerCase() : null } : null;
  }
  function num(chap) {
    var m = /chap-(\d+)(?:[-.](\d+))?/i.exec(chap || "");
    return m ? parseFloat(m[1] + (m[2] ? "." + m[2] : "")) : NaN;
  }
  function label(chap) {
    var m = /chap-(.+)$/i.exec(chap || "");
    return "Chương " + (m ? m[1].replace(/-/g, ".") : chap);
  }
  function send(obj) {
    var s = JSON.stringify(obj);
    if (window.CuuAmApp && window.CuuAmApp.onNav) window.CuuAmApp.onNav(s);
    else if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.cuuam)
      webkit.messageHandlers.cuuam.postMessage(s);
  }
  function detailUrl(slug) { return ORIGIN + "truyen/" + slug + "/"; }
  function add(map, slug, chap, extra) {
    chap = chap.toLowerCase();
    if (isNaN(num(chap))) return;
    var e = map[chap] || { c: chap, n: num(chap), u: detailUrl(slug) + chap + "/", t: label(chap) };
    if (extra) e.t = extra;
    map[chap] = e;
  }
  function collect(doc, base, slug, map) {
    var as = doc.querySelectorAll("a[href]");
    for (var i = 0; i < as.length; i++) {
      var href;
      try { href = new URL(as[i].getAttribute("href"), base).href; } catch (e) { continue; }
      var p = parse(href);
      if (p && p.slug === slug && p.chap) add(map, slug, p.chap);
    }
  }
  function getJSON(u) {
    return fetch(u, { credentials: "include" }).then(function (r) { return r.ok ? r.json() : null; })
      .catch(function () { return null; });
  }
  /* Danh sách đầy đủ qua API của trang: /wp-json/initmanga/v1/chapters?manga_id=…&paged=…&per_page=50 */
  function fromApi(id, slug, map) {
    var api = ORIGIN + "wp-json/initmanga/v1/chapters?manga_id=" + id + "&per_page=50&paged=";
    function page(n) {
      return getJSON(api + n).then(function (d) {
        if (!d || !d.items) return;
        d.items.forEach(function (it) {
          if (!it.slug) return;
          var t = label(it.slug) + (it.title ? " – " + it.title : "");
          if (it.lock_type && it.lock_type !== "none" && !it.is_purchased) t = "🔒 " + t;
          add(map, slug, it.slug, t);
        });
        if (d.total_pages && n < d.total_pages && n < 40) return page(n + 1);
      });
    }
    return page(1);
  }
  function chapters(slug) {
    if (cache[slug]) return Promise.resolve(cache[slug]);
    var map = {};
    collect(document, location.href, slug, map);
    return fetch(detailUrl(slug), { credentials: "include" })
      .then(function (r) { return r.ok ? r.text() : ""; })
      .catch(function () { return ""; })
      .then(function (html) {
        if (!html) return;
        collect(new DOMParser().parseFromString(html, "text/html"), detailUrl(slug), slug, map);
        var m = /wp-json\/wp\/v2\/manga\/(\d+)/.exec(html);
        if (m) return fromApi(m[1], slug, map);
      })
      .then(function () {
        var list = Object.keys(map).map(function (k) { return map[k]; });
        list.sort(function (a, b) { return b.n - a.n; });   // mới nhất ở trên
        if (list.length > 1) cache[slug] = list;
        return list;
      });
  }

  function run(action) {
    var cur = parse(location.href);
    if (!cur) return send({ type: "toast", text: "Hãy mở một truyện trước" });
    chapters(cur.slug).then(function (list) {
      if (!list.length) return send({ type: "toast", text: "Không tìm thấy danh sách chương" });
      var idx = -1;
      for (var i = 0; i < list.length; i++) if (list[i].c === cur.chap) { idx = i; break; }

      if (action === "list") {
        return send({
          type: "list",
          current: idx,
          items: list.map(function (x) { return { t: x.t, u: x.u }; })
        });
      }
      var target = null;
      if (idx < 0) {
        // Đang ở trang giới thiệu truyện: "Chương sau" = đọc từ chương đầu, "Chương trước" = chương mới nhất
        target = action === "next" ? list[list.length - 1] : list[0];
      } else if (action === "next") {
        if (idx === 0) return send({ type: "toast", text: "Đây là chương mới nhất" });
        target = list[idx - 1];
      } else {
        if (idx === list.length - 1) return send({ type: "toast", text: "Đây là chương đầu tiên" });
        target = list[idx + 1];
      }
      location.href = target.u;
    });
  }

  window.__cuuam = { run: run };
})();
