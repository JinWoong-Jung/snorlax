import SwiftUI

@main
struct JammanboWatchApp: App {
    @StateObject private var sessionStore = WatchSessionStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(sessionStore)
        }
    }
}
