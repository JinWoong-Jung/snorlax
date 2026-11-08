import SwiftUI

struct CheckInView: View {
    @EnvironmentObject private var checkInStore: CheckInStore
    @State private var mood = "괜찮아요"
    @State private var stress = "보통"
    @State private var caffeine = false
    @State private var exercise: Bool? = nil
    @State private var savedMessage: String?

    private let moods = ["개운해요", "괜찮아요", "피곤해요"]
    private let stressOptions = ["낮음", "보통", "높음"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("아침 체크인")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("몇 번의 선택으로 수면과 하루를 연결해요.")
                            .font(.subheadline)
                            .foregroundStyle(JammanboPalette.muted)
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("지금 기분은 어때요?", icon: "face.smiling")
                            choiceRow(options: moods, selection: $mood)
                        }
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("어제의 생활 맥락", icon: "sun.max")
                            Text("스트레스")
                                .font(.caption)
                                .foregroundStyle(JammanboPalette.muted)
                            choiceRow(options: stressOptions, selection: $stress)
                            Toggle(isOn: $caffeine) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("오후에 카페인을 마셨어요")
                                        .font(.subheadline.weight(.medium))
                                    Text("커피, 차, 에너지 음료")
                                        .font(.caption)
                                        .foregroundStyle(JammanboPalette.muted)
                                }
                            }
                            .tint(JammanboPalette.accent)
                            Picker("전날 운동", selection: $exercise) {
                                Text("미기록").tag(Optional<Bool>.none)
                                Text("했어요").tag(Optional(true))
                                Text("안 했어요").tag(Optional(false))
                            }
                            .pickerStyle(.segmented)
                            Text("전날 운동 여부 · 미기록은 비교에서 제외해요.")
                                .font(.caption).foregroundStyle(JammanboPalette.muted)
                        }
                    }

                    Button {
                        checkInStore.saveFromPhone(mood: mood, stress: stress, caffeine: caffeine, exercise: exercise)
                        savedMessage = "체크인을 저장했어요. 아래 최근 기록에서 확인할 수 있어요."
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("오늘 체크인 저장")
                        }
                        .font(.headline)
                        .foregroundStyle(JammanboPalette.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(JammanboPalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if let savedMessage {
                        Text(savedMessage).font(.caption).foregroundStyle(JammanboPalette.accent)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "applewatch")
                        Text(checkInStore.connectionLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(JammanboPalette.muted)
                    .frame(maxWidth: .infinity)

                    if !checkInStore.records.isEmpty {
                        recordsCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var recordsCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("최근 체크인")
                    .font(.headline)
                NavigationLink {
                    CheckInHistoryView()
                } label: {
                    Label("전체 기록 \(checkInStore.records.count)건 보기", systemImage: "list.bullet")
                        .font(.subheadline).foregroundStyle(JammanboPalette.accent)
                }
                ForEach(checkInStore.records.prefix(4)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(record.mood) · 스트레스 \(record.stress)")
                                .font(.subheadline.weight(.medium))
                            Text(record.exerciseLabel).font(.caption).foregroundStyle(JammanboPalette.muted)
                            Text(record.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()) + " · " + record.source)
                                .font(.caption)
                                .foregroundStyle(JammanboPalette.muted)
                        }
                        Spacer()
                        if record.caffeine {
                            Text("카페인")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(JammanboPalette.coral)
                        }
                    }
                    if record.id != checkInStore.records.prefix(4).last?.id { Divider().overlay(.white.opacity(0.1)) }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(JammanboPalette.accent)
    }

    private func choiceRow(options: [String], selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    Text(option)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selection.wrappedValue == option ? JammanboPalette.background : .white.opacity(0.84))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selection.wrappedValue == option ? JammanboPalette.accent : JammanboPalette.raised, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
