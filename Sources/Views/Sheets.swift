import SwiftUI

struct MainMenuSheet: View {
    var onExtensions: () -> Void
    var onSettings: () -> Void
    var onConsole: () -> Void
    var onBookmarks: () -> Void
    var onHistory: () -> Void
    var onProxy: () -> Void
    var onPageInfo: () -> Void
    var onDesktop: () -> Void
    var desktopOn: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Navigation")) {
                    btn("Favoris", "star.fill", onBookmarks)
                    btn("Historique", "clock", onHistory)
                    btn("Source HTML", "doc.text", onPageInfo)
                }
                Section(header: Text("Outils")) {
                    btn("Extensions / scripts", "puzzlepiece.extension", onExtensions)
                    btn("Console", "terminal", onConsole)
                    btn("Proxy / IP", "network", onProxy)
                    Button(action: onDesktop) {
                        Label(desktopOn ? "Mode desktop · ON" : "Mode desktop · OFF", systemImage: "desktopcomputer")
                    }
                }
                Section {
                    btn("Réglages", "gearshape", onSettings)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func btn(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
    }
}

struct TabsSheet: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(store.tabs) { tab in
                    Button {
                        store.activeTabId = tab.id
                        store.save()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tab.title).lineLimit(1).foregroundColor(.primary)
                                Text(tab.urlString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if tab.id == store.activeTabId {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.cyan)
                            }
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx.sorted(by: >) {
                        if store.tabs.indices.contains(i) {
                            store.closeTab(store.tabs[i].id)
                        }
                    }
                }
            }
            .navigationTitle("Onglets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.newTab()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

struct BookmarksView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    var onOpen: (String) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(store.bookmarks) { b in
                    Button {
                        onOpen(b.urlString)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(b.title).foregroundColor(.primary)
                            Text(b.urlString).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { i in
                    store.bookmarks.remove(atOffsets: i)
                    store.save()
                }
            }
            .navigationTitle("Favoris")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    var onOpen: (String) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(store.history) { h in
                    Button {
                        onOpen(h.urlString)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(h.title).foregroundColor(.primary)
                            Text(h.urlString).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { i in
                    store.history.remove(atOffsets: i)
                    store.save()
                }
            }
            .navigationTitle("Historique")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Effacer") {
                        store.history.removeAll()
                        store.save()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

struct ExtensionsView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                Section(footer: Text("Userscripts JS/CSS injectés dans les pages (pas les packs Chrome/Firefox natifs).")) {
                    EmptyView()
                }
                Section(header: Text("Scripts")) {
                    ForEach(store.scripts) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.name).font(.headline)
                                Text("\(s.matches) · \(s.isCSS ? "CSS" : "JS")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: binding(for: s.id))
                                .labelsHidden()
                        }
                    }
                    .onDelete { i in
                        store.scripts.remove(atOffsets: i)
                        store.save()
                    }
                }
            }
            .navigationTitle("Extensions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddScriptView().environmentObject(store)
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { store.scripts.first(where: { $0.id == id })?.enabled ?? false },
            set: { newVal in
                if let i = store.scripts.firstIndex(where: { $0.id == id }) {
                    store.scripts[i].enabled = newVal
                    store.save()
                }
            }
        )
    }
}

struct AddScriptView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Mon script"
    @State private var matches = "*"
    @State private var code = "console.log('OrionX');"
    @State private var isCSS = false

    var body: some View {
        NavigationView {
            Form {
                TextField("Nom", text: $name)
                TextField("Match (* ou host)", text: $matches)
                Toggle("CSS", isOn: $isCSS)
                Section(header: Text("Code")) {
                    TextEditor(text: $code)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle("Nouveau")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Ajouter") {
                        store.scripts.append(UserScript(
                            name: name, matches: matches, code: code, isCSS: isCSS
                        ))
                        store.save()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

struct ProxyView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text("Pas un VPN système iOS. Configure un proxy HTTP/SOCKS si tu en as un.")) {
                    Toggle("Activer proxy", isOn: $store.settings.proxy.enabled)
                    Picker("Type", selection: $store.settings.proxy.type) {
                        Text("HTTP").tag("HTTP")
                        Text("SOCKS5").tag("SOCKS5")
                    }
                    TextField("Hôte", text: $store.settings.proxy.host)
                        .autocapitalization(.none)
                    TextField("Port", value: $store.settings.proxy.port, format: .number)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Proxy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Sauver") {
                        store.save()
                        dismiss()
                    }
                }
            }
            .onDisappear { store.save() }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Général")) {
                    TextField("Accueil", text: $store.settings.homepage)
                        .autocapitalization(.none)
                    TextField("Moteur (préfixe)", text: $store.settings.searchEngineURL)
                        .autocapitalization(.none)
                    Toggle("Desktop par défaut", isOn: $store.settings.desktopByDefault)
                }
                Section(header: Text("Confidentialité")) {
                    Toggle("Bloquer pubs", isOn: $store.settings.blockAds)
                    Toggle("Bloquer trackers", isOn: $store.settings.blockTrackers)
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Sauver") {
                        store.save()
                        dismiss()
                    }
                }
            }
            .onDisappear { store.save() }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

struct PageInfoView: View {
    @ObservedObject var web: TabWebModel
    @Environment(\.dismiss) private var dismiss
    @State private var html = "Chargement…"

    var body: some View {
        NavigationView {
            ScrollView {
                Text(html)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Copier") { UIPasteboard.general.string = html }
                }
            }
            .onAppear {
                web.eval("document.documentElement.outerHTML") { r in
                    DispatchQueue.main.async {
                        html = String(r.prefix(150_000))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

struct ConsolePanel: View {
    @ObservedObject var store: BrowserStore
    @ObservedObject var web: TabWebModel
    var onClose: () -> Void
    @State private var tab = 0
    @State private var js = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Console").font(.headline).foregroundColor(.white)
                    Spacer()
                    Button("Clear") {
                        if tab == 0 { store.consoleLogs.removeAll() }
                        else { store.consoleErrors.removeAll() }
                    }
                    .font(.caption)
                    .foregroundColor(.cyan)
                    Button(action: onClose) {
                        Image(systemName: "xmark").foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()

                Picker("", selection: $tab) {
                    Text("Logs").tag(0)
                    Text("Errors").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        let lines = tab == 0 ? store.consoleLogs : store.consoleErrors
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(tab == 1 ? .red : .white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 150)

                HStack {
                    TextField("JS…", text: $js)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    Button("Run") {
                        let c = js
                        web.eval(c) { r in store.log("< \(r)") }
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.94))
            )
            .padding()
        }
    }
}
