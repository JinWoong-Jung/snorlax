import Foundation
import WatchConnectivity

private struct WatchCheckIn: Codable {
    let timestamp: Double
    let mood: String
    let stress: String
    let caffeine: Bool

    var transferPayload: [String: Any] {
        ["timestamp": timestamp, "mood": mood, "stress": stress, "caffeine": caffeine]
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
        let payload = WatchCheckIn(timestamp: Date.now.timeIntervalSince1970, mood: mood, stress: stress, caffeine: caffeine)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: pendingKey)
        status = "저장했어요 · iPhone으로 전송 준비 중"
        flushPendingCheckIn()
    }

    private func flushPendingCheckIn() {
        guard WCSession.default.activationState == .activated,
              let data = UserDefaults.standard.data(forKey: pendingKey),
              let payload = try? JSONDecoder().decode(WatchCheckIn.self, from: data) else { return }
        WCSession.default.transferUserInfo(payload.transferPayload)
        UserDefaults.standard.removeObject(forKey: pendingKey)
        status = "체크인을 저장했어요"
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
