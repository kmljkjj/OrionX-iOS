import SwiftUI

@main
struct OrionXApp: App {
    @StateObject private var store = BrowserStore()

    var body: some Scene {
        WindowGroup {
            BrowserRootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
