import Foundation

struct ReportContent: Equatable, Sendable {
    let nights: [SleepNight]
    let checkIns: [CheckIn]
    let source: String
    let periodStart: Date
}

/// Shared seven-calendar-day input for analysis, the summary screen and PDF.
struct ReportSummary: Sendable {
    let nights: [SleepNight]
    let checkIns: [CheckIn]
    let source: String
    let periodStart: Date
    let generatedAt: Date

    init(nights: [SleepNight], checkIns: [CheckIn], source: String, now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        self.nights = nights.filter { $0.date >= start && $0.date <= today }.sorted { $0.date > $1.date }
        self.checkIns = checkIns.filter { $0.date >= start && $0.date <= now }.sorted { $0.date > $1.date }
        self.source = source
        periodStart = start
        generatedAt = now
    }

    var averageMinutes: Int {
        nights.isEmpty ? 0 : nights.reduce(0) { $0 + $1.totalMinutes } / nights.count
    }

    var content: ReportContent {
        ReportContent(nights: nights, checkIns: checkIns, source: source, periodStart: periodStart)
    }
}

// Export projections contain only fields explicitly selected by the user.
enum CheckInExportField: String, CaseIterable, Hashable, Sendable {
    case mood, stress, caffeine, exercise
    var label: String {
        switch self { case .mood: return "기분"; case .stress: return "스트레스"; case .caffeine: return "오후 카페인"; case .exercise: return "전날 운동" }
    }
}

struct ReportExportOptions: Equatable, Sendable {
    var dates: Set<Date>
    var includeSleepTotals = true
    var includeSleepStages = false
    var checkInFields = Set<CheckInExportField>()
    init(summary: ReportSummary, calendar: Calendar = .current) {
        dates = Set((summary.nights.map(\.date) + summary.checkIns.map(\.date)).map { calendar.startOfDay(for: $0) })
    }
    var hasFields: Bool { includeSleepTotals || includeSleepStages || !checkInFields.isEmpty }
    var labels: [String] {
        (includeSleepTotals ? ["총 수면·평균"] : []) +
        (includeSleepStages ? ["수면 단계"] : []) + CheckInExportField.allCases.filter { checkInFields.contains($0) }.map(\.label)
    }
}

struct ExportSleepRow: Equatable, Sendable {
    let date: Date
    let totalMinutes: Int?
    let stages: String?
}
struct ExportCheckInRow: Equatable, Sendable {
    let date: Date
    let fields: [String]
}
struct ExportReport: Equatable, Sendable {
    let generatedAt: Date
    let source: String
    let selectedLabels: [String]
    let sleepRows: [ExportSleepRow]
    let checkInRows: [ExportCheckInRow]
    let averageMinutes: Int?
    let includesCheckIns: Bool
}

enum ReportExportError: LocalizedError {
    case noData, consentRequired, outdated
    var errorDescription: String? {
        switch self {
        case .noData: return "날짜와 포함할 항목을 선택해 주세요. 선택한 범위에 내보낼 기록이 필요합니다."
        case .consentRequired: return "선택한 PDF의 내용을 확인하고 공유 동의를 체크해 주세요."
        case .outdated: return "기록 또는 선택 항목이 바뀌었습니다. 새 PDF를 만들고 다시 확인해 주세요."
        }
    }
}

extension ReportSummary {
    func export(options: ReportExportOptions, calendar: Calendar = .current) throws -> ExportReport {
        guard options.hasFields, !options.dates.isEmpty else { throw ReportExportError.noData }
        let dates = Set(options.dates.map { calendar.startOfDay(for: $0) })
        let selectedNights = nights.filter { dates.contains(calendar.startOfDay(for: $0.date)) }
        let sleepRows: [ExportSleepRow] = options.includeSleepTotals || options.includeSleepStages ? selectedNights.map { night in
            var stages: [String] = []
            if options.includeSleepStages {
                if night.hasDeepStageData { stages.append("깊은 잠 \(night.deepMinutes)분") }
                if night.hasRemStageData { stages.append("렘수면 \(night.remMinutes)분") }
                if night.hasCoreStageData { stages.append("코어 수면 \(night.coreMinutes)분") }
                if night.unclassifiedMinutes > 0 { stages.append("미분류 \(night.unclassifiedMinutes)분") }
                if stages.isEmpty { stages.append("단계 미제공") }
            }
            return ExportSleepRow(date: night.date, totalMinutes: options.includeSleepTotals ? night.totalMinutes : nil,
                                  stages: options.includeSleepStages ? stages.joined(separator: " · ") : nil)
        } : []
        let checkRows: [ExportCheckInRow] = options.checkInFields.isEmpty ? [] : checkIns.filter { dates.contains(calendar.startOfDay(for: $0.date)) }.map { record in
            let fields = CheckInExportField.allCases.filter { options.checkInFields.contains($0) }.map { field -> String in
                switch field {
                case .mood: return "기분: \(record.mood)"
                case .stress: return "스트레스: \(record.stress)"
                case .caffeine: return "오후 카페인: \(record.caffeine ? "있음" : "없음")"
                case .exercise: return "전날 \(record.exerciseLabel)"
                }
            }
            return ExportCheckInRow(date: calendar.startOfDay(for: record.date), fields: fields)
        }
        guard !sleepRows.isEmpty || !checkRows.isEmpty else { throw ReportExportError.noData }
        let average = options.includeSleepTotals && !selectedNights.isEmpty ? selectedNights.reduce(0) { $0 + $1.totalMinutes } / selectedNights.count : nil
        return ExportReport(generatedAt: generatedAt, source: sleepRows.isEmpty ? "사용자 체크인" : source,
            selectedLabels: options.labels, sleepRows: sleepRows, checkInRows: checkRows,
            averageMinutes: average, includesCheckIns: !options.checkInFields.isEmpty)
    }
}
