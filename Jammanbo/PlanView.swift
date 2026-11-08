import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var planStore: PlanStore
    @State private var eventTitle = ""
    @State private var eventTime = Date.now
    @State private var eventDuration = 60
    @State private var wakeDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @FocusState private var eventTitleFocused: Bool
    private var recommendation: PlanRecommendation { planStore.recommendation(forWakeDate: wakeDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("이번 주 계획").font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("기상 날짜와 일정을 반영해 취침을 제안해요.")
                            .font(.subheadline).foregroundStyle(JammanboPalette.muted)
                    }
                    SoftCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("나의 수면 목표", systemImage: "target").foregroundStyle(JammanboPalette.accent)
                            DatePicker("기상 날짜", selection: $wakeDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                            HStack {
                                Text("목표 수면"); Spacer()
                                Text(duration(planStore.sleepGoalMinutes)).foregroundStyle(JammanboPalette.lilac)
                            }
                            Stepper("목표 수면 조절", value: $planStore.sleepGoalMinutes, in: 360...600, step: 15)
                            DatePicker("목표 기상 시간", selection: wakeBinding, displayedComponents: .hourAndMinute)
                        }
                    }
                    SoftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("일정 반영 취침 제안", systemImage: "sparkles").foregroundStyle(JammanboPalette.accent)
                            LabeledContent("기본 취침 목표", value: timeLabel(recommendation.baseBedtime))
                            LabeledContent("제안 취침", value: timeLabel(recommendation.bedtime)).fontWeight(.semibold)
                            if recommendation.isAdjusted {
                                Text("겹치는 일정: " + recommendation.conflictingEvents.map(\.title).joined(separator: ", "))
                                Text("일정 종료 후 준비 시간 30분을 확보하도록 제안을 늦췄어요. 선택한 수면·기상 목표 자체는 유지합니다.")
                                LabeledContent("기상 목표까지 확보 가능", value: duration(recommendation.availableMinutes))
                                LabeledContent("수면 목표보다 부족", value: duration(recommendation.shortfallMinutes))
                                if recommendation.availableMinutes == 0 {
                                    Text("기상 목표 전에 수면 시간을 확보할 수 없어요. 일정 또는 기상 목표를 조정해 주세요.").foregroundStyle(JammanboPalette.coral)
                                }
                                Text("수면 목표를 유지하려면 기상 시각을 \(timeLabel(recommendation.fullGoalWake))로 옮기는 방법도 있어요.")
                            } else {
                                Text("겹치는 일정이 없어 기상 목표에서 수면 목표를 뺀 시각을 제안합니다.")
                            }
                            Text("수동 입력 일정의 시작·종료 시각과 30분 준비 시간을 사용한 단순 제안입니다. 이동 시간이나 의료적 적정 수면을 추정하지 않습니다.")
                                .font(.caption).foregroundStyle(JammanboPalette.muted)
                        }
                        .font(.subheadline)
                    }
                    SoftCard {
                        VStack(alignment: .leading, spacing: 13) {
                            Label("직접 입력한 일정", systemImage: "calendar.badge.clock").foregroundStyle(JammanboPalette.accent)
                            TextField("예: 저녁 약속", text: $eventTitle)
                                .focused($eventTitleFocused).submitLabel(.done)
                                .onSubmit { eventTitleFocused = false }
                                .padding(12).background(JammanboPalette.raised, in: RoundedRectangle(cornerRadius: 13))
                            DatePicker("시작", selection: $eventTime, displayedComponents: [.date, .hourAndMinute])
                            Picker("지속 시간", selection: $eventDuration) {
                                ForEach([30, 60, 90, 120, 180, 240], id: \.self) { Text(duration($0)).tag($0) }
                            }
                            Text("종료 \(timeLabel(eventTime.addingTimeInterval(Double(eventDuration * 60))))")
                                .font(.caption).foregroundStyle(JammanboPalette.muted)
                            Button {
                                eventTitleFocused = false
                                if planStore.addEvent(title: eventTitle, time: eventTime, endTime: eventTime.addingTimeInterval(Double(eventDuration * 60))) { eventTitle = "" }
                            } label: {
                                Label("일정 추가", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .foregroundStyle(JammanboPalette.background).background(JammanboPalette.accent, in: Capsule())
                            }.buttonStyle(.plain)
                            ForEach(planStore.events.sorted { $0.time < $1.time }) { event in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                        Text("\(timeLabel(event.time)) – \(timeLabel(event.endTime))")
                                            .font(.caption).foregroundStyle(JammanboPalette.muted)
                                    }
                                    Spacer()
                                    Button { planStore.removeEvent(id: event.id) } label: { Image(systemName: "trash") }
                                        .accessibilityLabel("\(event.title) 삭제")
                                }
                            }
                            Text("기존에 시작 시각만 저장한 일정은 1시간 일정으로 표시합니다. 캘린더 계정과는 동기화하지 않습니다.")
                                .font(.caption2).foregroundStyle(JammanboPalette.muted)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: eventTime) { _, _ in eventTitleFocused = false }
            .onChange(of: wakeDate) { _, _ in eventTitleFocused = false }
            .onChange(of: planStore.wakeMinutes) { _, _ in eventTitleFocused = false }
            .onChange(of: planStore.sleepGoalMinutes) { _, _ in eventTitleFocused = false }
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("완료") { eventTitleFocused = false } }
            }
        }
    }
    private var wakeBinding: Binding<Date> {
        Binding(get: { planStore.wakeTime(on: wakeDate) }, set: {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            planStore.wakeMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
        })
    }
    private func duration(_ minutes: Int) -> String { "\(minutes / 60)시간 \(minutes % 60)분" }
    private func timeLabel(_ date: Date) -> String { date.formatted(.dateTime.month().day().hour().minute()) }
}
