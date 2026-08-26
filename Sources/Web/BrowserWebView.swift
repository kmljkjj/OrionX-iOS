import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var coordinatorModel: TabWebModel
    @EnvironmentObject var store: BrowserStore

    func makeCoordinator() -> Coordinator {
        Coordinator(model: coordinatorModel, store: store)
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true
        if #available(iOS 14.0, *) {
            cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        // Nouveau userContentController → pas de double-register du handler
        let uc = cfg.userContentController
        uc.removeScriptMessageHandler(forName: "orionx")
        uc.add(context.coordinator, name: "orionx")

        let bridge = """
        (function(){
          function send(t,m){try{window.webkit.messageHandlers.orionx.postMessage({type:t,message:String(m)})}catch(e){}}
          window.onerror=function(m,s,l,c){send('error',m+' @'+s+':'+l);return false};
          window.addEventListener('unhandledrejection',function(e){send('error','unhandled '+String(e.reason))});
          var ce=console.error;console.error=function(){try{send('error',Array.from(arguments).map(String).join(' '))}catch(e){}return ce.apply(console,arguments)};
        })();
        """
        uc.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .automatic
        wv.isOpaque = true
        wv.backgroundColor = UIColor(white: 0.1, alpha: 1)

        context.coordinator.webView = wv
        DispatchQueue.main.async {
            self.coordinatorModel.attach(wv)
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.store = store
        context.coordinator.model = coordinatorModel
        if coordinatorModel.desktopMode {
            uiView.customUserAgent =
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else {
            let custom = store.settings.customUserAgent
            uiView.customUserAgent = custom.isEmpty ? nil : custom
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "orionx")
        coordinator.webView = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var model: TabWebModel
        var store: BrowserStore
        weak var webView: WKWebView?

        init(model: TabWebModel, store: BrowserStore) {
            self.model = model
            self.store = store
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            let msg = String(describing: body["message"] ?? "")
            if type == "error" {
                store.logError(msg)
            } else {
                store.log(msg)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.model.isLoading = true
                self.store.updateActive { $0.isLoading = true }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let title = webView.title ?? ""
            let url = webView.url?.absoluteString ?? ""
            let host = webView.url?.host
            let scripts = self.store.scripts
            DispatchQueue.main.async {
                self.model.isLoading = false
                self.store.updateActive {
                    $0.isLoading = false
                    $0.title = title.isEmpty ? url : title
                    if !url.isEmpty { $0.urlString = url }
                    $0.canGoBack = webView.canGoBack
                    $0.canGoForward = webView.canGoForward
                }
                if !url.isEmpty {
                    self.store.addHistory(title: title.isEmpty ? url : title, url: url)
                }
                self.model.injectScripts(from: scripts, host: host)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.model.isLoading = false
                self.store.updateActive { $0.isLoading = false }
                self.store.logError(error.localizedDescription)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            DispatchQueue.main.async {
                self.model.isLoading = false
                self.store.updateActive { $0.isLoading = false }
                // -999 = cancelled, ignorer
                let ns = error as NSError
                if ns.code != NSURLErrorCancelled {
                    self.store.logError(error.localizedDescription)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url {
                let flags = store.adblockFlags()
                if AdBlock.shouldBlock(url: url, blockAds: flags.ads, blockTrackers: flags.trackers) {
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                DispatchQueue.main.async {
                    self.store.newTab(url: url.absoluteString)
                }
            }
            return nil
        }
    }
}

final class TabWebModel: ObservableObject {
    @Published var isLoading = false
    @Published var desktopMode = false
    weak var webView: WKWebView?
    private var pendingURL: String?

    func attach(_ wv: WKWebView) {
        webView = wv
        if let p = pendingURL {
            pendingURL = nil
            load(p)
        }
    }

    func load(_ urlString: String) {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") && !s.hasPrefix("about:") {
            s = "https://" + s
        }
        guard let url = URL(string: s) else { return }

        guard let wv = webView else {
            pendingURL = s
            return
        }
        DispatchQueue.main.async {
            wv.load(URLRequest(url: url))
        }
    }

    func loadSearch(_ query: String, enginePrefix: String) {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        load(enginePrefix + q)
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stop() { webView?.stopLoading() }

    func eval(_ js: String, completion: ((String) -> Void)? = nil) {
        webView?.evaluateJavaScript(js) { r, e in
            if let e = e {
                completion?("error: \(e.localizedDescription)")
            } else {
                completion?(String(describing: r ?? "undefined"))
            }
        }
    }

    func injectScripts(from scripts: [UserScript], host: String?) {
        guard let wv = webView else { return }
        let h = (host ?? "").lowercased()
        for s in scripts where s.enabled {
            let match = s.matches == "*" || (!s.matches.isEmpty && h.contains(s.matches.lowercased()))
            guard match else { continue }
            if s.isCSS {
                let escaped = jsonString(s.code)
                let id = s.id.uuidString
                let js = """
                (function(){
                  var id='ox-\(id)';
                  if(document.getElementById(id)) return;
                  var st=document.createElement('style'); st.id=id;
                  st.textContent=\(escaped);
                  (document.head||document.documentElement).appendChild(st);
                })();
                """
                wv.evaluateJavaScript(js, completionHandler: nil)
            } else {
                let js = "(function(){ try {\n" + s.code + "\n} catch(e){ console.error('userscript', e); } })();"
                wv.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    private func jsonString(_ s: String) -> String {
        let d = try? JSONSerialization.data(withJSONObject: s, options: [])
        return d.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}
