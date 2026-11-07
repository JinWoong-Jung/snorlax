import Foundation

struct AnswerCard {
    let text: String
    let evidence: String
}

/// Local, deterministic analysis. No network calls or persistent answer storage.
enum AnalysisService {
    static func answer(question: String, summary: ReportSummary, calendar: Calendar = .current) -> AnswerCard {
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !normalized.isEmpty else {
            return AnswerCard(text: "질문을 입력하거나 아래 예시를 선택해 주세요.", evidence: "질문 입력 안내")
        }
        let nights = summary.nights
        guard !nights.isEmpty else {
            return AnswerCard(text: "아직 확인할 수면 기록이 없습니다. Apple 건강 연결과 읽기 권한을 확인해 주세요.", evidence: summary.source)
        }
        if normalized.contains("카페인") || normalized.contains("스트레스") {
            return lifestyleComparison(question: normalized, summary: summary, calendar: calendar)
        }
        if normalized.contains("깊") || normalized.contains("렘") || normalized.contains("단계") {
            let asksForRem = normalized.contains("렘")
            let stageName = asksForRem ? "렘수면" : "깊은 잠"
            guard let night = nights.first(where: { asksForRem ? $0.hasRemStageData : $0.hasDeepStageData }) else {
                return AnswerCard(
                    text: "최근 수면 기록에서 \(stageName) 단계 정보가 제공되지 않았어요. 기기나 HealthKit이 이 단계를 기록하지 않았을 수 있습니다.",
                    evidence: "최근 7일 수면 기록 · \(summary.source)"
                )
            }
            let minutes = asksForRem ? night.remMinutes : night.deepMinutes
            return AnswerCard(
                text: "최근 기록에서 \(stageName)은 \(minutes / 60)시간 \(minutes % 60)분입니다. 수면 단계는 기록 기기와 HealthKit 데이터에 따라 표시 항목이 다를 수 있어요.",
                evidence: "\(night.date.formatted(.dateTime.month(.abbreviated).day())) · \(summary.source)"
            )
        }
        let averageKeywords = ["평균", "수면시간", "수면 시간", "얼마나 잤", "몇 시간 잤", "몇시간 잤", "총 수면"]
        guard averageKeywords.contains(where: { normalized.contains($0) }) else {
            return AnswerCard(text: "현재는 최근 평균 수면시간, 깊은 잠·렘수면, 카페인·스트레스 비교 질문을 지원해요. 아래 예시 질문을 선택해 보세요.", evidence: "지원 질문 범위")
        }
        return AnswerCard(
            text: "최근 \(nights.count)개 수면 기록의 평균은 \(summary.averageMinutes / 60)시간 \(summary.averageMinutes % 60)분입니다. 가장 최근 기록은 \(nights[0].durationLabel)입니다.",
            evidence: nights.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) }.joined(separator: ", ") + " · " + summary.source
        )
    }

    private static func lifestyleComparison(question: String, summary: ReportSummary, calendar: Calendar) -> AnswerCard {
        guard !summary.nights.contains(where: { $0.isSample }) else {
            return AnswerCard(
                text: "샘플 수면 기록으로 개인 체크인과의 차이를 계산하지 않아요. Apple 건강에서 실제 수면 기록을 연결한 뒤 비교해 주세요.",
                evidence: "수면 출처 \(summary.source) · 샘플 수면과 개인 생활습관의 비교 제외"
            )
        }
        let isCaffeine = question.contains("카페인")
        let grouped = Dictionary(grouping: summary.checkIns) { calendar.startOfDay(for: $0.date) }
        let values: [(date: Date, observed: Bool, minutes: Int, source: String)] = grouped.compactMap { day, records in
            guard let checkIn = records.max(by: { $0.date < $1.date }),
                  let night = summary.nights.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) else { return nil }
            return (day, isCaffeine ? checkIn.caffeine : checkIn.stress == "높음", night.totalMinutes, checkIn.source)
        }.sorted { $0.date < $1.date }
        let exposed = values.filter { $0.observed }
        let comparison = values.filter { !$0.observed }
        let dates = values.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) }.joined(separator: ", ")
        let sources = Set(values.map { $0.source }).sorted().joined(separator: ", ")
        let evidence = "비교 날짜 \(dates.isEmpty ? "없음" : dates) · 조건 있음 \(exposed.count)일 / 없음 \(comparison.count)일 · 수면 출처 \(summary.source) · 체크인 출처 \(sources.isEmpty ? "없음" : sources)"
        let label = isCaffeine ? "오후 카페인" : "높은 스트레스"
        guard exposed.count >= 2, comparison.count >= 2 else {
            return AnswerCard(text: "\(label) 여부를 비교하려면 양쪽 조건에 해당하는 같은 날짜의 수면·체크인 기록이 각각 최소 2일 필요합니다. 현재는 더 많은 기록이 필요해요.", evidence: evidence)
        }
        let exposedAverage = exposed.reduce(0) { $0 + $1.minutes } / exposed.count
        let comparisonAverage = comparison.reduce(0) { $0 + $1.minutes } / comparison.count
        let difference = abs(exposedAverage - comparisonAverage)
        let result = difference == 0
            ? "입력한 기록에서 \(label) 조건별 평균 수면시간의 차이가 없었습니다."
            : "입력한 기록에서는 \(label)이 있었던 날의 수면이 없었던 날보다 평균 \(difference / 60)시간 \(difference % 60)분 \(exposedAverage < comparisonAverage ? "짧았습니다" : "길었습니다")."
        return AnswerCard(text: result + " 이 비교는 같은 날짜에 입력한 기록의 단순 평균이며 원인이나 효과를 뜻하지 않습니다.", evidence: evidence)
    }
}
