package com.phong.meodoc;

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
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
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

/**
 * Mèo Đọc — trình duyệt riêng cho meosss.com.
 * Tải trang gốc trong WebView (đăng nhập, thư viện, mở khoá… vẫn do web xử lý),
 * thêm thanh điều hướng, chế độ đọc toàn màn hình và nhớ trang đang đọc.
 */
public class MainActivity extends Activity {

    private static final String HOST = "meosss.com";
    private static final String HOME = "https://meosss.com/";
    private static final int FILE_REQ = 42;

    private WebView web;
    private ProgressBar progress;
    private LinearLayout bottomBar;
    private TextView[] tabs;
    private SharedPreferences prefs;
    private ValueCallback<Uri[]> fileCallback;
    private String shieldJs = "";
    private boolean reading = false;
    private boolean barHidden = false;
    private long lastBack = 0;

    private static final String[][] TABS = {
            {"⌂", "Trang chủ", "https://meosss.com/"},
            {"‹", "Chương trước", "@prev"},
            {"☰", "Chọn chương", "@list"},
            {"›", "Chương sau", "@next"},
    };

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences("meodoc", MODE_PRIVATE);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.parseColor("#1A0A13"));

        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(-1, -1));

        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        progress.setProgressTintList(android.content.res.ColorStateList.valueOf(Color.parseColor("#FF7AB6")));
        root.addView(progress, new FrameLayout.LayoutParams(-1, dp(3), Gravity.TOP));

        bottomBar = buildBottomBar();
        root.addView(bottomBar, new FrameLayout.LayoutParams(-1, dp(56), Gravity.BOTTOM));

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
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);
        s.setJavaScriptCanOpenWindowsAutomatically(false);
        s.setSupportMultipleWindows(false);
        shieldJs = AdShield.loadScript(this, "adshield.js") + "\n" + AdShield.loadScript(this, "chapnav.js");
        web.addJavascriptInterface(new NavBridge(), "CuuAmApp");

        CookieManager cm = CookieManager.getInstance();
        cm.setAcceptCookie(true);
        cm.setAcceptThirdPartyCookies(web, true);

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) {
                // Chỉ đi trong meosss.com. Mọi chuyển hướng ra ngoài (quảng cáo, TikTok, Shopee,
                // intent://, market://…) đều bị bỏ qua — không mở trình duyệt hay app khác.
                return !AdShield.isAllowedNavigation(req.getUrl());
            }

            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                if (AdShield.shouldBlock(req)) return AdShield.empty();
                return null;
            }

            @Override
            public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
                injectShield();
            }

            @Override
            public void onPageCommitVisible(WebView view, String url) {
                injectShield();
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                injectShield();
                CookieManager.getInstance().flush();
                if (url != null && url.contains(HOST)) prefs.edit().putString("last", url).apply();
                updateMode(url);
            }

            @Override
            public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
                updateMode(url);
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

        // Ẩn thanh dưới khi cuộn xuống, hiện lại khi cuộn lên
        web.setOnScrollChangeListener((v, x, y, ox, oy) -> {
            int dy = y - oy;
            if (!web.canScrollVertically(1)) setBarHidden(false);      // cuối chương → hiện thanh để sang chương
            else if (dy > 12) setBarHidden(true);
            else if (dy < -12 || y < dp(40)) setBarHidden(false);
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
        bar.setBackgroundColor(Color.parseColor("#F21A0A13"));
        bar.setElevation(dp(8));
        tabs = new TextView[TABS.length];
        for (int i = 0; i < TABS.length; i++) {
            final String[] t = TABS[i];
            TextView tv = new TextView(this);
            tv.setText(t[0] + "\n" + t[1]);
            tv.setGravity(Gravity.CENTER);
            tv.setTextSize(11);
            tv.setLineSpacing(0, 1.1f);
            tv.setTextColor(Color.parseColor("#F3DCE8"));
            tv.setTypeface(Typeface.DEFAULT_BOLD);
            tv.setOnClickListener(v -> {
                if (t[2].startsWith("@")) chapterAction(t[2].substring(1));
                else web.loadUrl(t[2]);
            });
            tabs[i] = tv;
            bar.addView(tv, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f));
        }
        return bar;
    }

    /** Trang chương (…/truyen/<tên>/chap-…) → chế độ đọc: toàn màn hình, giữ màn hình sáng. */
    private void updateMode(String url) {
        boolean isChapter = url != null && url.matches("https?://(www\\.)?meosss\\.com/truyen/[^/]+/chap[^/]*/?.*");
        for (int i = 0; i < 4; i++) {
            boolean active = url != null && url.split("[?#]")[0].equals(TABS[i][2]);
            tabs[i].setTextColor(Color.parseColor(active ? "#FF7AB6" : "#F3DCE8"));
        }
        if (isChapter == reading) return;
        reading = isChapter;
        if (reading) getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                if (reading) {
                    c.hide(WindowInsets.Type.statusBars());
                    c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                } else {
                    c.show(WindowInsets.Type.statusBars());
                }
            }
        } else {
            if (reading) getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
            else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        }
        if (!reading) setBarHidden(false);
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

    /** prev / next / list — chạy trong trang (chapnav.js), kết quả trả về qua NavBridge. */
    private void chapterAction(String action) {
        injectShield();
        web.evaluateJavascript("window.__cuuam && window.__cuuam.run('" + action + "')", null);
    }

    private final class NavBridge {
        @android.webkit.JavascriptInterface
        public void onNav(String json) {
            runOnUiThread(() -> handleNav(json));
        }
    }

    private void handleNav(String json) {
        try {
            org.json.JSONObject o = new org.json.JSONObject(json);
            if ("toast".equals(o.optString("type"))) {
                Toast.makeText(this, o.optString("text"), Toast.LENGTH_SHORT).show();
                return;
            }
            if (!"list".equals(o.optString("type"))) return;
            org.json.JSONArray items = o.getJSONArray("items");
            final String[] titles = new String[items.length()];
            final String[] urls = new String[items.length()];
            for (int i = 0; i < items.length(); i++) {
                titles[i] = items.getJSONObject(i).optString("t");
                urls[i] = items.getJSONObject(i).optString("u");
            }
            final int cur = o.optInt("current", -1);
            android.app.AlertDialog d = new android.app.AlertDialog.Builder(this,
                    android.R.style.Theme_DeviceDefault_Dialog_Alert)
                    .setTitle("Chọn chương (" + titles.length + ")")
                    .setSingleChoiceItems(titles, cur, (dlg, which) -> {
                        dlg.dismiss();
                        if (which != cur) web.loadUrl(urls[which]);
                    })
                    .setNegativeButton("Đóng", null)
                    .create();
            d.show();
            if (cur > 2) d.getListView().setSelection(cur - 2);
        } catch (Exception ignored) { }
    }

    private void injectShield() {
        if (!shieldJs.isEmpty()) web.evaluateJavascript(shieldJs, null);
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
