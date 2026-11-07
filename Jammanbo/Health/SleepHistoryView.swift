import SwiftUI

struct SleepHistoryView: View {
    @EnvironmentObject private var sleepStore: SleepStore

    var body: some View {
        List {
            Section {
                ForEach(sleepStore.nights) { night in
                    NavigationLink {
                        SleepNightDetailView(date: night.date)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(night.date.formatted(.dateTime.month().day().weekday()))
                                Text(night.isSample ? "샘플 기록" : "건강 앱 · 수면 종료일 기준")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(night.durationLabel).fontWeight(.semibold)
                        }
                    }
                    .listRowBackground(JammanboPalette.surface)
                }
            } footer: {
                Text("오늘을 포함한 최근 7일의 기록입니다. 여러 수면 구간은 마지막으로 잠에서 깬 날짜에 합산해요.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(JammanboPalette.background)
        .navigationTitle("최근 7일 수면")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .refreshable { await sleepStore.refreshIfConnected() }
    }
}

struct SleepNightDetailView: View {
    let date: Date
    @EnvironmentObject private var sleepStore: SleepStore
    @EnvironmentObject private var checkInStore: CheckInStore

    private var night: SleepNight? { sleepStore.nights.first { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private var checkIns: [CheckIn] { checkInStore.records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }

    var body: some View {
        List {
            if let night {
                Section("수면 요약") {
                    row("총 수면", night.durationLabel)
                    row("출처", night.isSample ? "샘플 기록" : "Apple 건강 기록")
                    if let start = night.startDate, let end = night.endDate {
                        row("첫 수면 시작", start.formatted(.dateTime.month().day().hour().minute()))
                        row("마지막 수면 종료", end.formatted(.dateTime.month().day().hour().minute()))
                    }
                }
                Section("수면 단계") {
                    row("깊은 잠", night.hasDeepStageData ? duration(night.deepMinutes) : "미제공")
                    row("렘수면", night.hasRemStageData ? duration(night.remMinutes) : "미제공")
                    row("코어 수면", night.hasCoreStageData ? duration(night.coreMinutes) : "미제공")
                    if night.unclassifiedMinutes > 0 { row("단계 미분류", duration(night.unclassifiedMinutes)) }
                }
                Section {
                    if checkIns.isEmpty { Text("이 날짜의 체크인이 없습니다.").foregroundStyle(.secondary) }
                    ForEach(checkIns) { record in
                        NavigationLink { CheckInDetailView(id: record.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(record.mood) · 스트레스 \(record.stress)")
                                Text("\(record.caffeine ? "오후 카페인 있음" : "오후 카페인 없음") · \(record.source)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: { Text("같은 날짜의 체크인") } footer: {
                    Text(night.isSample ? "샘플 수면과 개인 체크인은 생활습관 비교에 사용하지 않습니다." : "수면 기록은 건강 앱에서 관리합니다. 잠만보는 수면을 수정하지 않습니다.")
                }
            } else {
                ContentUnavailableView("기록을 확인할 수 없어요", systemImage: "bed.double", description: Text("최근 7일 목록을 새로 확인해 주세요."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(JammanboPalette.background)
        .navigationTitle(date.formatted(.dateTime.month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
            .listRowBackground(JammanboPalette.surface)
    }
    private func duration(_ minutes: Int) -> String { "\(minutes / 60)시간 \(minutes % 60)분" }
}
