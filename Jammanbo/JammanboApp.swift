import SwiftUI

@main
struct JammanboApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sleepStore = SleepStore()
    @StateObject private var checkInStore = CheckInStore()

    @StateObject private var planStore = PlanStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sleepStore)
                .environmentObject(checkInStore)
                .environmentObject(planStore)
                .preferredColorScheme(.dark)
                .task { await sleepStore.refreshIfConnected() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await sleepStore.refreshIfConnected() }
                    }
                }
        }
    }
}
