import Foundation

struct BrowserTab: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = "Nouvel onglet"
    var urlString: String = "https://duckduckgo.com"
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var desktopMode: Bool = false
}

struct Bookmark: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var urlString: String
    var createdAt: Date = Date()
}

struct HistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var urlString: String
    var visitedAt: Date = Date()
}

struct UserScript: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var enabled: Bool = true
    /// "*" = all sites, or host substring match
    var matches: String = "*"
    var code: String
    var isCSS: Bool = false
    var runAtDocumentStart: Bool = false
}

struct ProxyConfig: Codable, Equatable {
    var enabled: Bool = false
    var type: String = "HTTP" // HTTP | SOCKS5
    var host: String = ""
    var port: Int = 8080
    var username: String = ""
    var password: String = ""
}

struct BrowserSettings: Codable, Equatable {
    var searchEngineURL: String = "https://duckduckgo.com/?q="
    var homepage: String = "https://duckduckgo.com"
    var blockAds: Bool = true
    var blockTrackers: Bool = true
    var desktopByDefault: Bool = false
    var proxy: ProxyConfig = ProxyConfig()
    var customUserAgent: String = ""
}
