import Foundation

struct CheckInMessage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Double
    let mood: String
    let stress: String
    let caffeine: Bool

    init(id: UUID = UUID(), timestamp: Double = Date.now.timeIntervalSince1970, mood: String, stress: String, caffeine: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.mood = mood
        self.stress = stress
        self.caffeine = caffeine
    }

    private enum CodingKeys: CodingKey { case id, timestamp, mood, stress, caffeine }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try values.decode(Double.self, forKey: .timestamp)
        mood = try values.decode(String.self, forKey: .mood)
        stress = try values.decode(String.self, forKey: .stress)
        caffeine = try values.decode(Bool.self, forKey: .caffeine)
    }

    init?(payload: [String: Any]) {
        guard payload["kind"] as? String != "checkInReceipt",
              let id = UUID(uuidString: payload["id"] as? String ?? ""),
              let timestamp = payload["timestamp"] as? Double, timestamp.isFinite, timestamp > 0,
              let mood = payload["mood"] as? String, !mood.isEmpty, mood.count <= 80,
              let stress = payload["stress"] as? String, !stress.isEmpty, stress.count <= 80,
              let caffeine = payload["caffeine"] as? Bool else { return nil }
        self.init(id: id, timestamp: timestamp, mood: mood, stress: stress, caffeine: caffeine)
    }

    var payload: [String: Any] {
        ["kind": "checkIn", "id": id.uuidString, "timestamp": timestamp, "mood": mood, "stress": stress, "caffeine": caffeine]
    }

    static func receipt(for id: UUID) -> [String: Any] { ["kind": "checkInReceipt", "id": id.uuidString] }

    static func receiptID(in payload: [String: Any]) -> UUID? {
        guard payload["kind"] as? String == "checkInReceipt" else { return nil }
        return UUID(uuidString: payload["id"] as? String ?? "")
    }
}

final class CheckInOutbox {
    enum QueueError: Error { case full }
    private let defaults: UserDefaults
    private let key = "jammanbo.watch.pendingCheckIn.v1"
    private(set) var pending: [CheckInMessage]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let data = defaults.data(forKey: key)
        let decoder = JSONDecoder()
        if let data, let values = try? decoder.decode([CheckInMessage].self, from: data) {
            pending = values
        } else if let data, let old = try? decoder.decode(CheckInMessage.self, from: data) {
            pending = [old]
        } else {
            pending = []
        }
        var seen = Set<UUID>()
        pending = pending.filter { $0.timestamp.isFinite && seen.insert($0.id).inserted }
        persist() // Persist migrated legacy UUIDs before the first transfer.
    }

    func enqueue(_ message: CheckInMessage) throws {
        guard !pending.contains(where: { $0.id == message.id }) else { return }
        guard pending.count < 30 else { throw QueueError.full }
        pending.append(message)
        persist()
    }

    func acknowledge(id: UUID) {
        pending.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(pending) { defaults.set(data, forKey: key) }
    }
}

struct DeliveryRetryState {
    private var attempts: [UUID: Int] = [:]
    private var due: [UUID: Date] = [:]

    mutating func scheduled(_ id: UUID, now: Date) { due[id] = now.addingTimeInterval(60) }

    mutating func finished(_ id: UUID, failed: Bool, now: Date) {
        if failed {
            attempts[id, default: 0] += 1
            due[id] = now.addingTimeInterval(min(300, 5 * pow(2, Double(min(attempts[id, default: 1] - 1, 6)))))
        } else {
            due[id] = now.addingTimeInterval(60) // Transport success still waits for the app receipt.
        }
    }

    mutating func acknowledged(_ id: UUID) { attempts[id] = nil; due[id] = nil }

    func eligible(_ id: UUID, transporting: Set<UUID>, now: Date) -> Bool {
        !transporting.contains(id) && (due[id] ?? .distantPast) <= now
    }

    func nextRetry(for pending: [UUID], transporting: Set<UUID>, now: Date) -> Date? {
        pending.filter { !transporting.contains($0) }.map { max(now, due[$0] ?? now) }.min()
    }
}
