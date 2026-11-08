import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var sleepStore: SleepStore
    @EnvironmentObject private var checkInStore: CheckInStore
    @State private var choosingData = false

    private var summary: ReportSummary {
        ReportSummary(nights: sleepStore.nights, checkIns: checkInStore.records, source: sleepStore.sourceLabel)
    }
    private var nights: [SleepNight] { summary.nights }
    private var average: Int { summary.averageMinutes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("상담용 요약")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("최근 7일 중 공유할 날짜와 항목을 직접 선택해요.")
                            .font(.subheadline)
                            .foregroundStyle(JammanboPalette.muted)
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("최근 7일 요약", systemImage: "doc.text.magnifyingglass")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JammanboPalette.accent)
                            metricRow("평균 수면 시간", value: "\(average / 60)시간 \(average % 60)분")
                            metricRow("확인한 수면 기록", value: "\(nights.count)일")
                            metricRow("최근 7일 아침 체크인", value: "\(summary.checkIns.count)건")
                            metricRow("데이터 출처", value: sleepStore.sourceLabel)
                        }
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("최근 기록")
                                .font(.headline)
                            ForEach(nights) { night in
                                NavigationLink { SleepNightDetailView(date: night.date) } label: {
                                    HStack {
                                        Text(night.date.formatted(.dateTime.month(.abbreviated).day()))
                                            .foregroundStyle(JammanboPalette.muted)
                                        Spacer()
                                        Text(night.durationLabel)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    Button { choosingData = true } label: {
                        Label("공유할 데이터 선택", systemImage: "checklist")
                            .font(.headline).foregroundStyle(JammanboPalette.background)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(JammanboPalette.accent, in: Capsule())
                    }.buttonStyle(.plain)
                    Text("데이터 선택 → PDF 미리보기 → 최종 동의 → 공유 대상 선택. 자동 전송하지 않습니다.")
                        .font(.caption).foregroundStyle(JammanboPalette.muted)

                    Text("요약은 상담 대화를 돕기 위한 참고 자료이며 진단·치료 결과를 의미하지 않습니다. 공유 전에 내용과 수신자를 확인해 주세요.")
                        .font(.caption2)
                        .foregroundStyle(JammanboPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $choosingData) { ReportExportFlow() }
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(JammanboPalette.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

}
