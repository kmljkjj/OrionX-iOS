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

    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                BrowserWebView(coordinatorModel: web)
                    .environmentObject(store)
                bottomBar
            }

            if showConsole {
                ConsolePanel(store: store, web: web, onClose: { showConsole = false })
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showTabs) { TabsSheet() }
        .sheet(isPresented: $showMenu) {
            MainMenuSheet(
                onExtensions: { showMenu = false; showExtensions = true },
                onSettings: { showMenu = false; showSettings = true },
                onConsole: { showMenu = false; showConsole = true },
                onBookmarks: { showMenu = false; showBookmarks = true },
                onHistory: { showMenu = false; showHistory = true },
                onProxy: { showMenu = false; showProxy = true },
                onPageInfo: { showMenu = false; showPageInfo = true },
                onDesktop: {
                    web.desktopMode.toggle()
                    store.updateActive { $0.desktopMode = web.desktopMode }
                    web.reload()
                    showMenu = false
                },
                desktopOn: web.desktopMode
            )
        }
        .sheet(isPresented: $showExtensions) { ExtensionsView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showBookmarks) { BookmarksView(onOpen: openURL) }
        .sheet(isPresented: $showHistory) { HistoryView(onOpen: openURL) }
        .sheet(isPresented: $showProxy) { ProxyView() }
        .sheet(isPresented: $showPageInfo) { PageInfoView(web: web) }
        .onAppear { syncFromTab() }
        .onChange(of: store.activeTabId) { _ in syncFromTab() }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
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
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 15))
                    if !address.isEmpty {
                        Button { address = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button { web.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
        .padding(.bottom, 6)
        .background(Color(white: 0.1))
    }

    private var bottomBar: some View {
        HStack {
            Button { showTabs = true } label: {
                ZStack {
                    Image(systemName: "square.on.square")
                    Text("\(store.tabs.count)")
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
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(Color(white: 0.1))
    }

    private func submitAddress() {
        let t = address.trimmingCharacters(in: .whitespacesAndNewlines)
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
        web.load(t.urlString)
    }
}
