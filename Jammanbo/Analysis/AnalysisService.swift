import Foundation

struct AnswerCard {
    let text: String
    let evidence: String
}

/// Deterministic record queries; descriptive differences are never significance or causal claims.
enum AnalysisService {
    static let comparisonPolicy = "같은 기상일의 수면과 하루 마지막 체크인을 연결합니다. 조건별 최소 2일은 계산을 위한 최소 자료 수이며 통계적 유의성 기준이 아닙니다. 양쪽 평균과 차이를 표시할 뿐, 의미 있는 변화·원인·효과를 판정하지 않습니다."

    private enum Habit: CaseIterable {
        case caffeine, stress, exercise
        var words: [String] {
            switch self {
            case .caffeine: return ["카페인", "커피", "녹차", "홍차", "에너지음료", "caffeine", "coffee"]
            case .stress: return ["스트레스", "긴장", "압박", "stress"]
            case .exercise: return ["운동", "산책", "러닝", "달리기", "조깅", "헬스", "요가", "exercise", "workout", "running"]
            }
        }
        var label: String {
            switch self { case .caffeine: return "오후 카페인"; case .stress: return "높은 스트레스"; case .exercise: return "전날 운동" }
        }
        func observed(_ record: CheckIn) -> Bool? {
            switch self { case .caffeine: return record.caffeine; case .stress: return record.stress == "높음"; case .exercise: return record.exercise }
        }
    }

    static func answer(question: String, summary: ReportSummary, calendar: Calendar = .current) -> AnswerCard {
        let normalized = question.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ko_KR"))
            .filter { !$0.isWhitespace && !$0.isPunctuation }
        guard !normalized.isEmpty else { return AnswerCard(text: "질문을 입력하거나 아래 예시를 선택해 주세요.", evidence: "질문 입력 안내") }
        guard !summary.nights.isEmpty else { return AnswerCard(text: "아직 확인할 수면 기록이 없습니다. Apple 건강 연결과 읽기 권한을 확인해 주세요.", evidence: summary.source) }
        let habits = Habit.allCases.filter { habit in habit.words.contains { normalized.contains($0) } }
        if habits.count > 1 { return AnswerCard(text: "운동·카페인·스트레스 중 한 가지 조건씩 물어봐 주세요. 여러 조건의 복합 효과는 계산하지 않습니다.", evidence: "비교 조건 선택 안내 · " + comparisonPolicy) }
        if let habit = habits.first { return lifestyleComparison(habit: habit, summary: summary, calendar: calendar) }
        if ["의미", "유의", "판단", "기준", "변화", "차이"].contains(where: normalized.contains) {
            return AnswerCard(text: comparisonPolicy + " 운동·카페인·스트레스 중 비교할 조건을 알려 주세요.", evidence: "비교 계산 기준 · 최근 7일 · " + summary.source)
        }
        let rem = ["렘", "rem"].contains(where: normalized.contains)
        let core = ["얕", "코어", "core"].contains(where: normalized.contains)
        let deep = ["깊", "딥", "deep"].contains(where: normalized.contains)
        if rem || core || deep || normalized.contains("단계") {
            let name = rem ? "렘수면" : core ? "코어 수면" : "깊은 잠"
            guard let night = summary.nights.first(where: { rem ? $0.hasRemStageData : core ? $0.hasCoreStageData : $0.hasDeepStageData }) else {
                return AnswerCard(text: "최근 수면 기록에서 \(name) 단계 정보가 제공되지 않았어요. 기기나 HealthKit이 이 단계를 기록하지 않았을 수 있습니다.", evidence: "최근 7일 · \(summary.source)")
            }
            let minutes = rem ? night.remMinutes : core ? night.coreMinutes : night.deepMinutes
            return AnswerCard(text: "최근 기록에서 \(name)은 \(duration(minutes))입니다. 단계는 기록 기기와 HealthKit 제공 자료에 따라 다를 수 있어요.", evidence: "\(dateLabel(night.date)) · \(summary.source)")
        }
        let averageWords = ["평균", "수면시간", "얼마나잤", "몇시간", "총수면", "잠을얼마", "얼마나잠", "잠잔시간", "자는시간", "수면량", "잘잤", "잠은어땠", "수면은어땠", "average", "howlong", "sleepduration"]
        guard averageWords.contains(where: normalized.contains) else {
            return AnswerCard(text: "수면시간·단계와 운동·카페인·스트레스 비교를 물어볼 수 있어요. 예: ‘운동한 날 수면이 달랐나?’, ‘커피 마신 날 덜 잤어?’, ‘요즘 몇 시간 자?’ 지원하는 항목의 다른 표현도 인식하며, 모든 주제의 자유 대화는 제공하지 않습니다.", evidence: "지원 질문 범위")
        }
        return AnswerCard(text: "최근 \(summary.nights.count)개 수면 기록의 평균은 \(duration(summary.averageMinutes))입니다. 가장 최근 기록은 \(summary.nights[0].durationLabel)입니다.", evidence: summary.nights.map { dateLabel($0.date) }.joined(separator: ", ") + " · " + summary.source)
    }

    private static func lifestyleComparison(habit: Habit, summary: ReportSummary, calendar: Calendar) -> AnswerCard {
        guard !summary.nights.contains(where: \.isSample) else {
            return AnswerCard(text: "샘플 수면 기록으로 개인 체크인과의 차이를 계산하지 않아요. 운동·카페인·스트레스를 기록하고 Apple 건강에서 실제 수면을 연결한 뒤 비교해 주세요.", evidence: "수면 출처 \(summary.source) · 샘플 수면과 개인 생활습관의 비교 제외 · " + comparisonPolicy)
        }
        let grouped = Dictionary(grouping: summary.checkIns) { calendar.startOfDay(for: $0.date) }
        var unknown = 0
        let values: [(date: Date, observed: Bool, minutes: Int, source: String)] = grouped.compactMap { day, records in
            guard let record = records.sorted(by: { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }).first,
                  let night = summary.nights.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) else { return nil }
            guard let observed = habit.observed(record) else { unknown += 1; return nil }
            return (day, observed, night.totalMinutes, record.source)
        }.sorted { $0.date < $1.date }
        let yes = values.filter { $0.observed }, no = values.filter { !$0.observed }
        let dates = values.map { dateLabel($0.date) }.joined(separator: ", ")
        var evidence = "비교 날짜 \(dates.isEmpty ? "없음" : dates) · 조건 있음 \(yes.count)일 / 없음 \(no.count)일 · 미기록 제외 \(unknown)일 · 수면 출처 \(summary.source) · 체크인 출처 \(Set(values.map(\.source)).sorted().joined(separator: ", "))"
        if case .exercise = habit { evidence += " · 운동은 있음/없음 기록이며 종류·강도별 비교는 아닙니다." }
        evidence += "\n있음 날짜: \(yes.map { dateLabel($0.date) }.joined(separator: ", ")) / 없음 날짜: \(no.map { dateLabel($0.date) }.joined(separator: ", "))\n" + comparisonPolicy
        guard yes.count >= 2, no.count >= 2 else {
            return AnswerCard(text: "\(habit.label) 여부를 비교하려면 양쪽 조건의 같은 기상일 수면·체크인이 각각 최소 2일 필요합니다. 현재 있음 \(yes.count)일, 없음 \(no.count)일입니다. 미기록은 ‘없음’에 넣지 않아요. 체크인의 운동 항목도 확인해 주세요.", evidence: evidence)
        }
        let a = Double(yes.reduce(0) { $0 + $1.minutes }) / Double(yes.count)
        let b = Double(no.reduce(0) { $0 + $1.minutes }) / Double(no.count)
        let difference = Int(abs(a - b).rounded())
        let result: String
        if a == b { result = "\(habit.label) 조건별 평균 수면시간의 차이가 없었습니다." }
        else if difference == 0 { result = "\(habit.label) 조건별 평균 차이는 표시 단위인 1분 미만입니다." }
        else { result = "\(habit.label)이 있었던 날의 수면이 없었던 날보다 평균 \(duration(difference)) \(a < b ? "짧았습니다" : "길었습니다")." }
        return AnswerCard(text: "있음 \(yes.count)일 평균 \(duration(Int(a.rounded()))), 없음 \(no.count)일 평균 \(duration(Int(b.rounded())))입니다.\n" + result + " 관찰된 평균 차이이며, 의미 있는 변화나 통계적 유의성·인과관계를 판정한 결과가 아닙니다.", evidence: evidence)
    }

    private static func duration(_ minutes: Int) -> String { "\(minutes / 60)시간 \(minutes % 60)분" }
    private static func dateLabel(_ date: Date) -> String { date.formatted(.dateTime.month().day()) }
}
