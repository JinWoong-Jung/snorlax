import SwiftUI

struct AskView: View {
    @EnvironmentObject private var sleepStore: SleepStore
    @EnvironmentObject private var checkInStore: CheckInStore
    @State private var question = ""
    @State private var answer: AnswerCard?
    @FocusState private var questionFieldFocused: Bool

    private let suggestions = ["최근 평균 수면은?", "깊은 잠은 얼마나 잤어?", "카페인과 수면을 비교해줘"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("내 기록에 질문")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("답변에는 사용한 날짜와 기록을 함께 표시해요.")
                            .font(.subheadline)
                            .foregroundStyle(JammanboPalette.muted)
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("예: 최근 평균 수면은?", text: $question, axis: .vertical)
                                .lineLimit(1...3)
                                .focused($questionFieldFocused)
                                .submitLabel(.search)
                                .onSubmit {
                                    questionFieldFocused = false
                                    ask()
                                }
                                .padding(13)
                                .background(JammanboPalette.raised, in: RoundedRectangle(cornerRadius: 15))
                            Button {
                                questionFieldFocused = false
                                ask()
                            } label: {
                                Label("기록에서 답 찾기", systemImage: "sparkle.magnifyingglass")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .foregroundStyle(JammanboPalette.background)
                                    .background(JammanboPalette.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("이렇게 물어볼 수 있어요")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JammanboPalette.muted)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                question = suggestion
                                questionFieldFocused = false
                                ask()
                            } label: {
                                HStack {
                                    Text(suggestion)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(14)
                                .background(JammanboPalette.surface, in: RoundedRectangle(cornerRadius: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let answer {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("기록 요약", systemImage: "quote.bubble.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(JammanboPalette.accent)
                                Text(answer.text)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                Divider().overlay(.white.opacity(0.1))
                                Text("근거 · \(answer.evidence)")
                                    .font(.caption)
                                    .foregroundStyle(JammanboPalette.muted)
                            }
                        }
                    }

                    Text("잠만보는 기록을 요약하며 수면 상태를 진단하지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(JammanboPalette.muted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    questionFieldFocused = false
                }
            }
        }
    }

    private func ask() {
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !normalized.isEmpty else {
            answer = AnswerCard(text: "질문을 입력하거나 아래 예시를 선택해 주세요.", evidence: "질문 입력 안내")
            return
        }
        let nights = Array(sleepStore.nights.prefix(7))
        guard !nights.isEmpty else {
            answer = AnswerCard(text: "아직 확인할 수면 기록이 없습니다. Apple 건강을 연결하거나 기록을 추가해 주세요.", evidence: sleepStore.sourceLabel)
            return
        }

        if normalized.contains("카페인") || normalized.contains("스트레스") {
            answer = lifestyleComparison(for: normalized, nights: nights)
            return
        }

        if normalized.contains("깊") || normalized.contains("렘") || normalized.contains("단계") {
            let asksForRem = normalized.contains("렘")
            guard let night = nights.first(where: { asksForRem ? $0.hasRemStageData : $0.hasDeepStageData }) else {
                let stageName = asksForRem ? "렘수면" : "깊은 잠"
                answer = AnswerCard(
                    text: "최근 수면 기록에서 \(stageName) 단계 정보가 제공되지 않았어요. 기기나 HealthKit이 이 단계를 기록하지 않았을 수 있습니다.",
                    evidence: "최근 수면 기록 · \(sleepStore.sourceLabel)"
                )
                return
            }
            let stage = asksForRem ? ("렘수면", night.remMinutes) : ("깊은 잠", night.deepMinutes)
            answer = AnswerCard(
                text: "최근 기록에서 \(stage.0)은 \(stage.1 / 60)시간 \(stage.1 % 60)분입니다. 수면 단계는 기록 기기와 HealthKit 데이터에 따라 표시 항목이 다를 수 있어요.",
                evidence: "\(night.date.formatted(.dateTime.month(.abbreviated).day())) · \(sleepStore.sourceLabel)"
            )
            return
        }

        let asksForAverage = ["평균", "수면시간", "수면 시간", "얼마나 잤", "몇 시간 잤", "몇시간 잤", "총 수면"].contains { normalized.contains($0) }
        guard asksForAverage else {
            answer = AnswerCard(
                text: "현재는 최근 평균 수면시간, 깊은 잠·렘수면, 카페인·스트레스 비교 질문을 지원해요. 아래 예시 질문을 선택해 보세요.",
                evidence: "지원 질문 범위"
            )
            return
        }

        answer = averageAnswer(for: nights)
    }

    private func lifestyleComparison(for question: String, nights: [SleepNight]) -> AnswerCard {
        let isCaffeine = question.contains("카페인")
        let calendar = Calendar.current
        let groupedCheckIns = Dictionary(grouping: checkInStore.records) { calendar.startOfDay(for: $0.date) }
        let values: [(date: Date, observed: Bool, minutes: Int, checkInSource: String)] = groupedCheckIns.compactMap { day, dayRecords in
            guard let checkIn = dayRecords.max(by: { $0.date < $1.date }),
                  let night = nights.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) else { return nil }
            let observed = isCaffeine ? checkIn.caffeine : checkIn.stress == "높음"
            return (day, observed, night.totalMinutes, checkIn.source)
        }.sorted { $0.date < $1.date }

        let exposed = values.filter { $0.observed }
        let comparison = values.filter { !$0.observed }
        let label = isCaffeine ? "오후 카페인" : "높은 스트레스"
        let minimumDaysPerGroup = 2
        let evidence = comparisonEvidence(values)
        guard exposed.count >= minimumDaysPerGroup, comparison.count >= minimumDaysPerGroup else {
            return AnswerCard(
                text: "\(label) 여부를 비교하려면 양쪽 조건에 해당하는 같은 날짜의 수면·체크인 기록이 각각 최소 \(minimumDaysPerGroup)일 필요합니다. 현재는 더 많은 기록이 필요해요.",
                evidence: evidence
            )
        }

        let exposedAverage = exposed.reduce(0) { $0 + $1.minutes } / exposed.count
        let comparisonAverage = comparison.reduce(0) { $0 + $1.minutes } / comparison.count
        let difference = abs(exposedAverage - comparisonAverage)
        let direction = exposedAverage < comparisonAverage ? "짧았습니다" : "길었습니다"
        return AnswerCard(
            text: "입력한 기록에서는 \(label)이 있었던 날의 수면이 없었던 날보다 평균 \(difference / 60)시간 \(difference % 60)분 \(direction). 이 비교는 현재 기록의 단순 평균이며 원인이나 효과를 뜻하지 않습니다.",
            evidence: evidence
        )
    }

    private func averageAnswer(for nights: [SleepNight]) -> AnswerCard {
        let average = nights.reduce(0) { $0 + $1.totalMinutes } / nights.count
        return AnswerCard(
            text: "최근 \(nights.count)개 수면 기록의 평균은 \(average / 60)시간 \(average % 60)분입니다. 가장 최근 기록은 \(nights[0].durationLabel)입니다.",
            evidence: nights.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) }.joined(separator: ", ") + " · " + sleepStore.sourceLabel
        )
    }

    private func comparisonEvidence(_ values: [(date: Date, observed: Bool, minutes: Int, checkInSource: String)]) -> String {
        let dates = values.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) }.joined(separator: ", ")
        let checkInSources = Set(values.map { $0.checkInSource }).sorted().joined(separator: ", ")
        return "비교 날짜 \(dates.isEmpty ? "없음" : dates) · 수면 출처 \(sleepStore.sourceLabel) · 체크인 출처 \(checkInSources.isEmpty ? "없음" : checkInSources)"
    }
}

private struct AnswerCard {
    let text: String
    let evidence: String
}
