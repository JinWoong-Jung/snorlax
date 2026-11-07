import Foundation
import HealthKit

@MainActor
final class SleepStore: ObservableObject {
    @Published private(set) var nights = SleepNight.sampleNights()
    @Published private(set) var isLoading = false
    @Published private(set) var sourceLabel = "샘플 기록"
    @Published private(set) var message: String?

    private let healthStore = HKHealthStore()
    private let defaults: UserDefaults
    private let connectionKey = "jammanbo.health.connectionRequested.v1"
    private var observer: HKObserverQuery?
    private var refreshTask: Task<Void, Never>?
    private var refreshAgain = false
    private var authorizing = false

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func requestAccessAndRefresh() async {
        guard !isLoading, !authorizing else { return }
        guard HKHealthStore.isHealthDataAvailable(), let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            showSample(message: "이 기기에서는 HealthKit 수면 기록을 사용할 수 없습니다. 샘플 기록을 보여드립니다.")
            return
        }
        isLoading = true
        authorizing = true
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            defaults.set(true, forKey: connectionKey)
            authorizing = false
            isLoading = false
            await refreshIfConnected()
        } catch {
            authorizing = false
            isLoading = false
            showSample(message: "건강 데이터 권한을 확인하지 못했습니다. 다시 연결해 주세요.")
        }
    }

    /// Re-query on launch/foreground after the user has chosen to connect; never prompts here.
    func refreshIfConnected() async {
        guard !authorizing else { return }
        guard defaults.bool(forKey: connectionKey), HKHealthStore.isHealthDataAvailable() else {
            if nights.allSatisfy(\.isSample) { nights = SleepNight.sampleNights() }
            return
        }
        startObserving()
        await refresh()
    }

    func refresh() async {
        if let task = refreshTask {
            refreshAgain = true
            await task.value
            return
        }
        isLoading = true
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                self.refreshAgain = false
                await self.loadRecords()
            } while self.refreshAgain
        }
        refreshTask = task
        await task.value
        refreshTask = nil
        isLoading = false
    }

    private func startObserving() {
        guard observer == nil, let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            Task { @MainActor [weak self] in
                defer { completion() }
                guard error == nil, let self else { return }
                await self.refreshIfConnected()
            }
        }
        observer = query
        healthStore.execute(query)
    }

    private func loadRecords() async {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let now = Date.now
        let start = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        do {
            let samples = try await querySamples(type: type, predicate: predicate, descriptor: descriptor)
            let intervals = samples.compactMap { Self.interval($0) }
            let normalized = SleepNormalizer.nights(from: intervals, now: now)
            let recent = ReportSummary(nights: normalized, checkIns: [], source: "Apple 건강 기록", now: now).nights
            if recent.isEmpty {
                showSample(message: "최근 7일에 읽을 수 있는 수면 기록이 없습니다. 건강 앱의 기록과 접근 권한을 확인해 주세요.")
            } else {
                nights = recent
                sourceLabel = "Apple 건강 기록"
                message = nil
            }
        } catch {
            showSample(message: "수면 기록을 불러오지 못했습니다. 샘플 기록을 보여드립니다. 아래로 당겨 다시 확인해 주세요.")
        }
    }

    private func querySamples(type: HKSampleType, predicate: NSPredicate, descriptor: NSSortDescriptor) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [descriptor]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples as? [HKCategorySample] ?? []) }
            }
            healthStore.execute(query)
        }
    }

    private static func interval(_ sample: HKCategorySample) -> SleepInterval? {
        let stage: SleepInterval.Stage
        switch sample.value {
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: stage = .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue: stage = .rem
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue: stage = .core
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: stage = .unclassified
        case HKCategoryValueSleepAnalysis.awake.rawValue: stage = .awake
        case HKCategoryValueSleepAnalysis.inBed.rawValue: stage = .inBed
        default: return nil
        }
        let product = sample.sourceRevision.productType ?? sample.device?.model ?? ""
        return SleepInterval(id: sample.uuid.uuidString, start: sample.startDate, end: sample.endDate, stage: stage,
                             source: sample.sourceRevision.source.bundleIdentifier, isWatch: product.lowercased().contains("watch"))
    }

    private func showSample(message: String) {
        nights = SleepNight.sampleNights()
        sourceLabel = "샘플 기록"
        self.message = message
    }
}
