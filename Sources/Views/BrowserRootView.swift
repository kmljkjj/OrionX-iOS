import SwiftUI

struct BrowserRootView: View {
    @EnvironmentObject var store: BrowserStore
    @StateObject private var web = TabWebModel()
    @State private var address = ""
    @State private var showTabs = false
    @State private var showMenu = false
    @State private var showExtensions = false
    @State private var showSettings = false
    @State private var showConsole = false
    @State private var showBookmarks = false
    @State private var showHistory = false
    @State private var showProxy = false
    @State private var showPageInfo = false
    @State private var didInitialLoad = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                BrowserWebView(coordinatorModel: web)
                    .environmentObject(store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }

            if showConsole {
                ConsolePanel(store: store, web: web, onClose: { showConsole = false })
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showTabs) {
            TabsSheet().environmentObject(store)
        }
        .sheet(isPresented: $showMenu) {
            MainMenuSheet(
                onExtensions: { showMenu = false; DispatchQueue.main.async { showExtensions = true } },
                onSettings: { showMenu = false; DispatchQueue.main.async { showSettings = true } },
                onConsole: { showMenu = false; showConsole = true },
                onBookmarks: { showMenu = false; DispatchQueue.main.async { showBookmarks = true } },
                onHistory: { showMenu = false; DispatchQueue.main.async { showHistory = true } },
                onProxy: { showMenu = false; DispatchQueue.main.async { showProxy = true } },
                onPageInfo: { showMenu = false; DispatchQueue.main.async { showPageInfo = true } },
                onDesktop: {
                    web.desktopMode.toggle()
                    store.updateActive { $0.desktopMode = web.desktopMode }
                    web.reload()
                    showMenu = false
                },
                desktopOn: web.desktopMode
            )
        }
        .sheet(isPresented: $showExtensions) { ExtensionsView().environmentObject(store) }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(onOpen: openURL).environmentObject(store)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(onOpen: openURL).environmentObject(store)
        }
        .sheet(isPresented: $showProxy) { ProxyView().environmentObject(store) }
        .sheet(isPresented: $showPageInfo) { PageInfoView(web: web) }
        .onAppear {
            if !didInitialLoad {
                didInitialLoad = true
                // Laisse le WKWebView s'attacher avant de charger
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    syncFromTab()
                }
            }
        }
        .onChange(of: store.activeTabId) { _ in
            syncFromTab()
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { web.goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!(store.activeTab?.canGoBack ?? false))

            Button { web.goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!(store.activeTab?.canGoForward ?? false))

            HStack {
                if store.activeTab?.isLoading == true {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "lock.fill").font(.caption2).opacity(0.5)
                }
                TextField("Recherche ou URL", text: $address, onCommit: submitAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 15))
                if !address.isEmpty {
                    Button { address = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)

            Button { web.reload() } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.12))
    }

    private var bottomBar: some View {
        HStack {
            Button { showTabs = true } label: {
                ZStack {
                    Image(systemName: "square.on.square")
                    Text("\(max(store.tabs.count, 1))")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            Spacer()
            Button {
                if let t = store.activeTab {
                    store.addBookmark(title: t.title, url: t.urlString)
                    store.log("Favori ajouté")
                }
            } label: {
                Image(systemName: "star")
            }
            Spacer()
            Button { store.newTab() } label: {
                Image(systemName: "plus")
            }
            Spacer()
            Button { showConsole.toggle() } label: {
                Image(systemName: "terminal")
            }
            Spacer()
            Button { showMenu = true } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .font(.system(size: 20))
        .foregroundColor(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(Color(white: 0.12))
    }

    private func submitAddress() {
        let t = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if t.contains(" ") || (!t.contains(".") && !t.hasPrefix("http")) {
            web.loadSearch(t, enginePrefix: store.settings.searchEngineURL)
        } else {
            web.load(t)
        }
        store.updateActive { $0.urlString = t }
    }

    private func openURL(_ url: String) {
        address = url
        web.load(url)
        store.updateActive { $0.urlString = url }
    }

    private func syncFromTab() {
        guard let t = store.activeTab else { return }
        address = t.urlString
        web.desktopMode = t.desktopMode
        if !t.urlString.isEmpty {
            web.load(t.urlString)
        }
    }
}
