import Foundation

struct SleepNight: Identifiable {
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

    var hasDetailedStages: Bool {
        hasDeepStageData || hasRemStageData || hasCoreStageData
    }

    var targetProgress: Int {
        min(100, Int(Double(totalMinutes) / 480.0 * 100.0))
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
