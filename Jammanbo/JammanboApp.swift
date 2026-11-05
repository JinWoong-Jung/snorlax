import SwiftUI

@main
struct JammanboApp: App {
    @StateObject private var sleepStore = SleepStore()
    @StateObject private var checkInStore = CheckInStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sleepStore)
                .environmentObject(checkInStore)
                .preferredColorScheme(.dark)
        }
    }
}
