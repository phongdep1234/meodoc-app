import UIKit
import WebKit

/// Mèo Đọc — trình duyệt riêng cho meosss.com.
/// Tải trang gốc trong WKWebView (đăng nhập, thư viện, mở khoá… vẫn do web xử lý),
/// thêm thanh điều hướng, vuốt để quay lại, kéo để tải lại, chế độ đọc toàn màn hình.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private let host = "meosss.com"
    private let home = URL(string: "https://meosss.com/")!
    private let brand = UIColor(red: 0x4B/255, green: 0x15/255, blue: 0x35/255, alpha: 1)
    private let barBg = UIColor(red: 0x1A/255, green: 0x0A/255, blue: 0x13/255, alpha: 0.96)
    private let accent = UIColor(red: 1, green: 0x7A/255, blue: 0xB6/255, alpha: 1)
    private let barText = UIColor(red: 0xF3/255, green: 0xDC/255, blue: 0xE8/255, alpha: 1)

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
        ("house.fill", "Trang chủ", "https://meosss.com/"),
        ("sparkles", "Mới", "https://meosss.com/moi-cap-nhat/"),
        ("heart.fill", "Thư viện", "https://meosss.com/thu-vien-cua-toi/"),
        ("clock.fill", "Lịch sử", "https://meosss.com/lich-su-doc/"),
        ("chevron.backward", "Quay lại", nil),
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

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0x1A/255, green: 0x0A/255, blue: 0x13/255, alpha: 1)
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
        if let s = tabs[b.tag].url, let u = URL(string: s) {
            webView.load(URLRequest(url: u))
        } else if webView.canGoBack {
            webView.goBack()
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
        let isChapter = s.range(of: #"^https?://(www\.)?meosss\.com/truyen/[^/]+/chap[^/]*"#,
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
        if dy > 12 && y > 40 { setBarHidden(true) }
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
            // Chỉ ở lại meosss.com; mọi chuyển hướng quảng cáo ra ngoài bị bỏ qua
            decisionHandler(AdShield.isSite(h) || h == "challenges.cloudflare.com" ? .allow : .cancel)
        } else {
            decisionHandler(AdShield.isAllowedHost(h) ? .allow : .cancel)
        }
    }

    // Popup / target=_blank: chỉ mở nếu là trang trong meosss.com (mở ngay trong app)
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
