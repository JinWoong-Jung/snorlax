import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var planStore: PlanStore
    @State private var eventTitle = ""
    @State private var eventTime = Date.now
    @FocusState private var eventTitleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("이번 주 계획")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("수면·기상 목표를 정하고 일정을 기록해요.")
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
                                Text("\(planStore.sleepGoalMinutes / 60)시간 \(planStore.sleepGoalMinutes % 60)분")
                                    .foregroundStyle(JammanboPalette.lilac)
                            }
                            Stepper("", value: $planStore.sleepGoalMinutes, in: 360...600, step: 15)
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
                                Text(planStore.suggestedBedtime().formatted(.dateTime.hour().minute()))
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
                                .focused($eventTitleFocused)
                                .submitLabel(.done)
                                .onSubmit { eventTitleFocused = false }
                                .padding(12)
                                .background(JammanboPalette.raised, in: RoundedRectangle(cornerRadius: 13))
                            HStack {
                                Text("일정 시간")
                                    .font(.subheadline)
                                Spacer()
                                DatePicker("일정 시간", selection: $eventTime, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                            Button {
                                eventTitleFocused = false
                                addEvent()
                            } label: {
                                Label("일정 추가", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(JammanboPalette.background)
                                    .background(JammanboPalette.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            ForEach(planStore.events.sorted { $0.time < $1.time }) { event in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.title).font(.subheadline.weight(.medium))
                                        Text(event.time.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                            .font(.caption)
                                            .foregroundStyle(JammanboPalette.muted)
                                    }
                                    Spacer()
                                    Button {
                                        planStore.removeEvent(id: event.id)
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
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: eventTime) { _, _ in eventTitleFocused = false }
            .onChange(of: planStore.wakeMinutes) { _, _ in eventTitleFocused = false }
            .onChange(of: planStore.sleepGoalMinutes) { _, _ in eventTitleFocused = false }
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") {
                        eventTitleFocused = false
                    }
                }
            }
        }
    }

    private var wakeBinding: Binding<Date> {
        Binding(
            get: { planStore.wakeTime() },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                planStore.wakeMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func addEvent() {
        if planStore.addEvent(title: eventTitle, time: eventTime) {
            eventTitle = ""
        }
    }
}
