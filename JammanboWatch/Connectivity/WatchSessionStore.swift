import Foundation
import WatchConnectivity

private struct WatchCheckIn: Codable {
    let id: UUID
    let timestamp: Double
    let mood: String
    let stress: String
    let caffeine: Bool

    var transferPayload: [String: Any] {
        ["id": id.uuidString, "timestamp": timestamp, "mood": mood, "stress": stress, "caffeine": caffeine]
    }
}

private struct LegacyWatchCheckIn: Decodable {
    let timestamp: Double
    let mood: String
    let stress: String
    let caffeine: Bool

    var currentVersion: WatchCheckIn {
        WatchCheckIn(id: UUID(), timestamp: timestamp, mood: mood, stress: stress, caffeine: caffeine)
    }
}

@MainActor
final class WatchSessionStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var status = "체크인을 입력해 주세요"

    private let pendingKey = "jammanbo.watch.pendingCheckIn.v1"

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            status = "iPhone 연결을 사용할 수 없어요"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func submit(mood: String, stress: String, caffeine: Bool) {
        let payload = WatchCheckIn(id: UUID(), timestamp: Date.now.timeIntervalSince1970, mood: mood, stress: stress, caffeine: caffeine)
        var pending = loadPendingCheckIns()
        pending.append(payload)
        pending = Array(pending.suffix(30))
        guard let data = try? JSONEncoder().encode(pending) else {
            status = "체크인을 저장하지 못했어요. 다시 시도해 주세요."
            return
        }
        UserDefaults.standard.set(data, forKey: pendingKey)
        status = "체크인을 저장했어요 · iPhone으로 전송 대기 중"
        flushPendingCheckIn()
    }

    private func loadPendingCheckIns() -> [WatchCheckIn] {
        guard let data = UserDefaults.standard.data(forKey: pendingKey) else { return [] }
        if let pending = try? JSONDecoder().decode([WatchCheckIn].self, from: data) {
            return pending
        }
        if let legacy = try? JSONDecoder().decode(LegacyWatchCheckIn.self, from: data) {
            return [legacy.currentVersion]
        }
        return []
    }

    private func flushPendingCheckIn() {
        guard WCSession.default.activationState == .activated,
              !loadPendingCheckIns().isEmpty else { return }
        let pending = loadPendingCheckIns()
        for payload in pending {
            WCSession.default.transferUserInfo(payload.transferPayload)
        }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        status = "전송을 예약했어요 · iPhone에서 도착을 확인해 주세요"
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let failed = error != nil
        Task { @MainActor [weak self] in
            if failed {
                self?.status = "연결을 확인 중이에요"
            } else {
                self?.flushPendingCheckIn()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {}
}
