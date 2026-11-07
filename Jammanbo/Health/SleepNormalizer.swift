import Foundation

struct SleepInterval: Sendable {
    enum Stage: Int, CaseIterable, Sendable {
        case unclassified, core, rem, deep, awake, inBed

        var isAsleep: Bool { self != .awake && self != .inBed }
        var isDetailed: Bool { self != .unclassified && self != .inBed }
    }

    let id: String
    let start: Date
    let end: Date
    let stage: Stage
    let source: String
    let isWatch: Bool

    init(id: String = UUID().uuidString, start: Date, end: Date, stage: Stage, source: String = "", isWatch: Bool = false) {
        self.id = id
        self.start = start
        self.end = end
        self.stage = stage
        self.source = source
        self.isWatch = isWatch
    }
}

/// Resolves overlapping intervals before grouping sleep sessions by their final waking date.
enum SleepNormalizer {
    private struct Segment {
        let start: Date
        let end: Date
        let stage: SleepInterval.Stage
    }

    static func nights(from input: [SleepInterval], now: Date = .now, calendar: Calendar = .current, maximumAwakeGap: TimeInterval = 90 * 60) -> [SleepNight] {
        let clipped = input.compactMap { item -> SleepInterval? in
            let end = min(item.end, now)
            guard item.start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite, end > item.start else { return nil }
            return SleepInterval(id: item.id, start: item.start, end: end, stage: item.stage, source: item.source, isWatch: item.isWatch)
        }
        let bedWindows = clipped.filter { $0.stage == .inBed }
        let intervals = clipped.filter { $0.stage != .inBed }
        // Sweep interval boundaries; a source is selected once for each unique span.
        let starts = Dictionary(grouping: intervals.indices, by: { intervals[$0].start })
        let ends = Dictionary(grouping: intervals.indices, by: { intervals[$0].end })
        let boundaries = Set(intervals.flatMap { [$0.start, $0.end] }).sorted()
        var active = Set<Int>()
        var segments: [Segment] = []
        for index in boundaries.indices.dropLast() {
            let date = boundaries[index]
            for item in ends[date] ?? [] { active.remove(item) }
            for item in starts[date] ?? [] { active.insert(item) }
            guard let best = active.min(by: { preferred(intervals[$0], over: intervals[$1]) }) else { continue }
            let selected = intervals[best]
            guard selected.stage.isAsleep else { continue }
            segments.append(Segment(start: date, end: boundaries[index + 1], stage: selected.stage))
        }
        guard !segments.isEmpty else { return [] }

        var sessions: [[Segment]] = []
        for segment in segments {
            if let last = sessions.last?.last,
               segment.start.timeIntervalSince(last.end) <= maximumAwakeGap || bedWindows.contains(where: { $0.start <= last.end && $0.end >= segment.start }) {
                sessions[sessions.count - 1].append(segment)
            } else {
                sessions.append([segment])
            }
        }
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.last!.end) }
        return grouped.compactMap { date, sessions in
            let spans = sessions.flatMap { $0 }
            var seconds: [SleepInterval.Stage: TimeInterval] = [:]
            for span in spans { seconds[span.stage, default: 0] += span.end.timeIntervalSince(span.start) }
            let total = Int((seconds.values.reduce(0, +) / 60).rounded(.down))
            guard total > 0 else { return nil }
            // Round once per waking day, distributing leftover minutes so stage totals agree.
            let stages = SleepInterval.Stage.allCases.filter(\.isAsleep)
            var minutes = Dictionary(uniqueKeysWithValues: stages.map { ($0, Int((seconds[$0, default: 0] / 60).rounded(.down))) })
            let remainder = total - minutes.values.reduce(0, +)
            let fractional = stages.sorted {
                let lhs = seconds[$0, default: 0].truncatingRemainder(dividingBy: 60)
                let rhs = seconds[$1, default: 0].truncatingRemainder(dividingBy: 60)
                return lhs == rhs ? $0.rawValue > $1.rawValue : lhs > rhs
            }
            for stage in fractional.prefix(remainder) { minutes[stage, default: 0] += 1 }
            return SleepNight(
                id: date, date: date, totalMinutes: total,
                deepMinutes: minutes[.deep, default: 0], remMinutes: minutes[.rem, default: 0],
                coreMinutes: minutes[.core, default: 0], unclassifiedMinutes: minutes[.unclassified, default: 0],
                hasDeepStageData: seconds[.deep] != nil, hasRemStageData: seconds[.rem] != nil,
                hasCoreStageData: seconds[.core] != nil, isSample: false,
                startDate: spans.first?.start, endDate: spans.last?.end
            )
        }.sorted { $0.date > $1.date }
    }

    private static func preferred(_ lhs: SleepInterval, over rhs: SleepInterval) -> Bool {
        if lhs.stage.isDetailed != rhs.stage.isDetailed { return lhs.stage.isDetailed }
        if lhs.isWatch != rhs.isWatch { return lhs.isWatch }
        if lhs.source != rhs.source { return lhs.source < rhs.source }
        if lhs.stage != rhs.stage { return lhs.stage == .awake || (rhs.stage != .awake && lhs.stage.rawValue > rhs.stage.rawValue) }
        return lhs.id < rhs.id
    }
}
