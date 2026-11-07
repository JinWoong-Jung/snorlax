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
