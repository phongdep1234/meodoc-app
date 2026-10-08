package com.phong.loigiaihay;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;

import java.util.Collections;

/**
 * Lời giải hay — trình duyệt riêng cho loigiaihay.com, đã loại bỏ quảng cáo.
 * Trang gốc tải trong WebView; quảng cáo bị chặn ở 3 lớp: chặn máy chủ quảng cáo,
 * ẩn khung quảng cáo bằng CSS và gỡ link/ảnh/iframe/video quảng cáo bằng script.
 */
public class MainActivity extends Activity {

    private static final String HOME = "https://loigiaihay.com/";
    private static final int FILE_REQ = 42;

    private static final int BLUE = Color.parseColor("#1565C0");
    private static final int BLUE_DARK = Color.parseColor("#0D47A1");
    private static final int BAR_TEXT = Color.parseColor("#FFFFFF");
    private static final int BAR_DIM = Color.parseColor("#90CAF9");

    private WebView web;
    private ProgressBar progress;
    private LinearLayout bottomBar;
    private TextView backTab, fwdTab;
    private SharedPreferences prefs;
    private ValueCallback<Uri[]> fileCallback;
    private String shieldJs = "";
    private boolean docStartJs = false;
    private boolean barHidden = false;
    private long lastBack = 0;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences("loigiaihay", MODE_PRIVATE);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.WHITE);

        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(-1, -1));

        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        progress.setProgressTintList(android.content.res.ColorStateList.valueOf(Color.parseColor("#42A5F5")));
        root.addView(progress, new FrameLayout.LayoutParams(-1, dp(3), Gravity.TOP));

        bottomBar = buildBottomBar();
        root.addView(bottomBar, new FrameLayout.LayoutParams(-1, dp(54), Gravity.BOTTOM));

        setContentView(root);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        s.setSupportZoom(true);
        s.setBuiltInZoomControls(true);
        s.setDisplayZoomControls(false);
        s.setMediaPlaybackRequiresUserGesture(true);      // không tự phát video/âm thanh
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);
        s.setJavaScriptCanOpenWindowsAutomatically(false);
        s.setSupportMultipleWindows(false);
        shieldJs = AdShield.loadScript(this);

        // Chạy lá chắn ngay khi trang bắt đầu dựng (trước cả script quảng cáo của trang)
        if (!shieldJs.isEmpty() && WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            try {
                WebViewCompat.addDocumentStartJavaScript(web, shieldJs,
                        Collections.singleton("https://*.loigiaihay.com"));
                WebViewCompat.addDocumentStartJavaScript(web, shieldJs,
                        Collections.singleton("https://loigiaihay.com"));
                docStartJs = true;
            } catch (Exception ignored) { }
        }

        CookieManager cm = CookieManager.getInstance();
        cm.setAcceptCookie(true);
        cm.setAcceptThirdPartyCookies(web, true);

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                String scheme = u.getScheme();
                if (!"http".equals(scheme) && !"https".equals(scheme)) return true;   // intent://, market://…
                if (AdShield.isAd(u)) return true;                                    // link quảng cáo → bỏ qua
                if (AdShield.isSite(u.getHost()) || AdShield.isLogin(u.getHost())) return false;
                // Link ngoài khác: chỉ mở bằng trình duyệt khi người dùng tự bấm
                if (req.hasGesture()) {
                    try {
                        startActivity(new Intent(Intent.ACTION_VIEW, u));
                    } catch (Exception ignored) { }
                }
                return true;
            }

            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                if (AdShield.shouldBlock(req)) return AdShield.empty();
                return null;
            }

            @Override
            public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
                if (!docStartJs) injectShield();
                updateNav();
            }

            @Override
            public void onPageCommitVisible(WebView view, String url) {
                injectShield();
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                injectShield();
                CookieManager.getInstance().flush();
                if (url != null && AdShield.isSite(Uri.parse(url).getHost())) {
                    prefs.edit().putString("last", url).apply();
                }
                updateNav();
            }

            @Override
            public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
                updateNav();
            }
        });

        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int p) {
                progress.setProgress(p);
                progress.setVisibility(p >= 100 ? View.GONE : View.VISIBLE);
            }

            @Override
            public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = cb;
                try {
                    startActivityForResult(params.createIntent(), FILE_REQ);
                } catch (Exception e) {
                    fileCallback = null;
                    return false;
                }
                return true;
            }
        });

        // Ẩn thanh dưới khi cuộn xuống đọc bài, hiện lại khi cuộn lên
        web.setOnScrollChangeListener((v, x, y, ox, oy) -> {
            int dy = y - oy;
            if (dy > 12 && y > dp(60)) setBarHidden(true);
            else if (dy < -12 || y < dp(60)) setBarHidden(false);
        });

        String start = HOME;
        Uri data = getIntent() != null ? getIntent().getData() : null;
        if (data != null) start = data.toString();
        else if (savedInstanceState == null) start = prefs.getString("last", HOME);

        if (savedInstanceState != null) web.restoreState(savedInstanceState);
        else web.loadUrl(start);
    }

    private LinearLayout buildBottomBar() {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setBackgroundColor(BLUE);
        bar.setElevation(dp(8));
        backTab = addTab(bar, "‹", "Quay lại", v -> { if (web.canGoBack()) web.goBack(); });
        addTab(bar, "⌂", "Trang chủ", v -> web.loadUrl(HOME));
        addTab(bar, "⟳", "Tải lại", v -> web.reload());
        addTab(bar, "⇡", "Lên đầu", v -> web.pageUp(true));
        fwdTab = addTab(bar, "›", "Tiến", v -> { if (web.canGoForward()) web.goForward(); });
        return bar;
    }

    private TextView addTab(LinearLayout bar, String icon, String label, View.OnClickListener l) {
        TextView tv = new TextView(this);
        tv.setText(icon + "\n" + label);
        tv.setGravity(Gravity.CENTER);
        tv.setTextSize(11);
        tv.setLineSpacing(0, 1.05f);
        tv.setTextColor(BAR_TEXT);
        tv.setTypeface(Typeface.DEFAULT_BOLD);
        tv.setOnClickListener(l);
        bar.addView(tv, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f));
        return tv;
    }

    private void updateNav() {
        if (backTab == null) return;
        backTab.setTextColor(web.canGoBack() ? BAR_TEXT : BAR_DIM);
        fwdTab.setTextColor(web.canGoForward() ? BAR_TEXT : BAR_DIM);
    }

    private void setBarHidden(boolean hide) {
        if (hide == barHidden) return;
        barHidden = hide;
        bottomBar.animate().translationY(hide ? bottomBar.getHeight() : 0).setDuration(180).start();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        if (intent.getData() != null) web.loadUrl(intent.getData().toString());
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        if (req == FILE_REQ && fileCallback != null) {
            fileCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(res, data));
            fileCallback = null;
            return;
        }
        super.onActivityResult(req, res, data);
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) {
            web.goBack();
            return;
        }
        long now = System.currentTimeMillis();
        if (now - lastBack < 2000) {
            super.onBackPressed();
        } else {
            lastBack = now;
            Toast.makeText(this, "Bấm Quay lại lần nữa để thoát", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    @Override
    protected void onPause() {
        super.onPause();
        CookieManager.getInstance().flush();
        web.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        web.onResume();
    }

    private void injectShield() {
        if (!shieldJs.isEmpty()) web.evaluateJavascript(shieldJs, null);
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
