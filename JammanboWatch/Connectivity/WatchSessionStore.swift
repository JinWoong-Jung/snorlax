import Foundation
import WatchConnectivity

@MainActor
final class WatchSessionStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var status = "체크인을 입력해 주세요"
    @Published private(set) var pendingCount = 0
    @Published private(set) var lastConfirmedAt: Date?

    private let outbox: CheckInOutbox
    private let defaults: UserDefaults
    private var retry = DeliveryRetryState()
    private var retryTask: Task<Void, Never>?

    override convenience init() { self.init(defaults: .standard) }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        outbox = CheckInOutbox(defaults: defaults)
        super.init()
        pendingCount = outbox.pending.count
        let confirmed = defaults.double(forKey: "jammanbo.watch.lastConfirmedAt.v1")
        if confirmed > 0 { lastConfirmedAt = Date(timeIntervalSince1970: confirmed) }
        guard WCSession.isSupported() else { status = "iPhone 연결을 사용할 수 없어요"; return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func submit(mood: String, stress: String, caffeine: Bool, exercise: Bool? = nil) {
        do {
            try outbox.enqueue(CheckInMessage(mood: mood, stress: stress, caffeine: caffeine, exercise: exercise))
            pendingCount = outbox.pending.count
            status = "Watch에 저장했어요 · iPhone 저장 확인 대기"
            flushPendingCheckIns()
        } catch {
            status = "전송 대기 30건이 가득 찼어요. iPhone 연결 후 먼저 동기화해 주세요."
        }
    }

    func retryNow() {
        retryTask?.cancel()
        retry = DeliveryRetryState()
        flushPendingCheckIns()
    }

    func resume() { flushPendingCheckIns() }

    func handleBackgroundDelivery() async {
        flushPendingCheckIns()
        await Task.yield()
        let session = WCSession.default
        while !Task.isCancelled && (session.activationState != .activated || session.hasContentPending) {
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        }
        await Task.yield() // Finish receipt persistence before SwiftUI completes the background task.
    }

    private func flushPendingCheckIns(completedID: UUID? = nil) {
        retryTask?.cancel()
        pendingCount = outbox.pending.count
        guard !outbox.pending.isEmpty else {
            status = lastConfirmedAt == nil ? "체크인을 입력해 주세요" : "iPhone에 저장된 것을 확인했어요"
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else { status = "Watch에 저장됨 · iPhone 연결 대기"; return }
        guard session.isCompanionAppInstalled else { status = "iPhone에 잠만보 앱을 설치해 주세요 · 기록은 Watch에 보관 중"; return }
        var transporting = Set(session.outstandingUserInfoTransfers.compactMap { UUID(uuidString: $0.userInfo["id"] as? String ?? "") })
        if let completedID { transporting.remove(completedID) }
        let now = Date.now
        var scheduled = Set<UUID>()
        for item in outbox.pending where retry.eligible(item.id, transporting: transporting, now: now) {
            session.transferUserInfo(item.payload)
            retry.scheduled(item.id, now: now)
            scheduled.insert(item.id)
        }
        status = "\(pendingCount)건 전송 중 · iPhone 저장 확인 대기"
        scheduleRetry(transporting: transporting.union(scheduled))
    }

    private func scheduleRetry(transporting: Set<UUID>) {
        guard let date = retry.nextRetry(for: outbox.pending.map(\.id), transporting: transporting, now: .now) else { return }
        let delay = max(1, date.timeIntervalSinceNow)
        retryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            self?.flushPendingCheckIns()
        }
    }

    private func receiveReceipt(_ payload: [String: Any]) {
        guard let id = CheckInMessage.receiptID(in: payload), outbox.pending.contains(where: { $0.id == id }) else { return }
        outbox.acknowledge(id: id)
        retry.acknowledged(id)
        lastConfirmedAt = .now
        defaults.set(Date.now.timeIntervalSince1970, forKey: "jammanbo.watch.lastConfirmedAt.v1")
        flushPendingCheckIns()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let failed = error != nil
        Task { @MainActor [weak self] in
            if failed { self?.status = "연결하지 못했어요 · Watch 기록은 보관 중" }
            else { self?.flushPendingCheckIns() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor [weak self] in self?.receiveReceipt(userInfo) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let id = UUID(uuidString: userInfoTransfer.userInfo["id"] as? String ?? "")
        let failed = error != nil
        Task { @MainActor [weak self] in
            guard let self, let id, self.outbox.pending.contains(where: { $0.id == id }) else { return }
            self.retry.finished(id, failed: failed, now: .now)
            self.flushPendingCheckIns(completedID: id)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.flushPendingCheckIns() }
    }

    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.flushPendingCheckIns() }
    }
}
