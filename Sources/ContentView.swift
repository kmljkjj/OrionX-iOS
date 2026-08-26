import SwiftUI
import WebKit

/// Version minimale stable — un seul écran, pas de store complexe au boot.
struct ContentView: View {
    @StateObject private var browser = SimpleBrowser()
    @State private var address = "https://duckduckgo.com"
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // Barre d'adresse
            HStack(spacing: 8) {
                Button(action: { browser.goBack() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                Button(action: { browser.goForward() }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }

                TextField("URL", text: $address, onCommit: {
                    browser.load(address)
                })
                .padding(8)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)

                Button(action: { browser.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                }
                Button(action: { showMenu = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(white: 0.12))

            // WebView
            WebViewContainer(browser: browser)
                .background(Color.black)

            // Barre bas
            HStack {
                Button(action: {
                    address = "https://duckduckgo.com"
                    browser.load(address)
                }) {
                    Image(systemName: "house")
                }
                Spacer()
                Button(action: { browser.load("https://canary.discord.com/app") }) {
                    Text("Discord")
                        .font(.caption)
                }
                Spacer()
                Button(action: {
                    browser.desktopMode.toggle()
                    browser.reload()
                }) {
                    Image(systemName: browser.desktopMode ? "desktopcomputer" : "iphone")
                }
            }
            .font(.system(size: 18))
            .foregroundColor(.white)
            .padding()
            .background(Color(white: 0.12))
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .actionSheet(isPresented: $showMenu) {
            ActionSheet(
                title: Text("OrionX"),
                message: Text("v1.0.2 stable"),
                buttons: [
                    .default(Text("DuckDuckGo")) {
                        address = "https://duckduckgo.com"
                        browser.load(address)
                    },
                    .default(Text("Google")) {
                        address = "https://www.google.com"
                        browser.load(address)
                    },
                    .default(Text("Recharger")) { browser.reload() },
                    .cancel(Text("Fermer"))
                ]
            )
        }
        .onAppear {
            // Délai pour laisser le WKWebView se créer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                browser.load(address)
            }
        }
    }
}

final class SimpleBrowser: NSObject, ObservableObject {
    @Published var desktopMode = false
    @Published var isLoading = false

    weak var webView: WKWebView?
    private var pending: String?

    func attach(_ wv: WKWebView) {
        webView = wv
        applyUA()
        if let p = pending {
            pending = nil
            loadNow(p, on: wv)
        }
    }

    func load(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return }
        if !s.contains(".") && !s.hasPrefix("http") {
            s = "https://duckduckgo.com/?q=" +
                (s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)
        } else if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "https://" + s
        }
        guard let wv = webView else {
            pending = s
            return
        }
        loadNow(s, on: wv)
    }

    private func loadNow(_ s: String, on wv: WKWebView) {
        guard let url = URL(string: s) else { return }
        DispatchQueue.main.async {
            wv.load(URLRequest(url: url))
        }
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }

    func applyUA() {
        if desktopMode {
            webView?.customUserAgent =
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        } else {
            webView?.customUserAgent = nil
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var browser: SimpleBrowser

    func makeCoordinator() -> Coord {
        Coord(browser: browser)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.backgroundColor = .black
        wv.isOpaque = true

        DispatchQueue.main.async {
            self.browser.attach(wv)
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        browser.applyUA()
    }

    final class Coord: NSObject, WKNavigationDelegate {
        let browser: SimpleBrowser
        init(browser: SimpleBrowser) { self.browser = browser }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.browser.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.browser.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.browser.isLoading = false }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            DispatchQueue.main.async { self.browser.isLoading = false }
        }
    }
}
