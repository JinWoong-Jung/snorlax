import Foundation

@main
struct DomainChecks {
    @MainActor
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        func night(_ offset: Int, minutes: Int = 420, sample: Bool = false, stages: Bool = true) -> SleepNight {
            SleepNight(id: day(offset), date: day(offset), totalMinutes: minutes, deepMinutes: stages ? 60 : 0, remMinutes: 0, coreMinutes: 0, unclassifiedMinutes: minutes - (stages ? 60 : 0), hasDeepStageData: stages, hasRemStageData: false, hasCoreStageData: false, isSample: sample)
        }
        func checkIn(_ offset: Int, caffeine: Bool, seconds: Int = 1) -> CheckIn {
            CheckIn(date: day(offset).addingTimeInterval(Double(seconds)), mood: "괜찮음", stress: "보통", caffeine: caffeine, source: "iPhone")
        }
        func summary(_ nights: [SleepNight], _ checkIns: [CheckIn] = []) -> ReportSummary {
            ReportSummary(nights: nights, checkIns: checkIns, source: "검증 기록", now: now, calendar: calendar)
        }
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let window = summary([night(-7), night(-6, minutes: 360), night(0, minutes: 480), night(1)], [checkIn(-7, caffeine: true), checkIn(-6, caffeine: true), checkIn(0, caffeine: false), checkIn(1, caffeine: true)])
        expect(window.nights.map(\.date) == [day(0), day(-6)], "Seven calendar days must exclude older and future nights")
        expect(window.checkIns.count == 2, "Reports must filter check-ins to the same date range")
        expect(window.averageMinutes == 420, "Missing dates must not count as zero-duration nights")
        expect(AnalysisService.answer(question: " ", summary: window).evidence == "질문 입력 안내", "Empty question")
        expect(AnalysisService.answer(question: "최근 평균 수면은?", summary: summary([])).text.contains("기록이 없습니다"), "No records")
        expect(AnalysisService.answer(question: "내일 날씨는?", summary: window).evidence == "지원 질문 범위", "Unsupported question")
        expect(AnalysisService.answer(question: "렘수면은?", summary: window).text.contains("제공되지"), "Missing stage must not be reported as zero")
        expect(AnalysisService.answer(question: "카페인 비교", summary: summary([night(0, sample: true)], [checkIn(0, caffeine: true)])).text.contains("샘플 수면"), "Sample sleep cannot explain personal habits")
        let nights = [night(0, minutes: 360), night(-1, minutes: 360), night(-2, minutes: 480), night(-3, minutes: 480)]
        let habits = [checkIn(0, caffeine: false), checkIn(0, caffeine: true, seconds: 2), checkIn(-1, caffeine: true), checkIn(-2, caffeine: false), checkIn(-3, caffeine: false)]
        let comparison = AnalysisService.answer(question: "카페인 비교", summary: summary(nights, habits), calendar: calendar)
        expect(comparison.text.contains("2시간 0분 짧았습니다"), "Use the latest check-in each date, not all check-ins")
        expect(comparison.evidence.contains("있음 2일 / 없음 2일"), "Comparison evidence must include group counts")
        let insufficient = AnalysisService.answer(question: "카페인 비교", summary: summary(nights, Array(habits.prefix(3))), calendar: calendar)
        expect(insufficient.text.contains("각각 최소 2일"), "Require two dates in each group")
        let equal = AnalysisService.answer(question: "카페인 비교", summary: summary((0...3).map { night(-$0) }, habits), calendar: calendar)
        expect(equal.text.contains("차이가 없었습니다"), "Equal means should not imply longer sleep")
        expect(night(0, minutes: 360).targetProgress(goalMinutes: 360) == 100, "Dashboard progress must use the selected sleep goal")
        let suite = "jammanbo.domain-checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let plan = PlanStore(defaults: defaults)
        expect(plan.wakeMinutes == 420 && plan.sleepGoalMinutes == 480, "Default plan")
        let bedtime = plan.suggestedBedtime(on: now, calendar: calendar)
        expect(calendar.component(.hour, from: bedtime) == 23 && calendar.isDate(bedtime, inSameDayAs: day(-1)), "07:00 minus eight hours is 23:00 on previous day")
        expect(!plan.addEvent(title: "   ", time: now), "Reject empty title")
        expect(plan.addEvent(title: "  운동  ", time: now) && plan.events.first?.title == "운동", "Trim saved event")
        plan.wakeMinutes = 450
        plan.sleepGoalMinutes = 465
        let restored = PlanStore(defaults: defaults)
        expect(restored.events.count == 1 && restored.wakeMinutes == 450 && restored.sleepGoalMinutes == 465, "Restore existing storage keys")
        restored.removeEvent(id: restored.events[0].id)
        expect(PlanStore(defaults: defaults).events.isEmpty, "Persist deletion")
        // Regression: one overnight session must stay on its final waking day.
        func interval(_ start: Date, _ end: Date, _ stage: SleepInterval.Stage = .core, source: String = "watch", watch: Bool = true) -> SleepInterval {
            SleepInterval(start: start, end: end, stage: stage, source: source, isWatch: watch)
        }
        let sleepStart = day(-1).addingTimeInterval(22.5 * 3600)
        let split = day(-1).addingTimeInterval(23.5 * 3600)
        let sleepEnd = today.addingTimeInterval(6.5 * 3600)
        let overnight = SleepNormalizer.nights(from: [interval(sleepStart, split), interval(split, sleepEnd)], now: now, calendar: calendar)
        expect(overnight.count == 1 && overnight[0].date == today && overnight[0].totalMinutes == 480, "Overnight stages must share the waking date")
        expect(overnight[0].startDate == sleepStart && overnight[0].endDate == sleepEnd, "Sleep detail preserves real start and end")
        let eightHours = interval(today, today.addingTimeInterval(8 * 3600))
        let duplicated = SleepNormalizer.nights(from: [eightHours, eightHours, interval(today, today.addingTimeInterval(8 * 3600), .unclassified, source: "phone", watch: false)], now: now, calendar: calendar)
        expect(duplicated[0].totalMinutes == 480 && duplicated[0].coreMinutes == 480 && duplicated[0].unclassifiedMinutes == 0, "Duplicate and unspecified overlap must count only once")
        let detail = SleepNormalizer.nights(from: [interval(today, today.addingTimeInterval(8 * 3600), .unclassified), interval(today, today.addingTimeInterval(8 * 3600), .rem, source: "detail", watch: false)], now: now, calendar: calendar)
        expect(detail[0].remMinutes == 480 && detail[0].unclassifiedMinutes == 0, "Detailed data wins over unspecified data")
        let sourcePriority = SleepNormalizer.nights(from: [eightHours, interval(today, today.addingTimeInterval(8 * 3600), .deep, source: "third-party", watch: false)], now: now, calendar: calendar)
        expect(sourcePriority[0].coreMinutes == 480, "Watch wins a conflicting detailed-source overlap")
        let awake = interval(today.addingTimeInterval(3 * 3600), today.addingTimeInterval(3.5 * 3600), .awake)
        let interrupted = SleepNormalizer.nights(from: [eightHours, awake], now: now, calendar: calendar)
        expect(interrupted.count == 1 && interrupted[0].totalMinutes == 450, "Awake time must not count as sleep")
        let seconds = SleepNormalizer.nights(from: [interval(today, today.addingTimeInterval(30), .deep), interval(today.addingTimeInterval(30), today.addingTimeInterval(60), .rem)], now: now, calendar: calendar)
        expect(seconds.count == 1 && seconds[0].totalMinutes == 1, "Accumulate sub-minute samples before rounding")
        expect(seconds[0].deepMinutes + seconds[0].remMinutes + seconds[0].coreMinutes + seconds[0].unclassifiedMinutes == seconds[0].totalMinutes, "Rounded stage totals must equal the displayed total")
        expect(seconds[0].hasDeepStageData && seconds[0].hasRemStageData, "A rounded zero stage is still provided data")
        let nap = interval(today.addingTimeInterval(10 * 3600), today.addingTimeInterval(11 * 3600))
        let withNap = SleepNormalizer.nights(from: [eightHours, nap], now: now, calendar: calendar)
        expect(withNap.count == 1 && withNap[0].totalMinutes == 540, "Separate sleep sessions on one waking day are added once")
        let bedStart = day(-1).addingTimeInterval(21 * 3600)
        let bedEnd = today.addingTimeInterval(6 * 3600)
        let longAwakening = SleepNormalizer.nights(from: [interval(bedStart, day(-1).addingTimeInterval(23 * 3600)), interval(today.addingTimeInterval(2 * 3600), bedEnd), interval(bedStart, bedEnd, .inBed)], now: now, calendar: calendar)
        expect(longAwakening.count == 1 && longAwakening[0].date == today && longAwakening[0].totalMinutes == 360, "Shared in-bed window keeps one overnight session across a long awakening without counting awake time")
        expect(SleepNormalizer.nights(from: [interval(bedStart, bedEnd, .inBed)], now: now, calendar: calendar).isEmpty, "Time in bed alone is not sleep")
        let prior = interval(day(-1).addingTimeInterval(12 * 3600), day(-1).addingTimeInterval(13 * 3600))
        let separateDays = SleepNormalizer.nights(from: [prior, eightHours], now: now, calendar: calendar)
        expect(separateDays.count == 2, "Long gaps must not join unrelated sleep days")
        let future = SleepNormalizer.nights(from: [interval(now.addingTimeInterval(-60), now.addingTimeInterval(60))], now: now, calendar: calendar)
        expect(future[0].totalMinutes == 1, "Never count the future part of a sample")
        expect(SleepNormalizer.nights(from: [interval(now, now), interval(now, day(-1))], now: now, calendar: calendar).isEmpty, "Reject empty and reversed intervals")
        expect(SleepNormalizer.nights(from: [], now: now, calendar: calendar).isEmpty, "No samples produce no real nights")
        let unknownStage = SleepNormalizer.nights(from: [interval(today, today.addingTimeInterval(3600), .unclassified)], now: now, calendar: calendar)
        expect(!unknownStage[0].hasDetailedStages && unknownStage[0].unclassifiedMinutes == 60, "Unspecified sleep must not become core sleep")

        let records = CheckInRepository(defaults: defaults)
        let newest = (0..<30).map { index in CheckIn(date: today.addingTimeInterval(Double(index)), mood: "괜찮아요", stress: "보통", caffeine: false, source: "iPhone") }
        for item in newest { records.insert(item) }
        let delayed = CheckIn(date: day(-10), mood: "피곤해요", stress: "높음", caffeine: true, source: "Apple Watch")
        records.insert(delayed)
        expect(Set(records.records.map(\.id)) == Set(newest.map(\.id)), "Delayed old Watch record must not evict a newer record")
        expect(records.records.first?.date == newest.last?.date, "Record list is sorted by record time")
        expect(!CheckInRepository(defaults: defaults).insert(delayed), "Receipt ledger prevents redelivery even outside the visible 30 records")
        let selected = records.records[0]
        records.update(id: selected.id, mood: "개운해요", stress: "낮음", caffeine: true)
        let edited = CheckInRepository(defaults: defaults).records.first!
        expect(edited.id == selected.id && edited.date == selected.date && edited.source == selected.source && edited.caffeine, "Editing preserves date and original source and persists changes")
        expect(!records.insert(selected) && records.records.first?.caffeine == true, "Retransmission must not undo a phone edit")
        records.remove(id: selected.id)
        expect(!CheckInRepository(defaults: defaults).records.contains(where: { $0.id == selected.id }), "Delete persists")
        expect(!records.insert(selected), "A Watch retry cannot resurrect a deleted record")

        let outbox = CheckInOutbox(defaults: defaults)
        let message = CheckInMessage(timestamp: now.timeIntervalSince1970, mood: "괜찮아요", stress: "보통", caffeine: false)
        try outbox.enqueue(message)
        try outbox.enqueue(message)
        expect(outbox.pending.count == 1 && CheckInOutbox(defaults: defaults).pending.first == message, "Outbox persists UUIDs and does not enqueue a duplicate")
        expect(CheckInMessage(payload: message.payload) == message, "Watch payload round trip")
        expect(CheckInMessage(payload: ["id": message.id.uuidString, "timestamp": Double.infinity, "mood": "a", "stress": "b", "caffeine": false]) == nil, "Reject nonfinite wire timestamps")
        expect(CheckInMessage.receiptID(in: CheckInMessage.receipt(for: message.id)) == message.id, "Only a typed receipt confirms its UUID")
        expect(CheckInMessage.receiptID(in: message.payload) == nil, "A data message is not a receipt")
        var retryState = DeliveryRetryState()
        retryState.scheduled(message.id, now: now)
        expect(!retryState.eligible(message.id, transporting: [], now: now.addingTimeInterval(59)), "Wait for receipt before resending successful transport")
        retryState.finished(message.id, failed: true, now: now)
        expect(!retryState.eligible(message.id, transporting: [], now: now.addingTimeInterval(4)) && retryState.eligible(message.id, transporting: [], now: now.addingTimeInterval(5)), "Failed transfer retries after backoff")
        expect(!retryState.eligible(message.id, transporting: [message.id], now: now.addingTimeInterval(600)), "Never duplicate a system transfer still in flight")
        retryState.finished(message.id, failed: false, now: now)
        expect(CheckInOutbox(defaults: defaults).pending.count == 1, "Transport completion alone must not discard the durable message")
        outbox.acknowledge(id: UUID())
        expect(outbox.pending.count == 1, "Unrelated receipts must not remove pending data")
        outbox.acknowledge(id: message.id)
        expect(CheckInOutbox(defaults: defaults).pending.isEmpty, "Phone app receipt removes the durable item")
        for _ in 0..<30 { try outbox.enqueue(CheckInMessage(mood: "괜찮아요", stress: "보통", caffeine: false)) }
        do {
            try outbox.enqueue(CheckInMessage(mood: "피곤해요", stress: "높음", caffeine: true))
            expect(false, "Full outbox must reject instead of silently dropping data")
        } catch CheckInOutbox.QueueError.full { expect(outbox.pending.count == 30, "Full outbox preserves all pending records") }
        // Old single-record outboxes are migrated once with a stable ID.
        let legacyData = try JSONSerialization.data(withJSONObject: ["timestamp": now.timeIntervalSince1970, "mood": "괜찮아요", "stress": "보통", "caffeine": false])
        defaults.set(legacyData, forKey: "jammanbo.watch.pendingCheckIn.v1")
        let migrated = CheckInOutbox(defaults: defaults)
        expect(migrated.pending.count == 1 && CheckInOutbox(defaults: defaults).pending[0].id == migrated.pending[0].id, "Legacy queue migration must persist a stable retry UUID")

        var generation = 0
        let exports = ReportExportStore { _ in generation += 1; return URL(fileURLWithPath: "/tmp/jammanbo-test-report-\(generation).pdf") }
        let originalSummary = summary([night(0)], [checkIn(0, caffeine: false)])
        let firstReport = try exports.prepare(originalSummary)
        let laterSameData = ReportSummary(nights: originalSummary.nights, checkIns: originalSummary.checkIns, source: originalSummary.source, now: now.addingTimeInterval(60), calendar: calendar)
        exports.synchronize(with: laterSameData.content)
        expect(exports.document?.id == firstReport.id, "A ticking generation clock alone does not invalidate a PDF")
        let changedSummary = summary([night(0)], [checkIn(0, caffeine: false), checkIn(0, caffeine: true, seconds: 2)])
        exports.synchronize(with: changedSummary.content)
        expect(exports.document == nil, "New check-in data invalidates the previous PDF")
        let fresh = try exports.prepare(changedSummary)
        expect(fresh.content.checkIns.count == 2 && fresh.url != firstReport.url, "Regeneration shares the latest report snapshot")
        let nextDay = ReportSummary(nights: originalSummary.nights, checkIns: [], source: "검증 기록", now: day(1), calendar: calendar)
        exports.synchronize(with: nextDay.content)
        expect(exports.document == nil, "Calendar day change invalidates the previous reporting range")

        var shouldFailExport = false
        let failingExports = ReportExportStore { _ in
            if shouldFailExport { throw NSError(domain: "ExportCheck", code: 1) }
            return URL(fileURLWithPath: "/tmp/export-success.pdf")
        }
        try failingExports.prepare(originalSummary)
        shouldFailExport = true
        do { try failingExports.prepare(changedSummary); expect(false, "Export failure should throw") }
        catch { expect(failingExports.document == nil, "Export failure cannot leave an old PDF available for sharing") }
        print("Passed \(checks) domain checks")
    }
}
