import Foundation

/// Persistent, date-ordered records and a receipt ledger for idempotent Watch retries.
final class CheckInRepository {
    private let defaults: UserDefaults
    private let key = "jammanbo.checkins.v1"
    private let receiptKey = "jammanbo.checkinReceipts.v1"
    private(set) var records: [CheckIn]
    private var receipts: [UUID]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([CheckIn].self, from: $0) } ?? []
        var seen = Set<UUID>()
        records = Array(saved.filter { $0.date.timeIntervalSince1970.isFinite && seen.insert($0.id).inserted }.sorted(by: Self.newer).prefix(30))
        receipts = (defaults.stringArray(forKey: receiptKey) ?? []).compactMap(UUID.init(uuidString:))
        for record in records where !receipts.contains(record.id) { receipts.append(record.id) }
    }

    @discardableResult
    func insert(_ record: CheckIn) -> Bool {
        guard record.date.timeIntervalSince1970.isFinite, !receipts.contains(record.id) else { return false }
        records = Array((records + [record]).sorted(by: Self.newer).prefix(30))
        receipts.append(record.id)
        receipts = Array(receipts.suffix(1000))
        persist()
        return true
    }

    func update(id: UUID, mood: String, stress: String, caffeine: Bool) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let old = records[index]
        records[index] = CheckIn(id: old.id, date: old.date, mood: mood, stress: stress, caffeine: caffeine, source: old.source)
        persist()
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
        // Keep the receipt so a retry cannot resurrect a locally deleted record.
        persist()
    }

    private static func newer(_ lhs: CheckIn, _ rhs: CheckIn) -> Bool {
        lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date > rhs.date
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
        defaults.set(receipts.map(\.uuidString), forKey: receiptKey)
    }
}
