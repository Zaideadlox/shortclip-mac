import AppKit
import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class TikTokWebController: NSObject {
    let webView: WKWebView

    private(set) var currentURL: URL?
    private(set) var pageTitle: String = "TikTok"
    private(set) var isLoading: Bool = false
    private(set) var estimatedProgress: Double = 0
    private(set) var canGoBack: Bool = false
    private(set) var canGoForward: Bool = false
    private(set) var lastError: String?
    private(set) var hasSessionCookies: Bool = false

    private var hasLoadedInitially = false
    private var progressObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var canGoBackObservation: NSKeyValueObservation?
    private var canGoForwardObservation: NSKeyValueObservation?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.allowsMagnification = true
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        wv.setValue(false, forKey: "drawsBackground")

        self.webView = wv
        super.init()

        wv.navigationDelegate = self
        wv.uiDelegate = self
        setupObservers()

        Task {
            await refreshCookieState()
        }
    }

    func ensureLoaded(destination: NavigationDestination) {
        if !hasLoadedInitially {
            load(url: destination.tikTokWebURL)
        }
    }

    func load(destination: NavigationDestination) {
        load(url: destination.tikTokWebURL)
    }

    func loadSearch(query: String) {
        var components = URLComponents(string: "https://www.tiktok.com/search")!
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        }
        if let url = components.url {
            load(url: url)
        }
    }

    func loadLoginPage() {
        load(url: URL(string: "https://www.tiktok.com/login")!)
    }

    func load(url: URL) {
        hasLoadedInitially = true
        lastError = nil
        if currentURL == url && !isLoading {
            return
        }
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
        webView.load(request)
    }

    func reload() {
        lastError = nil
        if webView.url != nil {
            webView.reload()
        } else {
            load(url: URL(string: "https://www.tiktok.com/foryou")!)
        }
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    func pauseMediaPlayback() {
        let js = """
        document.querySelectorAll('video, audio').forEach(el => {
            try { el.pause(); } catch(e) {}
        });
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func dispatchKeyboardAction(key: String, code: String, keyCode: Int) {
        let js = """
        (function() {
            const evt = new KeyboardEvent('keydown', { key: '\(key)', code: '\(code)', keyCode: \(keyCode), which: \(keyCode), bubbles: true, cancelable: true });
            document.dispatchEvent(evt);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func refreshCookieState() async {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        let sessionCookieNames: Set<String> = ["sessionid", "sessionid_ss", "sid_tt", "uid_tt"]
        let found = cookies.contains { cookie in
            cookie.domain.lowercased().contains("tiktok.com") && sessionCookieNames.contains(cookie.name)
        }
        hasSessionCookies = found
    }

    func clearWebSession() async {
        let dataStore = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: types)
        let tiktokRecords = records.filter { $0.displayName.lowercased().contains("tiktok") }
        await dataStore.removeData(ofTypes: types, for: tiktokRecords)
        hasSessionCookies = false
    }

    private func setupObservers() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.estimatedProgress = self.webView.estimatedProgress
            }
        }
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentURL = self.webView.url
            }
        }
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let title = self.webView.title ?? "TikTok"
                self.pageTitle = title.isEmpty ? "TikTok" : title
            }
        }
        canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.canGoBack = self.webView.canGoBack
            }
        }
        canGoForwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.canGoForward = self.webView.canGoForward
            }
        }
    }
}

extension TikTokWebController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        lastError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        Task {
            await refreshCookieState()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        isLoading = false
        lastError = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        isLoading = false
        lastError = error.localizedDescription
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
