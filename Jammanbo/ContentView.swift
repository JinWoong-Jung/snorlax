import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SleepDashboardView()
                .tabItem { Label("오늘", systemImage: "moon.zzz.fill") }
            CheckInView()
                .tabItem { Label("체크인", systemImage: "checkmark.circle.fill") }
            AskView()
                .tabItem { Label("질문", systemImage: "bubble.left.and.text.bubble.right.fill") }
            PlanView()
                .tabItem { Label("계획", systemImage: "calendar") }
            SummaryView()
                .tabItem { Label("요약", systemImage: "doc.text.fill") }
        }
        .tint(JammanboPalette.accent)
        .background(JammanboPalette.background)
    }
}
