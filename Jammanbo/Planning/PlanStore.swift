import Foundation
import Combine

struct PlanEvent: Codable, Identifiable {
    let id: UUID
    let title: String
    let time: Date

    init(id: UUID = UUID(), title: String, time: Date) {
        self.id = id
        self.title = title
        self.time = time
    }
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
    }

    func wakeTime(on date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: wakeMinutes / 60, minute: wakeMinutes % 60, second: 0, of: date) ?? date
    }

    func suggestedBedtime(on date: Date = .now, calendar: Calendar = .current) -> Date {
        let wake = wakeTime(on: date, calendar: calendar)
        return calendar.date(byAdding: .minute, value: -sleepGoalMinutes, to: wake) ?? wake
    }

    @discardableResult
    func addEvent(title: String, time: Date) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        events.append(PlanEvent(title: trimmed, time: time))
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
