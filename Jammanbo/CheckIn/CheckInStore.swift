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
        guard !records.contains(where: { $0.id == record.id }) else { return }
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
        let id = UUID(uuidString: payload["id"] as? String ?? "") ?? UUID()
        insert(CheckIn(id: id, date: Date(timeIntervalSince1970: timestamp), mood: mood, stress: stress, caffeine: caffeine, source: "Apple Watch"))
        connectionLabel = "Apple Watch 체크인 동기화됨"
    }

    private func updateConnectionLabel(for session: WCSession, activationState: WCSessionActivationState) {
        guard activationState == .activated else {
            connectionLabel = "Apple Watch 연결 대기"
            return
        }
        guard session.isPaired else {
            connectionLabel = "페어링된 Apple Watch 없음"
            return
        }
        guard session.isWatchAppInstalled else {
            connectionLabel = "Apple Watch 앱 설치 필요"
            return
        }
        connectionLabel = "Apple Watch 준비됨"
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if error != nil {
                self.connectionLabel = "Apple Watch 연결 대기"
            } else {
                self.updateConnectionLabel(for: session, activationState: activationState)
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.updateConnectionLabel(for: session, activationState: session.activationState)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor [weak self] in
            self?.importWatchRecord(userInfo)
        }
    }
}
