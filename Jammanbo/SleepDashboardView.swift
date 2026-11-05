import SwiftUI

struct SleepDashboardView: View {
    @EnvironmentObject private var sleepStore: SleepStore

    private var latest: SleepNight { sleepStore.nights[0] }
    private var recentAverage: Int {
        let nights = Array(sleepStore.nights.prefix(7))
        guard !nights.isEmpty else { return 0 }
        return nights.reduce(0) { $0 + $1.totalMinutes } / nights.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    sleepCard
                    stageCard
                    trendCard
                    healthButton
                    if let message = sleepStore.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(JammanboPalette.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("잠만보")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: "sparkle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(JammanboPalette.accent)
                    .frame(width: 42, height: 42)
                    .background(JammanboPalette.surface, in: Circle())
            }
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(.subheadline)
                .foregroundStyle(JammanboPalette.muted)
            Text("오늘의 수면을 가볍게 돌아봐요.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 3)
        }
    }

    private var sleepCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("어젯밤 수면", systemImage: "moon.stars.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JammanboPalette.accent)
                    Spacer()
                    Text(latest.isSample ? "샘플" : "건강 앱")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(JammanboPalette.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(JammanboPalette.raised, in: Capsule())
                }
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(latest.durationLabel)
                        .font(.system(size: 35, weight: .bold, design: .rounded))
                        .tracking(-1.5)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("8시간 목표")
                            .font(.caption)
                            .foregroundStyle(JammanboPalette.muted)
                        Text("\(latest.targetProgress)%")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(JammanboPalette.lilac)
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(latest.date.formatted(.dateTime.month(.abbreviated).day()))
                    Text("기상 기준")
                }
                .font(.caption)
                .foregroundStyle(JammanboPalette.muted)
            }
        }
    }

    private var stageCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("수면 단계")
                        .font(.headline)
                    Spacer()
                    Text("총 \(latest.totalMinutes / 60)시간대")
                        .font(.caption)
                        .foregroundStyle(JammanboPalette.muted)
                }
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        let availableWidth = max(0, proxy.size.width - 6)
                        stageSegment(latest.deepMinutes, total: latest.totalMinutes, width: availableWidth, color: JammanboPalette.lilac)
                        stageSegment(latest.remMinutes, total: latest.totalMinutes, width: availableWidth, color: JammanboPalette.accent)
                        stageSegment(latest.coreMinutes, total: latest.totalMinutes, width: availableWidth, color: Color(red: 0.34, green: 0.52, blue: 0.78))
                    }
                    .frame(width: proxy.size.width, height: 12)
                }
                .frame(height: 12)
                HStack {
                    stageLegend("깊은 잠", value: latest.deepMinutes, color: JammanboPalette.lilac)
                    Spacer(minLength: 8)
                    stageLegend("렘수면", value: latest.remMinutes, color: JammanboPalette.accent)
                    Spacer(minLength: 8)
                    stageLegend("얕은 잠", value: latest.coreMinutes, color: Color(red: 0.34, green: 0.52, blue: 0.78))
                }
            }
        }
    }

    private var trendCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("최근 7일")
                            .font(.headline)
                        Text("평균 수면 시간")
                            .font(.caption)
                            .foregroundStyle(JammanboPalette.muted)
                    }
                    Spacer()
                    Text("\(recentAverage / 60)시간 \(recentAverage % 60)분")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JammanboPalette.accent)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(sleepStore.nights.prefix(7).reversed())) { night in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(night.id == latest.id ? JammanboPalette.accent : JammanboPalette.lilac.opacity(0.56))
                                .frame(height: max(16, CGFloat(night.totalMinutes) / 480 * 56))
                            Text(night.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2)
                                .foregroundStyle(JammanboPalette.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 78, alignment: .bottom)
            }
        }
    }

    private var healthButton: some View {
        Button {
            Task { await sleepStore.requestAccessAndRefresh() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(sleepStore.isLoading ? "건강 기록을 확인하고 있어요" : "Apple 건강 수면 기록 연결")
                        .font(.subheadline.weight(.semibold))
                    Text(sleepStore.sourceLabel)
                        .font(.caption)
                        .foregroundStyle(JammanboPalette.muted)
                }
                Spacer()
                if sleepStore.isLoading {
                    ProgressView().tint(JammanboPalette.accent)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(JammanboPalette.accent)
            .padding(16)
            .background(JammanboPalette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(sleepStore.isLoading)
    }

    private func stageSegment(_ value: Int, total: Int, width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(color)
            .frame(width: total > 0 ? width * CGFloat(value) / CGFloat(total) : 0, height: 12)
            .opacity(total > 0 ? 1 : 0.25)
    }

    private func stageLegend(_ title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption2).foregroundStyle(JammanboPalette.muted)
                Text("\(value / 60)시간 \(value % 60)분")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}
