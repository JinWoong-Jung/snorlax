import SwiftUI

private struct PlanEvent: Codable, Identifiable {
    let id: UUID
    let title: String
    let time: Date

    init(id: UUID = UUID(), title: String, time: Date) {
        self.id = id
        self.title = title
        self.time = time
    }
}

struct PlanView: View {
    @AppStorage("jammanbo.targetWakeMinutes") private var wakeMinutes = 420
    @AppStorage("jammanbo.targetSleepMinutes") private var sleepGoalMinutes = 480
    @State private var eventTitle = ""
    @State private var eventTime = Date.now
    @State private var events = PlanView.loadEvents()

    private var wakeTime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = wakeMinutes / 60
        components.minute = wakeMinutes % 60
        return Calendar.current.date(from: components) ?? .now
    }

    private var suggestedBedtime: Date {
        Calendar.current.date(byAdding: .minute, value: -sleepGoalMinutes, to: wakeTime) ?? wakeTime
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("이번 주 계획")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("목표 기상 시간과 일정을 기준으로 수면 시간을 정해요.")
                            .font(.subheadline)
                            .foregroundStyle(JammanboPalette.muted)
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 17) {
                            Label("나의 수면 목표", systemImage: "target")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JammanboPalette.accent)
                            HStack {
                                Text("목표 수면")
                                Spacer()
                                Text("\(sleepGoalMinutes / 60)시간 \(sleepGoalMinutes % 60)분")
                                    .foregroundStyle(JammanboPalette.lilac)
                            }
                            Stepper("", value: $sleepGoalMinutes, in: 360...600, step: 15)
                                .labelsHidden()
                            HStack {
                                Text("목표 기상 시간")
                                Spacer()
                                DatePicker("기상", selection: wakeBinding, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(JammanboPalette.accent)
                            }
                        }
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("오늘 제안", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JammanboPalette.accent)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("취침 목표")
                                    .font(.subheadline)
                                    .foregroundStyle(JammanboPalette.muted)
                                Spacer()
                                Text(suggestedBedtime.formatted(.dateTime.hour().minute()))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                            }
                            Text("기상 목표에서 설정한 수면 시간을 거꾸로 계산했어요. 일정과 몸 상태에 맞게 조정해 주세요.")
                                .font(.caption)
                                .foregroundStyle(JammanboPalette.muted)
                        }
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 13) {
                            Label("직접 입력한 일정", systemImage: "calendar.badge.clock")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JammanboPalette.accent)
                            TextField("예: 저녁 운동", text: $eventTitle)
                                .padding(12)
                                .background(JammanboPalette.raised, in: RoundedRectangle(cornerRadius: 13))
                            HStack {
                                Text("일정 시간")
                                    .font(.subheadline)
                                Spacer()
                                DatePicker("일정 시간", selection: $eventTime, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                            Button(action: addEvent) {
                                Label("일정 추가", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(JammanboPalette.background)
                                    .background(JammanboPalette.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            ForEach(events.sorted { $0.time < $1.time }) { event in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.title).font(.subheadline.weight(.medium))
                                        Text(event.time.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                            .font(.caption)
                                            .foregroundStyle(JammanboPalette.muted)
                                    }
                                    Spacer()
                                    Button {
                                        events.removeAll { $0.id == event.id }
                                        saveEvents()
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(JammanboPalette.muted)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 5)
                            }
                        }
                    }

                    Text("일정은 이 기기에 저장됩니다. 캘린더 계정과는 아직 동기화하지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(JammanboPalette.muted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var wakeBinding: Binding<Date> {
        Binding(
            get: { wakeTime },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                wakeMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func addEvent() {
        let title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        events.append(PlanEvent(title: title, time: eventTime))
        saveEvents()
        eventTitle = ""
    }

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: "jammanbo.planEvents.v1")
    }

    private static func loadEvents() -> [PlanEvent] {
        guard let data = UserDefaults.standard.data(forKey: "jammanbo.planEvents.v1"),
              let events = try? JSONDecoder().decode([PlanEvent].self, from: data) else { return [] }
        return events
    }
}
