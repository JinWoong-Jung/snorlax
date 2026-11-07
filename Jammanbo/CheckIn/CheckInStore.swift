import Foundation
import WatchConnectivity

@MainActor
final class CheckInStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var records: [CheckIn] = []
    @Published private(set) var connectionLabel = "Apple Watch 연결 대기"
    private let repository: CheckInRepository
    private var pendingReceipts = Set<UUID>()

    override convenience init() { self.init(repository: CheckInRepository()) }

    init(repository: CheckInRepository) {
        self.repository = repository
        super.init()
        records = repository.records
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        } else {
            connectionLabel = "Apple Watch 연결을 사용할 수 없음"
        }
    }

    func saveFromPhone(mood: String, stress: String, caffeine: Bool) {
        repository.insert(CheckIn(mood: mood, stress: stress, caffeine: caffeine, source: "iPhone"))
        records = repository.records
    }

    func update(id: UUID, mood: String, stress: String, caffeine: Bool) {
        repository.update(id: id, mood: mood, stress: stress, caffeine: caffeine)
        records = repository.records
    }

    func remove(id: UUID) {
        repository.remove(id: id)
        records = repository.records
    }

    private func importWatchRecord(_ payload: [String: Any]) {
        // Old Watch builds provided fields without an ID. Import once per delivered payload.
        var payload = payload
        if payload["id"] == nil { payload["id"] = UUID().uuidString }
        guard let item = CheckInMessage(payload: payload) else { return }
        repository.insert(CheckIn(id: item.id, date: Date(timeIntervalSince1970: item.timestamp), mood: item.mood, stress: item.stress, caffeine: item.caffeine, source: "Apple Watch"))
        records = repository.records
        pendingReceipts.insert(item.id)
        flushReceipts()
        connectionLabel = "Apple Watch 체크인 저장 확인됨"
    }

    private func flushReceipts() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let active = Set(session.outstandingUserInfoTransfers.compactMap { CheckInMessage.receiptID(in: $0.userInfo) })
        for id in pendingReceipts where !active.contains(id) { session.transferUserInfo(CheckInMessage.receipt(for: id)) }
    }

    private func updateConnectionLabel(for session: WCSession, activationState: WCSessionActivationState) {
        guard activationState == .activated else { connectionLabel = "Apple Watch 연결 대기"; return }
        guard session.isPaired else { connectionLabel = "페어링된 Apple Watch 없음"; return }
        guard session.isWatchAppInstalled else { connectionLabel = "Apple Watch 앱 설치 필요"; return }
        connectionLabel = "Apple Watch 준비됨"
        flushReceipts()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in
            if error != nil { self?.connectionLabel = "Apple Watch 연결 대기" }
            else { self?.updateConnectionLabel(for: session, activationState: activationState) }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.updateConnectionLabel(for: session, activationState: session.activationState) }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor [weak self] in self?.importWatchRecord(userInfo) }
    }
    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let id = CheckInMessage.receiptID(in: userInfoTransfer.userInfo)
        let failed = error != nil
        Task { @MainActor [weak self] in
            guard let self, let id else { return }
            if !failed { self.pendingReceipts.remove(id) }
            // A lost receipt is requested again by the Watch's persistent outbox retry.
        }
    }
}
