import SwiftUI

@main
struct JammanboWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sessionStore = WatchSessionStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(sessionStore)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { sessionStore.resume() }
                }
        }
        .backgroundTask(.watchConnectivity) {
            await sessionStore.handleBackgroundDelivery()
        }
    }
}
