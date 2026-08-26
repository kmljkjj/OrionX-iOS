import SwiftUI

// MARK: - Menu principal

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
                Section("Navigation") {
                    row("Favoris", "star.fill", .yellow, onBookmarks)
                    row("Historique", "clock.arrow.circlepath", .blue, onHistory)
                    row("Infos page / source", "doc.text.magnifyingglass", .cyan, onPageInfo)
                }
                Section("Outils") {
                    row("Extensions & scripts", "puzzlepiece.extension.fill", .purple, onExtensions)
                    row("Console développeur", "terminal.fill", .green, onConsole)
                    row("Proxy / IP", "network", .orange, onProxy)
                    Button {
                        onDesktop()
                    } label: {
                        Label(desktopOn ? "Mode desktop · ON" : "Mode desktop · OFF", systemImage: "desktopcomputer")
                    }
                }
                Section {
                    row("Réglages", "gearshape.fill", .gray, onSettings)
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ title: String, _ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title).foregroundStyle(.primary)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
        }
    }
}

// MARK: - Onglets

struct TabsSheet: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(store.tabs) { tab in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tab.title).lineLimit(1)
                            Text(tab.urlString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if tab.id == store.activeTabId {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.activeTabId = tab.id
                        store.save()
                        dismiss()
                    }
                }
                .onDelete { idx in
                    for i in idx { store.closeTab(store.tabs[i].id) }
                }
            }
            .navigationTitle("Onglets (\(store.tabs.count))")
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
        .preferredColorScheme(.dark)
    }
}

// MARK: - Favoris / Historique

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
                            Text(b.title).foregroundStyle(.primary)
                            Text(b.urlString).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { i in store.bookmarks.remove(atOffsets: i); store.save() }
            }
            .navigationTitle("Favoris")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        }
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
                            Text(h.title).foregroundStyle(.primary)
                            Text(h.urlString).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { i in store.history.remove(atOffsets: i); store.save() }
            }
            .navigationTitle("Historique")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Effacer") { store.history.removeAll(); store.save() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Extensions

struct ExtensionsView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("OrionX injecte des **userscripts** JS/CSS (style Violentmonkey). Les vrais packs Chrome/Firefox nécessitent les APIs Orion/Kagi non publiques sur IPA sideload.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Scripts installés") {
                    ForEach($store.scripts) { $s in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(s.name).font(.headline)
                                Spacer()
                                Toggle("", isOn: $s.enabled).labelsHidden()
                            }
                            Text("match: \(s.matches) · \(s.isCSS ? "CSS" : "JS")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .onChange(of: s.enabled) { _ in store.save() }
                    }
                    .onDelete { i in store.scripts.remove(atOffsets: i); store.save() }
                }
            }
            .navigationTitle("Extensions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddScriptView() }
        }
        .preferredColorScheme(.dark)
    }
}

struct AddScriptView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Mon script"
    @State private var matches = "*"
    @State private var code = "console.log('OrionX userscript');"
    @State private var isCSS = false

    var body: some View {
        NavigationView {
            Form {
                TextField("Nom", text: $name)
                TextField("Match (* ou host)", text: $matches)
                Toggle("CSS (sinon JavaScript)", isOn: $isCSS)
                Section("Code") {
                    TextEditor(text: $code)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 180)
                }
            }
            .navigationTitle("Nouveau script")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
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
        .preferredColorScheme(.dark)
    }
}

// MARK: - Proxy

struct ProxyView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Activer proxy", isOn: $store.settings.proxy.enabled)
                    Picker("Type", selection: $store.settings.proxy.type) {
                        Text("HTTP").tag("HTTP")
                        Text("SOCKS5").tag("SOCKS5")
                    }
                    TextField("Hôte", text: $store.settings.proxy.host)
                        .textInputAutocapitalization(.never)
                    TextField("Port", value: $store.settings.proxy.port, format: .number)
                        .keyboardType(.numberPad)
                    TextField("User (opt)", text: $store.settings.proxy.username)
                    SecureField("Pass (opt)", text: $store.settings.proxy.password)
                } footer: {
                    Text("Sur iOS sideload, un proxy HTTP/SOCKS se configure ici pour guidance / apps liées. Un **VPN système** (changer toute l’IP de l’appareil) demande une Network Extension signée Apple — impossible en IPA unsigned pure. Tu peux coller un proxy gratuit HTTP public à tes risques (souvent instables / non privés).")
                }

                Section("Presets (exemples — vérifie qu’ils fonctionnent)") {
                    Button("Désactiver") {
                        store.settings.proxy.enabled = false
                        store.save()
                    }
                }
            }
            .navigationTitle("Proxy / IP")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Sauver") { store.save(); dismiss() }
                }
            }
            .onDisappear { store.save() }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: BrowserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Général") {
                    TextField("Page d’accueil", text: $store.settings.homepage)
                    TextField("Moteur (préfixe URL)", text: $store.settings.searchEngineURL)
                    Toggle("Mode desktop par défaut", isOn: $store.settings.desktopByDefault)
                }
                Section("Confidentialité") {
                    Toggle("Bloquer pubs", isOn: $store.settings.blockAds)
                    Toggle("Bloquer trackers", isOn: $store.settings.blockTrackers)
                }
                Section("User-Agent custom") {
                    TextField("Laisser vide = auto", text: $store.settings.customUserAgent)
                        .font(.caption)
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Sauver") { store.save(); dismiss() }
                }
            }
            .onDisappear { store.save() }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Page source

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
            .navigationTitle("Source HTML")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Copier") { UIPasteboard.general.string = html }
                }
            }
            .onAppear {
                web.eval("document.documentElement.outerHTML") { r in
                    html = String(r.prefix(200_000))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Console

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
                    Text("Console").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Button("Clear") {
                        if tab == 0 { store.consoleLogs.removeAll() }
                        else { store.consoleErrors.removeAll() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    Button(action: onClose) {
                        Image(systemName: "xmark").foregroundStyle(.white.opacity(0.8))
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
                                .foregroundStyle(tab == 1 ? Color.red.opacity(0.9) : Color.white.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 160)

                HStack {
                    TextField("JS…", text: $js)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    Button("Run") {
                        let c = js
                        web.eval(c) { r in store.log("< \(r)") }
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cyan)
                    .foregroundStyle(.black)
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12)))
            )
            .padding()
        }
    }
}
