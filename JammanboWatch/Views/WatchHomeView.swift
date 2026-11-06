import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var sessionStore: WatchSessionStore
    @State private var mood = "괜찮아요"
    @State private var stress = "보통"
    @State private var caffeine = false

    private let moods = ["개운해요", "괜찮아요", "피곤해요"]
    private let stressOptions = ["낮음", "보통", "높음"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Color(red: 0.45, green: 0.85, blue: 0.77))
                    Text("잠만보")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Text("좋은 아침이에요")
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 5) {
                    Label("어젯밤 수면", systemImage: "bed.double.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.72, green: 0.67, blue: 0.98))
                    Text("자세한 기록은 iPhone에서 확인")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.66))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))

                Text("일어난 뒤 기분")
                    .font(.caption.weight(.semibold))
                    .padding(.top, 2)

                ForEach(moods, id: \.self) { choice in
                    Button {
                        mood = choice
                    } label: {
                        HStack {
                            Text(choice)
                            Spacer(minLength: 4)
                            if mood == choice { Image(systemName: "checkmark.circle.fill") }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(mood == choice ? Color.black : Color.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(mood == choice ? Color(red: 0.45, green: 0.85, blue: 0.77) : Color.white.opacity(0.09), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("스트레스", systemImage: "brain.head.profile")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                    HStack(spacing: 4) {
                        ForEach(stressOptions, id: \.self) { choice in
                            Button {
                                stress = choice
                            } label: {
                                Text(choice)
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(stress == choice ? Color.orange : Color.white.opacity(0.09), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    caffeine.toggle()
                } label: {
                    Label(caffeine ? "카페인 기록됨" : "오후 카페인 없음", systemImage: "cup.and.saucer.fill")
                        .font(.caption2.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .tint(caffeine ? .orange : .gray)

                Button {
                    sessionStore.submit(mood: mood, stress: stress, caffeine: caffeine)
                } label: {
                    Text("체크인 저장")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .tint(Color(red: 0.45, green: 0.85, blue: 0.77))
                .buttonStyle(.borderedProminent)

                Text(sessionStore.status)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .background(Color(red: 0.035, green: 0.055, blue: 0.105).ignoresSafeArea())
    }
}
