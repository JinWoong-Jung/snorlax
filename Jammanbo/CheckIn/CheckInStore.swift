import Foundation
import WatchConnectivity

@MainActor
final class CheckInStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var records: [CheckIn] = []
    @Published private(set) var connectionLabel = "Apple Watch 연결 대기"

    private let storageKey = "jammanbo.checkins.v1"

    override init() {
        super.init()
        loadRecords()
        activateConnectivity()
    }

    func saveFromPhone(mood: String, stress: String, caffeine: Bool) {
        let record = CheckIn(mood: mood, stress: stress, caffeine: caffeine, source: "iPhone")
        insert(record)
    }

    private func activateConnectivity() {
        guard WCSession.isSupported() else {
            connectionLabel = "Apple Watch 연결을 사용할 수 없음"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([CheckIn].self, from: data) else { return }
        records = saved
    }

    private func insert(_ record: CheckIn) {
        records.insert(record, at: 0)
        records = Array(records.prefix(30))
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func importWatchRecord(_ payload: [String: Any]) {
        guard let mood = payload["mood"] as? String,
              let stress = payload["stress"] as? String,
              let caffeine = payload["caffeine"] as? Bool else { return }
        let timestamp = payload["timestamp"] as? Double ?? Date.now.timeIntervalSince1970
        insert(CheckIn(date: Date(timeIntervalSince1970: timestamp), mood: mood, stress: stress, caffeine: caffeine, source: "Apple Watch"))
        connectionLabel = "Apple Watch 체크인 동기화됨"
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let connected = error == nil && activationState == .activated
        Task { @MainActor [weak self] in
            self?.connectionLabel = connected ? "Apple Watch 연결됨" : "Apple Watch 연결 대기"
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let mood = userInfo["mood"] as? String,
              let stress = userInfo["stress"] as? String,
              let caffeine = userInfo["caffeine"] as? Bool else { return }
        let timestamp = userInfo["timestamp"] as? Double ?? Date.now.timeIntervalSince1970
        let record = CheckIn(date: Date(timeIntervalSince1970: timestamp), mood: mood, stress: stress, caffeine: caffeine, source: "Apple Watch")
        Task { @MainActor [weak self] in
            self?.insert(record)
            self?.connectionLabel = "Apple Watch 체크인 동기화됨"
        }
    }
}
