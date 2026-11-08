import Foundation
import Combine

struct PlanEvent: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let time: Date
    let endTime: Date

    init(id: UUID = UUID(), title: String, time: Date, endTime: Date? = nil) {
        self.id = id; self.title = title; self.time = time
        self.endTime = endTime ?? time.addingTimeInterval(3600)
    }

    private enum CodingKeys: CodingKey { case id, title, time, endTime }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        time = try values.decode(Date.self, forKey: .time)
        // Older single-time events retain their date and receive an explicit one-hour duration.
        endTime = try values.decodeIfPresent(Date.self, forKey: .endTime) ?? time.addingTimeInterval(3600)
    }
}

struct PlanRecommendation {
    let baseBedtime: Date
    let bedtime: Date
    let wake: Date
    let fullGoalWake: Date
    let conflictingEvents: [PlanEvent]
    let availableMinutes: Int
    let shortfallMinutes: Int
    var isAdjusted: Bool { bedtime > baseBedtime }
}

@MainActor
final class PlanStore: ObservableObject {
    @Published var wakeMinutes: Int { didSet { defaults.set(wakeMinutes, forKey: Self.wakeKey) } }
    @Published var sleepGoalMinutes: Int { didSet { defaults.set(sleepGoalMinutes, forKey: Self.sleepKey) } }
    @Published private(set) var events: [PlanEvent]

    private static let wakeKey = "jammanbo.targetWakeMinutes"
    private static let sleepKey = "jammanbo.targetSleepMinutes"
    private static let eventsKey = "jammanbo.planEvents.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        wakeMinutes = defaults.object(forKey: Self.wakeKey) == nil ? 420 : min(1439, max(0, defaults.integer(forKey: Self.wakeKey)))
        sleepGoalMinutes = defaults.object(forKey: Self.sleepKey) == nil ? 480 : min(600, max(360, defaults.integer(forKey: Self.sleepKey)))
        events = defaults.data(forKey: Self.eventsKey).flatMap { try? JSONDecoder().decode([PlanEvent].self, from: $0) } ?? []
        events = events.filter { $0.time.timeIntervalSince1970.isFinite && $0.endTime.timeIntervalSince1970.isFinite && $0.endTime > $0.time }
    }

    func wakeTime(on date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: wakeMinutes / 60, minute: wakeMinutes % 60, second: 0, of: date) ?? date
    }

    func suggestedBedtime(on date: Date = .now, calendar: Calendar = .current) -> Date {
        let wake = wakeTime(on: date, calendar: calendar)
        return calendar.date(byAdding: .minute, value: -sleepGoalMinutes, to: wake) ?? wake
    }

    /// The date identifies the intended waking day, so late-night events stay on the right night.
    func recommendation(forWakeDate date: Date, calendar: Calendar = .current) -> PlanRecommendation {
        let wake = wakeTime(on: date, calendar: calendar)
        let base = suggestedBedtime(on: date, calendar: calendar)
        let relevant = events.filter { $0.time < wake && $0.endTime.addingTimeInterval(30 * 60) > base }
            .sorted { $0.time < $1.time }
        let bedtime = relevant.reduce(base) { max($0, $1.endTime.addingTimeInterval(30 * 60)) }
        let available = max(0, Int(wake.timeIntervalSince(bedtime) / 60))
        return PlanRecommendation(baseBedtime: base, bedtime: bedtime, wake: wake,
            fullGoalWake: calendar.date(byAdding: .minute, value: sleepGoalMinutes, to: bedtime) ?? bedtime,
            conflictingEvents: relevant, availableMinutes: available,
            shortfallMinutes: max(0, sleepGoalMinutes - available))
    }

    @discardableResult
    func addEvent(title: String, time: Date, endTime: Date? = nil) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = endTime ?? time.addingTimeInterval(3600)
        guard !trimmed.isEmpty, time.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite, end > time else { return false }
        events.append(PlanEvent(title: trimmed, time: time, endTime: end))
        saveEvents()
        return true
    }

    func removeEvent(id: UUID) {
        events.removeAll { $0.id == id }
        saveEvents()
    }

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: Self.eventsKey)
    }
}
