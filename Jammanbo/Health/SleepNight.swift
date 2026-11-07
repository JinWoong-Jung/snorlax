import Foundation

struct SleepNight: Identifiable, Equatable, Sendable {
    let id: Date
    let date: Date
    let totalMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let unclassifiedMinutes: Int
    let hasDeepStageData: Bool
    let hasRemStageData: Bool
    let hasCoreStageData: Bool
    let isSample: Bool
    let startDate: Date?
    let endDate: Date?

    init(id: Date, date: Date, totalMinutes: Int, deepMinutes: Int, remMinutes: Int, coreMinutes: Int, unclassifiedMinutes: Int, hasDeepStageData: Bool, hasRemStageData: Bool, hasCoreStageData: Bool, isSample: Bool, startDate: Date? = nil, endDate: Date? = nil) {
        self.id = id
        self.date = date
        self.totalMinutes = totalMinutes
        self.deepMinutes = deepMinutes
        self.remMinutes = remMinutes
        self.coreMinutes = coreMinutes
        self.unclassifiedMinutes = unclassifiedMinutes
        self.hasDeepStageData = hasDeepStageData
        self.hasRemStageData = hasRemStageData
        self.hasCoreStageData = hasCoreStageData
        self.isSample = isSample
        self.startDate = startDate
        self.endDate = endDate
    }

    var hasDetailedStages: Bool {
        hasDeepStageData || hasRemStageData || hasCoreStageData
    }

    func targetProgress(goalMinutes: Int) -> Int {
        guard goalMinutes > 0 else { return 0 }
        return min(100, Int(Double(totalMinutes) / Double(goalMinutes) * 100.0))
    }

    var durationLabel: String {
        "\(totalMinutes / 60)시간 \(totalMinutes % 60)분"
    }

    static func sampleNights(calendar: Calendar = .current, today: Date = .now) -> [SleepNight] {
        let durations = [432, 401, 448, 376, 455, 419, 438]
        return durations.enumerated().map { offset, minutes in
            let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: today) ?? today)
            let deep = Int(Double(minutes) * 0.15)
            let rem = Int(Double(minutes) * 0.23)
            return SleepNight(
                id: date,
                date: date,
                totalMinutes: minutes,
                deepMinutes: deep,
                remMinutes: rem,
                coreMinutes: minutes - deep - rem,
                unclassifiedMinutes: 0,
                hasDeepStageData: true,
                hasRemStageData: true,
                hasCoreStageData: true,
                isSample: true
            )
        }
    }
}
