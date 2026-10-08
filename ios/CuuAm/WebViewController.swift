import UIKit
import WebKit

/// Cửu Âm Chân Kinh — trình duyệt riêng cho truyenqq.com.vn.
/// Tải trang gốc trong WKWebView (đăng nhập, thư viện, mở khoá… vẫn do web xử lý),
/// thêm thanh điều hướng, vuốt để quay lại, kéo để tải lại, chế độ đọc toàn màn hình.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private let host = "truyenqq.com.vn"
    private let home = URL(string: "https://truyenqq.com.vn/")!
    private let brand = UIColor(red: 0x24/255, green: 0x3A/255, blue: 0x70/255, alpha: 1)
    private let barBg = UIColor(red: 0x20/255, green: 0x18/255, blue: 0x12/255, alpha: 0.96)
    private let accent = UIColor(red: 0xE0/255, green: 0xB4/255, blue: 0x60/255, alpha: 1)
    private let barText = UIColor(red: 0xF3/255, green: 0xEA/255, blue: 0xD6/255, alpha: 1)

    private var webView: WKWebView!
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let bar = UIStackView()
    private var barBottom: NSLayoutConstraint!
    private var tabButtons: [UIButton] = []
    private var reading = false
    private var barHidden = false
    private var lastY: CGFloat = 0
    private var observers: [NSKeyValueObservation] = []

    private let tabs: [(icon: String, title: String, url: String?)] = [
        ("house.fill", "Trang chủ", "https://truyenqq.com.vn/"),
        ("chevron.left.circle.fill", "Chương trước", "@prev"),
        ("list.bullet.rectangle.fill", "Chọn chương", "@list"),
        ("chevron.right.circle.fill", "Chương sau", "@next"),
    ]

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersStatusBarHidden: Bool { reading }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .slide }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = brand

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // giữ cookie đăng nhập
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        if let js = AdShield.script {
            config.userContentController.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        if let u = Bundle.main.url(forResource: "chapnav", withExtension: "js"),
           let js = try? String(contentsOf: u, encoding: .utf8) {
            config.userContentController.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        config.userContentController.add(NavMessageProxy(self), name: "cuuam")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0x14/255, green: 0x10/255, blue: 0x0C/255, alpha: 1)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        let refresh = UIRefreshControl()
        refresh.tintColor = accent
        refresh.addTarget(self, action: #selector(pullRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        progress.progressTintColor = accent
        progress.trackTintColor = .clear
        progress.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progress)

        buildBar()

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: 3),
        ])

        observers.append(webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
            guard let self = self else { return }
            self.progress.setProgress(Float(wv.estimatedProgress), animated: true)
            self.progress.isHidden = wv.estimatedProgress >= 1
        })
        observers.append(webView.scrollView.observe(\.contentOffset, options: .new) { [weak self] sv, _ in
            self?.didScroll(sv)
        })
        observers.append(webView.observe(\.url, options: .new) { [weak self] wv, _ in
            self?.updateMode(wv.url)
        })

        let last = UserDefaults.standard.string(forKey: "last").flatMap(URL.init(string:)) ?? home
        AdShield.installRules(into: config.userContentController) { [weak self] in
            self?.webView.load(URLRequest(url: last))
        }
    }

    private func buildBar() {
        let bg = UIView()
        bg.backgroundColor = barBg
        bg.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bg)

        bar.axis = .horizontal
        bar.distribution = .fillEqually
        bar.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(bar)

        for (i, t) in tabs.enumerated() {
            var cfg = UIButton.Configuration.plain()
            cfg.image = UIImage(systemName: t.icon,
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
            cfg.title = t.title
            cfg.imagePlacement = .top
            cfg.imagePadding = 3
            cfg.baseForegroundColor = barText
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
                var a = a; a.font = .systemFont(ofSize: 10, weight: .semibold); return a
            }
            let b = UIButton(configuration: cfg)
            b.tag = i
            b.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabButtons.append(b)
            bar.addArrangedSubview(b)
        }

        barBottom = bg.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barBottom,
            bar.topAnchor.constraint(equalTo: bg.topAnchor),
            bar.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 54),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    @objc private func tabTapped(_ b: UIButton) {
        guard let s = tabs[b.tag].url else { return }
        if s.hasPrefix("@") {
            let action = String(s.dropFirst())
            webView.evaluateJavaScript("window.__cuuam && window.__cuuam.run('\(action)')", completionHandler: nil)
        } else if let u = URL(string: s) {
            webView.load(URLRequest(url: u))
        }
    }

    // MARK: - Chương trước / Chọn chương / Chương sau

    fileprivate func handleNav(_ json: String) {
        guard let data = json.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        switch o["type"] as? String {
        case "toast":
            toast(o["text"] as? String ?? "")
        case "list":
            let items = (o["items"] as? [[String: String]] ?? []).map { ($0["t"] ?? "", $0["u"] ?? "") }
            let picker = ChapterPicker(items: items, current: o["current"] as? Int ?? -1) { [weak self] url in
                if let u = URL(string: url) { self?.webView.load(URLRequest(url: u)) }
            }
            let nav = UINavigationController(rootViewController: picker)
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            present(nav, animated: true)
        default: break
        }
    }

    private func toast(_ text: String) {
        let l = PaddedLabel()
        l.text = text
        l.textColor = barText
        l.backgroundColor = barBg
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.layer.cornerRadius = 10
        l.clipsToBounds = true
        l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(l)
        NSLayoutConstraint.activate([
            l.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            l.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -70),
        ])
        UIView.animate(withDuration: 0.2, animations: { l.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.6, options: [], animations: { l.alpha = 0 }) { _ in
                l.removeFromSuperview()
            }
        }
    }

    @objc private func pullRefresh(_ rc: UIRefreshControl) {
        webView.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { rc.endRefreshing() }
    }

    // MARK: - Chế độ đọc

    private func updateMode(_ url: URL?) {
        let s = url?.absoluteString ?? ""
        let path = s.components(separatedBy: CharacterSet(charactersIn: "?#")).first ?? s
        for (i, b) in tabButtons.enumerated() where tabs[i].url != nil {
            b.configuration?.baseForegroundColor = (path == tabs[i].url) ? accent : barText
        }
        let isChapter = s.range(of: #"^https?://(www\.)?truyenqq\.com\.vn/[^/]+/chapter-[^/]*"#,
                                options: .regularExpression) != nil
        guard isChapter != reading else { return }
        reading = isChapter
        UIApplication.shared.isIdleTimerDisabled = reading      // giữ màn hình sáng khi đọc
        UIView.animate(withDuration: 0.25) { self.setNeedsStatusBarAppearanceUpdate() }
        if !reading { setBarHidden(false) }
    }

    private func setBarHidden(_ hide: Bool) {
        guard hide != barHidden else { return }
        barHidden = hide
        barBottom.constant = hide ? 54 + view.safeAreaInsets.bottom : 0
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    private func didScroll(_ sv: UIScrollView) {
        let y = sv.contentOffset.y
        let dy = y - lastY
        let atBottom = y + sv.bounds.height >= sv.contentSize.height - 30
        if atBottom && sv.contentSize.height > sv.bounds.height { setBarHidden(false) }   // cuối chương → hiện thanh
        else if dy > 12 && y > 40 { setBarHidden(true) }
        else if dy < -12 || y < 40 { setBarHidden(false) }
        lastY = y
    }

    // MARK: - Điều hướng

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "about" || scheme == "blob" || scheme == "data" { return decisionHandler(.allow) }
        // tiktok://, shopee://, itms-apps://… → không bao giờ mở app khác
        guard scheme == "http" || scheme == "https" else { return decisionHandler(.cancel) }
        let h = (url.host ?? "").lowercased()
        let mainFrame = action.targetFrame?.isMainFrame ?? true
        if mainFrame {
            // Chỉ ở lại truyenqq.com.vn; mọi chuyển hướng quảng cáo ra ngoài bị bỏ qua
            decisionHandler(AdShield.isSite(h) || h == "challenges.cloudflare.com" ? .allow : .cancel)
        } else {
            decisionHandler(AdShield.isAllowedHost(h) ? .allow : .cancel)
        }
    }

    // Popup / target=_blank: chỉ mở nếu là trang trong truyenqq.com.vn (mở ngay trong app)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = action.request.url, AdShield.isSite((u.host ?? "").lowercased()) {
            webView.load(URLRequest(url: u))
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let u = webView.url, (u.host ?? "").hasSuffix(host) {
            UserDefaults.standard.set(u.absoluteString, forKey: "last")
        }
        updateMode(webView.url)
    }

    // Hộp thoại JS (alert/confirm) của trang
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }
}


/// Nhận tin nhắn từ chapnav.js (giữ tham chiếu yếu để tránh vòng giữ bộ nhớ).
private final class NavMessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: WebViewController?
    init(_ owner: WebViewController) { self.owner = owner }
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        if let s = message.body as? String { owner?.handleNav(s) }
    }
}

/// Bảng chọn chương (mới nhất ở trên, cuộn sẵn tới chương đang đọc).
private final class ChapterPicker: UITableViewController {
    private let items: [(String, String)]
    private let current: Int
    private let onPick: (String) -> Void

    init(items: [(String, String)], current: Int, onPick: @escaping (String) -> Void) {
        self.items = items; self.current = current; self.onPick = onPick
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chọn chương (\(items.count))"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if current >= 0 && current < items.count {
            tableView.scrollToRow(at: IndexPath(row: current, section: 0), at: .middle, animated: false)
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    override func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = tv.dequeueReusableCell(withIdentifier: "c", for: ip)
        var cfg = c.defaultContentConfiguration()
        cfg.text = items[ip.row].0
        let isCur = ip.row == current
        cfg.textProperties.font = .systemFont(ofSize: 16, weight: isCur ? .bold : .regular)
        cfg.textProperties.color = isCur ? .systemOrange : .label
        c.contentConfiguration = cfg
        c.accessoryType = isCur ? .checkmark : .none
        return c
    }

    override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        let url = items[ip.row].1
        dismiss(animated: true) { [onPick] in onPick(url) }
    }
}

private final class PaddedLabel: UILabel {
    override func drawText(in rect: CGRect) { super.drawText(in: rect.insetBy(dx: 14, dy: 8)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize; return CGSize(width: s.width + 28, height: s.height + 16)
    }
}
