import UIKit
import WebKit

/// Lời giải hay — trình duyệt riêng cho loigiaihay.com, đã loại bỏ quảng cáo.
/// Trang gốc tải trong WKWebView; quảng cáo bị chặn bằng bộ lọc mạng của WebKit,
/// CSS ẩn khung quảng cáo và script gỡ link/ảnh/iframe/video quảng cáo.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private let home = URL(string: "https://loigiaihay.com/")!
    private let blue = UIColor(red: 0x15/255, green: 0x65/255, blue: 0xC0/255, alpha: 1)
    private let blueDark = UIColor(red: 0x0D/255, green: 0x47/255, blue: 0xA1/255, alpha: 1)
    private let accent = UIColor(red: 0x42/255, green: 0xA5/255, blue: 0xF5/255, alpha: 1)
    private let dim = UIColor(red: 0x90/255, green: 0xCA/255, blue: 0xF9/255, alpha: 1)

    private var webView: WKWebView!
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let bar = UIStackView()
    private var barBottom: NSLayoutConstraint!
    private var backButton: UIButton!
    private var fwdButton: UIButton!
    private var barHidden = false
    private var lastY: CGFloat = 0
    private var observers: [NSKeyValueObservation] = []

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = blueDark

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // giữ cookie đăng nhập
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all   // không tự phát video/âm thanh
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        if let js = AdShield.script {
            config.userContentController.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .white
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        let refresh = UIRefreshControl()
        refresh.tintColor = blue
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
        observers.append(webView.observe(\.canGoBack, options: .new) { [weak self] _, _ in self?.updateNav() })
        observers.append(webView.observe(\.canGoForward, options: .new) { [weak self] _, _ in self?.updateNav() })

        let last = UserDefaults.standard.string(forKey: "last").flatMap(URL.init(string:)) ?? home
        AdShield.installRules(into: config.userContentController) { [weak self] in
            self?.webView.load(URLRequest(url: last))
        }
        updateNav()
    }

    private func buildBar() {
        let bg = UIView()
        bg.backgroundColor = blue
        bg.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bg)

        bar.axis = .horizontal
        bar.distribution = .fillEqually
        bar.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(bar)

        backButton = makeButton("chevron.backward", "Quay lại", #selector(goBack))
        _ = makeButton("house.fill", "Trang chủ", #selector(goHome))
        _ = makeButton("arrow.clockwise", "Tải lại", #selector(reload))
        _ = makeButton("arrow.up.to.line", "Lên đầu", #selector(toTop))
        fwdButton = makeButton("chevron.forward", "Tiến", #selector(goForward))

        barBottom = bg.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barBottom,
            bar.topAnchor.constraint(equalTo: bg.topAnchor),
            bar.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 52),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func makeButton(_ icon: String, _ title: String, _ action: Selector) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: icon,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        cfg.title = title
        cfg.imagePlacement = .top
        cfg.imagePadding = 3
        cfg.baseForegroundColor = .white
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = .systemFont(ofSize: 10, weight: .semibold); return a
        }
        let b = UIButton(configuration: cfg)
        b.addTarget(self, action: action, for: .touchUpInside)
        bar.addArrangedSubview(b)
        return b
    }

    @objc private func goBack() { if webView.canGoBack { webView.goBack() } }
    @objc private func goForward() { if webView.canGoForward { webView.goForward() } }
    @objc private func goHome() { webView.load(URLRequest(url: home)) }
    @objc private func reload() { webView.reload() }
    @objc private func toTop() {
        webView.scrollView.setContentOffset(CGPoint(x: 0, y: -webView.scrollView.adjustedContentInset.top), animated: true)
    }

    @objc private func pullRefresh(_ rc: UIRefreshControl) {
        webView.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { rc.endRefreshing() }
    }

    private func updateNav() {
        backButton?.configuration?.baseForegroundColor = webView.canGoBack ? .white : dim
        fwdButton?.configuration?.baseForegroundColor = webView.canGoForward ? .white : dim
    }

    private func setBarHidden(_ hide: Bool) {
        guard hide != barHidden else { return }
        barHidden = hide
        barBottom.constant = hide ? 52 + view.safeAreaInsets.bottom : 0
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    private func didScroll(_ sv: UIScrollView) {
        let y = sv.contentOffset.y
        let dy = y - lastY
        if dy > 12 && y > 60 { setBarHidden(true) }
        else if dy < -12 || y < 60 { setBarHidden(false) }
        lastY = y
    }

    // MARK: - Điều hướng

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "about" || scheme == "blob" || scheme == "data" { return decisionHandler(.allow) }
        // itms-apps://, zalo://, intent://… → không mở app khác
        guard scheme == "http" || scheme == "https" else { return decisionHandler(.cancel) }
        if AdShield.isAd(url) { return decisionHandler(.cancel) }          // link quảng cáo → bỏ qua
        let h = (url.host ?? "").lowercased()
        let mainFrame = action.targetFrame?.isMainFrame ?? true
        if !mainFrame { return decisionHandler(AdShield.isAllowedHost(h) ? .allow : .cancel) }
        if AdShield.isSite(h) || AdShield.isLogin(h) { return decisionHandler(.allow) }
        // Link ngoài khác: chỉ mở bằng Safari khi người dùng tự bấm
        if action.navigationType == .linkActivated { UIApplication.shared.open(url) }
        decisionHandler(.cancel)
    }

    // target=_blank: trang trong loigiaihay.com mở ngay trong app, còn lại bỏ qua
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = action.request.url, !AdShield.isAd(u) {
            let h = (u.host ?? "").lowercased()
            if AdShield.isSite(h) || AdShield.isLogin(h) { webView.load(URLRequest(url: u)) }
            else if action.navigationType == .linkActivated { UIApplication.shared.open(u) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let u = webView.url, AdShield.isSite((u.host ?? "").lowercased()) {
            UserDefaults.standard.set(u.absoluteString, forKey: "last")
        }
        updateNav()
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
