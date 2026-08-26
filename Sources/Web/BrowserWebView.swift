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

        let uc = cfg.userContentController
        uc.add(context.coordinator, name: "orionx")

        let bridge = """
        (function(){
          function send(t,m){try{window.webkit.messageHandlers.orionx.postMessage({type:t,message:String(m)})}catch(e){}}
          window.onerror=function(m,s,l,c){send('error',m+' @'+s+':'+l);return false};
          window.addEventListener('unhandledrejection',function(e){send('error','unhandled '+e.reason)});
          var ce=console.error;console.error=function(){try{send('error',Array.from(arguments).join(' '))}catch(e){}return ce.apply(console,arguments)};
          var cw=console.warn;console.warn=function(){try{send('warn',Array.from(arguments).join(' '))}catch(e){}return cw.apply(console,arguments)};
        })();
        """
        uc.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .automatic
        wv.isOpaque = false
        wv.backgroundColor = UIColor(white: 0.08, alpha: 1)

        context.coordinator.webView = wv
        coordinatorModel.attach(wv)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.store = store
        if coordinatorModel.desktopMode {
            uiView.customUserAgent =
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else if !store.settings.customUserAgent.isEmpty {
            uiView.customUserAgent = store.settings.customUserAgent
        } else {
            uiView.customUserAgent = nil
        }
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
                  let type = body["type"] as? String,
                  let msg = body["message"] as? String else { return }
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
            let scripts = store.scripts
            DispatchQueue.main.async {
                self.model.isLoading = false
                self.store.updateActive {
                    $0.isLoading = false
                    $0.title = title.isEmpty ? url : title
                    $0.urlString = url
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

    func attach(_ wv: WKWebView) {
        webView = wv
    }

    func load(_ urlString: String) {
        guard let wv = webView else { return }
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") && !s.hasPrefix("about:") {
            s = "https://" + s
        }
        guard let url = URL(string: s) else { return }
        wv.load(URLRequest(url: url))
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
            let match = s.matches == "*" || h.contains(s.matches.lowercased())
            guard match else { continue }
            if s.isCSS {
                let escaped = jsonString(s.code)
                let js = """
                (function(){
                  var id='ox-\(s.id.uuidString)';
                  if(document.getElementById(id)) return;
                  var st=document.createElement('style'); st.id=id;
                  st.textContent=\(escaped);
                  (document.head||document.documentElement).appendChild(st);
                })();
                """
                wv.evaluateJavaScript(js, completionHandler: nil)
            } else {
                // Wrap user JS; avoid breaking on raw code
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
