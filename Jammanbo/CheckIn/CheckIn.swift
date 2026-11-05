import Foundation

struct CheckIn: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let mood: String
    let stress: String
    let caffeine: Bool
    let source: String

    init(id: UUID = UUID(), date: Date = .now, mood: String, stress: String, caffeine: Bool, source: String) {
        self.id = id
        self.date = date
        self.mood = mood
        self.stress = stress
        self.caffeine = caffeine
        self.source = source
    }
}
