import Foundation
import HealthKit

@MainActor
final class SleepStore: ObservableObject {
    @Published private(set) var nights = SleepNight.sampleNights()
    @Published private(set) var isLoading = false
    @Published private(set) var sourceLabel = "샘플 기록"
    @Published private(set) var message: String?

    private let healthStore = HKHealthStore()

    func requestAccessAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            message = "이 기기에서는 HealthKit 수면 기록을 사용할 수 없습니다. 샘플 기록을 보여드립니다."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            await refresh()
        } catch {
            message = "건강 데이터 권한을 확인하지 못했습니다. 샘플 기록을 계속 사용할 수 있습니다."
        }
    }

    func refresh() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        isLoading = true
        defer { isLoading = false }

        let start = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [descriptor]
            ) { [weak self] _, samples, error in
                Task { @MainActor in
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    if error == nil, let samples = samples as? [HKCategorySample] {
                        let fetchedNights = Self.makeNights(from: samples)
                        if fetchedNights.isEmpty {
                            self.nights = SleepNight.sampleNights()
                            self.sourceLabel = "샘플 기록 · 건강 앱에 수면 데이터가 없음"
                        } else {
                            self.nights = fetchedNights
                            self.sourceLabel = "Apple 건강 기록"
                        }
                        self.message = nil
                    } else {
                        self.message = "수면 기록을 불러오지 못했습니다. 샘플 기록을 보여드립니다."
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }

    private static func makeNights(from samples: [HKCategorySample]) -> [SleepNight] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.endDate) }

        return grouped.compactMap { day, daySamples in
            var deep = 0
            var rem = 0
            var core = 0
            for sample in daySamples {
                let minutes = max(0, Int(sample.endDate.timeIntervalSince(sample.startDate) / 60))
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deep += minutes
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    rem += minutes
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    core += minutes
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    core += minutes
                default:
                    break
                }
            }
            let total = deep + rem + core
            guard total > 0 else { return nil }
            return SleepNight(
                id: day,
                date: day,
                totalMinutes: total,
                deepMinutes: deep,
                remMinutes: rem,
                coreMinutes: core,
                isSample: false
            )
        }
        .sorted { $0.date > $1.date }
    }
}
