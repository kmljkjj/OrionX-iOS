import Foundation
import Combine

/// Store partagé — pas @MainActor sur toute la classe (WK delegates hors main actor).
final class BrowserStore: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabId: UUID?
    @Published var bookmarks: [Bookmark] = []
    @Published var history: [HistoryEntry] = []
    @Published var scripts: [UserScript] = []
    @Published var settings: BrowserSettings = BrowserSettings()

    @Published var consoleLogs: [String] = []
    @Published var consoleErrors: [String] = []

    private let defaults = UserDefaults.standard
    private let lock = NSLock()

    init() {
        load()
        if tabs.isEmpty {
            let t = BrowserTab(
                title: "Accueil",
                urlString: settings.homepage,
                desktopMode: settings.desktopByDefault
            )
            tabs = [t]
            activeTabId = t.id
        }
        if scripts.isEmpty {
            scripts = Self.defaultScripts()
        }
    }

    var activeTab: BrowserTab? {
        tabs.first { $0.id == activeTabId }
    }

    var activeTabIndex: Int? {
        tabs.firstIndex { $0.id == activeTabId }
    }

    /// Snapshot thread-safe pour adblock (appelé depuis WK delegate)
    func adblockFlags() -> (ads: Bool, trackers: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (settings.blockAds, settings.blockTrackers)
    }

    func newTab(url: String? = nil) {
        let t = BrowserTab(
            title: "Nouvel onglet",
            urlString: url ?? settings.homepage,
            desktopMode: settings.desktopByDefault
        )
        tabs.append(t)
        activeTabId = t.id
        save()
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if tabs.isEmpty {
            newTab()
        } else if activeTabId == id {
            activeTabId = tabs.last?.id
        }
        save()
    }

    func updateActive(_ mutate: (inout BrowserTab) -> Void) {
        guard let i = activeTabIndex else { return }
        mutate(&tabs[i])
        save()
    }

    func addBookmark(title: String, url: String) {
        bookmarks.insert(Bookmark(title: title, urlString: url), at: 0)
        save()
    }

    func addHistory(title: String, url: String) {
        history.removeAll { $0.urlString == url }
        history.insert(HistoryEntry(title: title, urlString: url), at: 0)
        if history.count > 300 { history = Array(history.prefix(300)) }
        save()
    }

    func log(_ msg: String) {
        let line = "[\(Self.ts())] \(msg)"
        DispatchQueue.main.async {
            self.consoleLogs.append(line)
            if self.consoleLogs.count > 500 {
                self.consoleLogs.removeFirst(self.consoleLogs.count - 500)
            }
        }
    }

    func logError(_ msg: String) {
        let line = "[\(Self.ts())] \(msg)"
        DispatchQueue.main.async {
            self.consoleErrors.append(line)
            self.consoleLogs.append("ERR " + line)
            if self.consoleErrors.count > 200 {
                self.consoleErrors.removeFirst(self.consoleErrors.count - 200)
            }
        }
    }

    func clearConsole() {
        consoleLogs.removeAll()
        consoleErrors.removeAll()
    }

    func save() {
        encode(tabs, key: "tabs")
        encode(bookmarks, key: "bookmarks")
        encode(history, key: "history")
        encode(scripts, key: "scripts")
        encode(settings, key: "settings")
        if let id = activeTabId {
            defaults.set(id.uuidString, forKey: "activeTabId")
        }
    }

    private func load() {
        tabs = decode([BrowserTab].self, key: "tabs") ?? []
        bookmarks = decode([Bookmark].self, key: "bookmarks") ?? []
        history = decode([HistoryEntry].self, key: "history") ?? []
        scripts = decode([UserScript].self, key: "scripts") ?? []
        settings = decode(BrowserSettings.self, key: "settings") ?? BrowserSettings()
        if let s = defaults.string(forKey: "activeTabId"), let id = UUID(uuidString: s) {
            activeTabId = id
        }
    }

    private func encode<T: Encodable>(_ v: T, key: String) {
        if let d = try? JSONEncoder().encode(v) {
            defaults.set(d, forKey: key)
        }
    }

    private func decode<T: Decodable>(_ t: T.Type, key: String) -> T? {
        guard let d = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(t, from: d)
    }

    private static func ts() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private static func defaultScripts() -> [UserScript] {
        [
            UserScript(
                name: "Dark hint (demo)",
                enabled: false,
                matches: "*",
                code: "document.documentElement.style.colorScheme='dark';",
                isCSS: false,
                runAtDocumentStart: true
            ),
            UserScript(
                name: "Hide common ad slots (CSS)",
                enabled: true,
                matches: "*",
                code: "iframe[src*=\"doubleclick\"], .adsbygoogle, [id*=\"google_ads\"] { display:none !important; }",
                isCSS: true,
                runAtDocumentStart: true
            ),
        ]
    }
}
