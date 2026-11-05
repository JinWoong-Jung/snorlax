import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var sleepStore: SleepStore
    @EnvironmentObject private var checkInStore: CheckInStore
    @State private var shareURL: URL?
    @State private var exportError: String?

    private var nights: [SleepNight] { Array(sleepStore.nights.prefix(7)) }
    private var average: Int {
        guard !nights.isEmpty else { return 0 }
        return nights.reduce(0) { $0 + $1.totalMinutes } / nights.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("상담용 요약")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("필요한 기간을 선택해 기록을 한 페이지로 정리해요.")
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
                            metricRow("아침 체크인", value: "\(checkInStore.records.count)건")
                            metricRow("데이터 출처", value: sleepStore.sourceLabel)
                        }
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("최근 기록")
                                .font(.headline)
                            ForEach(nights.prefix(5)) { night in
                                HStack {
                                    Text(night.date.formatted(.dateTime.month(.abbreviated).day()))
                                        .foregroundStyle(JammanboPalette.muted)
                                    Spacer()
                                    Text(night.durationLabel)
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    Button(action: exportPDF) {
                        Label("요약 PDF 만들기", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(JammanboPalette.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(JammanboPalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label("PDF 공유하기", systemImage: "doc.richtext")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JammanboPalette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }

                    if let exportError {
                        Text(exportError)
                            .font(.caption)
                            .foregroundStyle(JammanboPalette.coral)
                    }

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

    private func exportPDF() {
        do {
            shareURL = try ReportPDFGenerator.create(nights: nights, checkIns: checkInStore.records, source: sleepStore.sourceLabel)
            exportError = nil
        } catch {
            exportError = "PDF를 만들지 못했습니다. 다시 시도해 주세요."
        }
    }
}
