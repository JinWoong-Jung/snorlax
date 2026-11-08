import Foundation

struct CheckIn: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let mood: String
    let stress: String
    let caffeine: Bool
    let exercise: Bool?
    let source: String

    init(id: UUID = UUID(), date: Date = .now, mood: String, stress: String, caffeine: Bool, source: String, exercise: Bool? = nil) {
        self.id = id
        self.date = date
        self.mood = mood
        self.stress = stress
        self.caffeine = caffeine
        self.exercise = exercise
        self.source = source
    }
    var exerciseLabel: String { exercise.map { $0 ? "운동 있음" : "운동 없음" } ?? "운동 미기록" }
}
