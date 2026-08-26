import Foundation

enum AdBlock {
    /// Domaines / motifs basiques (pas une full EasyList, mais efficace en mobile)
    static let blockedHosts: Set<String> = [
        "doubleclick.net", "googleadservices.com", "googlesyndication.com",
        "pagead2.googlesyndication.com", "adservice.google.com",
        "facebook.net", "connect.facebook.net", "scorecardresearch.com",
        "adnxs.com", "adsrvr.org", "taboola.com", "outbrain.com",
        "hotjar.com", "clarity.ms", "moatads.com", "criteo.com",
        "amazon-adsystem.com", "advertising.com", "adsafeprotected.com",
    ]

    static let blockedPathKeywords = [
        "/ads/", "/ad/", "/advert", "/tracking", "/beacon",
        "pixel.gif", "analytics.js", "gtm.js",
    ]

    static func shouldBlock(url: URL, settings: BrowserSettings) -> Bool {
        guard settings.blockAds || settings.blockTrackers else { return false }
        let host = (url.host ?? "").lowercased()
        if settings.blockAds || settings.blockTrackers {
            for b in blockedHosts {
                if host == b || host.hasSuffix("." + b) { return true }
            }
        }
        let full = url.absoluteString.lowercased()
        if settings.blockAds {
            for k in blockedPathKeywords where full.contains(k) { return true }
        }
        return false
    }
}
